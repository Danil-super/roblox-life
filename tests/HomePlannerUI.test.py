#!/usr/bin/env python3
"""Execute planner navigation against current confirmed ownership."""
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/"src/client/HomeController.luau").read_text()
start=source.index("\tplanner = RoomPlanner.start(")
finish=source.index("\n\tfor _, back in", start)
body=source[start:finish]
a=source.index('\tlocal function planBlocked()')
b=source.index('\n\tlocal function thumbnail',a)
guard=source[a:b]
header='''
local navigate,earn
local RoomPlanner={start=function(_,_,fn,work)navigate=fn;earn=work;return {} end}
local planner,screen,language={},{},function()return "en"end
local state={available=true,items={{id="chair",catalogId="reading-chair-v1"}}}
local focus,shown,renders=nil,nil,0
local status="Ready"
local player={GetAttribute=function()return status end}
local purchase,storing=nil,nil
local building=false
local builder={isActive=function()return building end}
local homePanel={Visible=true}
local routeTarget="Shop"
local hidden,opened=0,0
local function hidePanels()hidden+=1 end
local function openJobs()opened+=1 end
local function show(tab)shown=tab end
local function render()renders+=1 end
'''
checks='''
navigate("reading-chair-v1",nil)
assert(shown=="Shop" and focus.id=="reading-chair-v1","Unowned target did not focus shop")
navigate("reading-chair-v1","chair")
assert(shown=="Furniture" and focus.id=="chair","Owned target did not focus inventory")
navigate("bookcase-v1","chair")
assert(shown=="Shop" and focus.id=="bookcase-v1","Mismatched item redirected to another product")
state.available=false;local before=renders
navigate("reading-chair-v1","chair");assert(renders==before,"Unavailable profile navigated")
state=nil;navigate("reading-chair-v1","chair");assert(renders==before,"Missing profile navigated")
state={available=true,items={}}
for _,blocked in {"purchase","store","build","profile"}do
 purchase=if blocked=="purchase"then {}else nil
 storing=if blocked=="store"then {}else nil
 building=blocked=="build";status=if blocked=="profile"then "Error"else "Ready"
 navigate("bookcase-v1",nil);earn()
 assert(opened==0 and hidden==0 and renders==before,"Pending/lost context was interrupted")
end
purchase=nil;storing=nil;building=false;status="Ready"
earn();assert(opened==1 and hidden==1 and not homePanel.Visible and routeTarget==nil,"Earn did not open jobs exclusively")
state.available=false;earn();assert(opened==1,"Unavailable snapshot opened work")
'''
with tempfile.NamedTemporaryFile("w",suffix=".luau",dir=ROOT/".tools")as script:
    script.write(header+guard+body+checks);script.flush()
    subprocess.run([str(ROOT/".tools/bin/luau"),script.name],cwd=ROOT,check=True)
print("PASS HomePlannerUI: owned targets, earn, pending purchase/store/build and profile guards")

planner_source=(ROOT/'src/client/HomePlannerController.luau').read_text()
a=planner_source.index('\t\t\t\t\tfindWork.Activated:Connect(function()')
b=planner_source.index('\n\t\t\t\t\tend)',a)+len('\n\t\t\t\t\tend)')
callback=planner_source[planner_source.index('local function goals('):planner_source.index('function Planner.start(')]+planner_source[a:b]
header='''
local Budget=require("../src/shared/HomeBudget")
local Plan=require("../src/shared/HomePlan")
local goal=Plan.evaluate({}).goals[1]
local state={available=true,items={},dollars=0,catalog={{id="floor-plant-v1",dollars=180}},plan={goals={goal}}}
local stateBlocked=false
local panel={Visible=true}
local clicked
local findWork={Activated={Connect=function(_,fn)clicked=fn end}}
local earned=0
local function earn()earned+=1;panel.Visible=false end
'''
checks='''
clicked();assert(earned==1 and not panel.Visible)
clicked();assert(earned==1,"Hidden stale Earn navigated twice")
panel.Visible=true;stateBlocked=true;clicked();assert(earned==1,"Blocked planner opened jobs")
stateBlocked=false;state.dollars=180;clicked();assert(earned==1,"Old button ignored updated affordability")
state.dollars=0;state.plan.goals[1].requirements[1].itemId="owned";clicked();assert(earned==1,"Owned item suggested earning instead of placement")
state.plan=nil;clicked();assert(earned==1,"Missing plan opened jobs")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as script:
    script.write(header+callback+checks);script.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),script.name],cwd=ROOT,check=True)
print('PASS HomePlannerUI: actual Earn callback rechecks visibility, latest budget, ownership and busy state')

a=planner_source.index('\twork.Activated:Connect(function()')
b=planner_source.index('\n\tend)',a)+len('\n\tend)')
callback=planner_source[a:b]
header='''
local Plan=require("../src/shared/HomePlan")
local items={}
for i,id in {"floor-plant-v1","reading-chair-v1","side-table-v1","floor-lamp-v1","bookcase-v1"}do
 table.insert(items,{id=tostring(i),catalogId=id,purchaseOperationId="buy"..i,placed={x=i,z=6,rotationY=0}})
end
local state={available=true,plan=Plan.evaluate(items)}
local stateBlocked=false
local panel={Visible=true}
local clicked
local work={Activated={Connect=function(_,fn)clicked=fn end}}
local opened=0
local function earn()opened+=1;panel.Visible=false end
'''
checks='''
clicked();assert(opened==1 and not panel.Visible,"Complete room did not open jobs")
clicked();assert(opened==1,"Hidden completion button repeated navigation")
panel.Visible=true;stateBlocked=true;clicked();assert(opened==1,"Pending operation interrupted by completion")
stateBlocked=false;items[1].placed=nil;state.plan=Plan.evaluate(items);clicked();assert(opened==1,"Stored item left old completion button active")
state.plan=Plan.evaluate({});clicked();assert(opened==1,"Empty room opened completion")
state.available=false;clicked();assert(opened==1,"Unavailable snapshot opened completion")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as script:
    script.write(header+callback+checks);script.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),script.name],cwd=ROOT,check=True)
print('PASS HomePlannerUI: complete room opens jobs without accepting; hidden/busy/stored/unavailable guards')
