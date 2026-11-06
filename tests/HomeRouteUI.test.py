#!/usr/bin/env python3
"""Run actual home-route callbacks, projections, status publishing and map drawing."""
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
home=(ROOT/'src/client/HomeController.luau').read_text()
def run(name,body):
    with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools') as f:
        f.write(body);f.flush()
        subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
    print('PASS HomeRouteUI:',name)
a=home.index('\thomeRouteButton.Activated:Connect(function()')
callback=home[a:home.index('\n\trouteButton.Activated',a)]
a=home.index('\t\ttravel = function(): Goals.Goal?')
projection=home[a:home.index('\n\t\trender = render,',a)]
a=home.index('\t\tlocal selected = routeTarget')
publish=home[a:home.index('\n\t\tlocal cue =',a)]
a=home.index('\t\thomeRouteButton.Text = t(')
caption=home[a:home.index('\n\t\tlocal errorText =',a)]
# Header keeps the real button in lexical scope before render, as in production.
header=r'''
local Goals=require("../src/shared/NavigationGoal")
local Strings=require("../src/shared/Strings")
local routeTarget=nil
local state={available=true,nearHome=false,nearShop=true,origin={64,0,128},homeName="Home_1"}
local lang="en";local function t(key)return Strings.text(lang,key)end
local attrs={};local screen={SetAttribute=function(_,key,value)attrs[key]=value end}
local player={GetAttribute=function()return "Ready"end}
local job={jobId="keep-job",workId="keep-work"}
local purchase,storing,build,profile=nil,nil,false,"Ready"
local function planBlocked()return purchase~=nil or storing~=nil or build or profile~="Ready"end
local hidden,rendered,clicked=0,0,nil
local homePanel={Visible=true}
local homeRouteButton={Activated={Connect=function(_,callback)clicked=callback end}}
local function hidePanels()hidden+=1 end
local function render()
 rendered+=1;local s=state
'''+publish+caption+r'''
end
local workspace={FindFirstChild=function()return nil end}
local api={
'''+projection+r'''
}
'''+callback
checks=r'''
for _,locale in {"en","ru"}do
 lang=locale;render();assert(homeRouteButton.Active and homeRouteButton.Text==t("walkHome"))
 clicked();assert(routeTarget=="Home"and not homePanel.Visible and hidden>=1)
 local goal=api.travel();assert(goal.kind=="Home"and goal.roomName=="Home_1"and attrs.TravelState=="Home:true:false")
 assert(homeRouteButton.Text==t("stopHomeRoute")and homeRouteButton.Active)
 state.nearHome=true;render();assert(attrs.TravelState=="Home:true:true"and api.travel().near)
 homePanel.Visible=true;clicked();assert(routeTarget==nil and api.travel()==nil)
 assert(not homeRouteButton.Active and homeRouteButton.Text==t("alreadyHome")and attrs.TravelState=="")
 clicked();assert(routeTarget==nil,"Already home invented a trip")
 state.nearHome=false
end
for _,reason in {"purchase","store","build","profile","snapshot","hidden","missing"}do
 routeTarget="Shop";homePanel.Visible=reason~="hidden"
 purchase=if reason=="purchase"then {requestId="immutable-buy"}else nil
 storing=if reason=="store"then {requestId="immutable-store"}else nil
 build=reason=="build";profile=if reason=="profile"then "Lost"else "Ready"
 state.available=reason~="snapshot";local snapshot=state;if reason=="missing"then state=nil end
 clicked();assert(routeTarget=="Shop","Blocked selection replaced route: "..reason)
 if purchase then assert(purchase.requestId=="immutable-buy")end
 if storing then assert(storing.requestId=="immutable-store")end
 state=snapshot
end
purchase=nil;storing=nil;build=false;profile="Ready";state.available=true;homePanel.Visible=true
clicked();assert(routeTarget=="Home","Home did not replace Shop")
api.stopRoute();assert(routeTarget==nil and attrs.TravelState=="","Explicit stop retained stale HUD")
assert(job.jobId=="keep-job"and job.workId=="keep-work","Local route changed active work")
'''
run('home callbacks, projection, guards, pending IDs, stop and captions EN/RU',header+checks)
# Execute the existing map renderer rather than asserting source substrings.
s=(ROOT/'src/client/MapController.luau').read_text();a=s.index('\tlocal function draw(): ()');b=s.index('\n\tlocal function resize',a)
run('home marker once, map legend/arrival/availability and immutable route pool',r'''
local Math=require("../src/shared/MapMath")
local status="Ready";local Players={LocalPlayer={GetAttribute=function()return status end}}
local UDim2={fromOffset=function(x,y)return{x=x,y=y}end,new=function(...)return{...}end}
local function t(key)return key end
local state,home,root=nil,nil,nil
local width,height=400,150;local routePoints={};local routeIndex=1
local house={BackgroundColor3="blue"};local playerDot={BackgroundColor3="gold"};local outline={};local homeLegendOutline={}
local target,road={},{ };local lines={};for i=1,128 do lines[i]={}end
local follow,heading,back={},{},{};local youLabel,homeLabel,clientLabel={},{},{}
local clientIcon,hint={},{}
'''+s[a:b]+r'''
home={X=64,Z=128};state={kind="Home",available=true,near=true,destination={64,3,128},areaKey="home"}
draw();assert(house.Visible and not target.Visible and not clientIcon.Visible and not clientLabel.Visible,"Duplicate home target")
assert(outline.Color=="gold"and homeLegendOutline.Color=="gold"and homeLabel.Text=="mapHomeGoal","Map did not identify selected house")
assert(hint.Text=="arrived"and follow.Active)
state.available=false;draw();assert(hint.Text=="mapUnavailable"and not follow.Active)
state.available=true;status="Lost";draw();assert(hint.Text=="mapUnavailable"and not follow.Active)
status="Ready";state.kind="Shop";draw();assert(target.Visible and clientIcon.Visible and clientLabel.Text=="mapShop"and outline.Color=="blue")
state=nil;draw();assert(house.Visible and not target.Visible and homeLabel.Text=="home"and hint.Text=="mapNoJob")
assert(#lines==128,"Route renderer changed object pool")
''')
