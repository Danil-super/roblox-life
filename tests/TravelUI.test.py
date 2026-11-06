#!/usr/bin/env python3
"""Execute real shop-route controls and objective dispatch, preserving game intents."""
from pathlib import Path
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
home = (ROOT/'src/client/HomeController.luau').read_text()
a = home.index('\trouteButton.Activated:Connect(function()')
b = home.index('\n\tevent.OnClientEvent', a)
shop_control = home[a:b]
job = (ROOT/'src/client/JobController.luau').read_text()
a = job.index('\tlocal function activate(): ()')
b = job.index('\n\tinteraction = ', a)
objective = job[a:b]
header = r'''
local routeTarget=nil
local status="Ready"
local player={GetAttribute=function(_,key)if key=="ProfileStatus"then return status end return "DONE"end}
local state={available=true,phase="Inspect",jobId="same-job",workId="same-work"}
local homePanel={Visible=true}
local jobs={Visible=true}
local hidden,rendered,clicked=0,0,nil
local function hidePanels()hidden+=1 end
local function render()rendered+=1 end
local routeButton={Activated={Connect=function(_,fn)clicked=fn end}}
'''
shop_checks = r'''
clicked();assert(routeTarget=="Shop" and not homePanel.Visible and hidden==1,"Route did not activate")
clicked();assert(routeTarget==nil and rendered==2 and hidden==1,"Stop closed catalog or retained route")
state.available=false;clicked();assert(routeTarget==nil,"Busy profile selected route")
state.available=true;status="Loading";clicked();status="Error";clicked()
assert(routeTarget==nil,"Unavailable profile selected route")
status="Ready";state=nil;clicked();assert(routeTarget==nil,"No snapshot selected route")
'''
objective_header = r'''
local function acceptancePending()return false end
local travel=nil
local function travelGoal()return travel end
local opened,shown,sent=nil,0,{}
local function homeAction(tab)opened=tab end
local map={show=function()shown+=1 end,hide=function()end}
local nearWall=false
local offers={show=function()end}
local function send(action) table.insert(sent,action)end
local function currentWall()return nil end
local painter={enter=function()error("Unexpected paint entry")end}
'''
objective_checks = r'''
travel={kind="Shop",available=true,near=false};activate()
assert(shown==1 and opened==nil and #sent==0,"Far shop action did not select map exclusively")
travel.near=true;activate()
assert(opened=="Shop" and #sent==0,"Arrival invented buy/job command")
opened=nil;travel.available=false;activate()
assert(opened==nil and shown==1,"Busy arrival interacted")
travel.available=true;status="Error";activate();assert(opened==nil,"Lost profile opened shop")
status="Ready";travel={kind="Home",available=true,near=false};activate()
assert(shown==2 and opened==nil and #sent==0,"Home walk did not open map exclusively")
travel.near=true;activate();assert(opened=="Room"and #sent==0,"Home arrival teleported, placed or opened shop")
opened=nil;travel.available=false;activate();assert(opened==nil,"Busy home opened plan")
travel.available=true;status="Error";activate();assert(opened==nil,"Lost profile opened home plan")
status="Ready";travel=nil;activate()
assert(shown==3 and #sent==0,"Cancelling travel did not return to same job")
assert(state.jobId=="same-job" and state.workId=="same-work","Travel changed job identity")
nearWall=true;activate();assert(sent[1]=="talk","Job arrival stopped dispatching real action")
'''
for name,body in [('shop',header+shop_control+shop_checks),('objective',header+objective_header+objective+objective_checks)]:
    with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools') as script:
        script.write(body);script.flush()
        subprocess.run([str(ROOT/'.tools/bin/luau'),script.name],cwd=ROOT,check=True)
    print('PASS TravelUI:',name)

# Exercise the actual displayed status with server arrival and error precedence.
source = (ROOT/'src/client/MapController.luau').read_text()
a = source.index('\t\thint.Text = if ')
b = source.index('\n\tend\n\tlocal function resize',a)
map_status = source[a:b]
status_cases = r'''
local status="Ready"
local Players={LocalPlayer={GetAttribute=function()return status end}}
local hint={Text=""}
local function t(key)return if key=="routeDistance"then "distance %d"else key end
local function update(s,remaining,current)
 local d=if s then s.destination else nil
''' + map_status + r'''
 return hint.Text
end
local s={available=true,near=true,destination={32,3,2}}
assert(update(s,3.8,{})=="arrived","Confirmed arrival still shows a remaining distance")
s.available=false;assert(update(s,nil,{})=="mapUnavailable","Busy arrival hid unavailability")
s.available=true;status="Error";assert(update(s,nil,{})=="mapUnavailable","Profile error became arrival")
status="Ready";assert(update(nil,nil,nil)=="mapNoJob","No selected goal invented route")
s.near=false;assert(update(s,7.3,{})=="distance 8","Walking distance changed")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools') as script:
    script.write(status_cases);script.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),script.name],cwd=ROOT,check=True)
print('PASS TravelUI: map arrival/unavailable/no-goal/distance')

# A deliberate NPC interaction resumes work even if Shop was selected for walking.
marker = '\tinteraction = ClientInteraction.start(screen, language, function()'
a = job.index(marker) + len(marker)
b = job.index('\n\tend, function(a: string)', a)
open_client = job[a:b]
scenario = r'''
local routeActive=true
local jobId="same-work"
local function stopTravel()routeActive=false end
local function hideHousing()end
local guide={hide=function()end}
local painter={stop=function()end}
local jobs,results,homePanel={Visible=true},{Visible=true},{Visible=true}
local map={hide=function()end}
local function enterClient()
''' + open_client + r'''
end
enterClient()
assert(routeTarget==nil,"NPC interaction left Shop overriding the next work action")
assert(jobId=="same-work" and not jobs.Visible and not results.Visible and not homePanel.Visible,"NPC entry changed work identity or left competing menus")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools') as script:
    script.write(scenario);script.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),script.name],cwd=ROOT,check=True)
print('PASS TravelUI: native client interaction resumes work')
