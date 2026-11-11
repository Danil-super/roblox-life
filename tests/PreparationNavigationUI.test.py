#!/usr/bin/env python3
"""Run real navigation wiring and beacon text, including travel precedence."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
s=(ROOT/'src/client/JobController.luau').read_text();a=s.index('\t\tlocal preparation, preparationTarget = preparationGoal(');b=s.index('\n\t\tinteraction.step(',a);bridge=s[a:b]
header=r'''
local state={phase="Prepare"};local wall,root,prepPart,homeSpawn,counter={},{},{},{},{}
local base={kind="Job",key="base"};local prepGoal={kind="Job",key="patch"}
local enabled=true;local calls=0;local observed
local function preparationGoal(s,r)calls+=1;observed=s;assert(r==root);if s and enabled then return prepGoal,prepPart end;return nil,nil end
local Goals={job=function(s,near)assert(s==state);return base end}
local room={FindFirstChild=function(_,name)assert(name=="HomeSpawn");return homeSpawn end}
local homes={FindFirstChild=function()return room end}
local shop={FindFirstChild=function(_,name)assert(name=="Counter");return counter end}
function homeSpawn:IsA(k)return k=="BasePart"end;function counter:IsA(k)return k=="BasePart"end
local workspace={FindFirstChild=function(_,name)return if name=="Homes"then homes else shop end}
local last,displayed
local navigation={update=function(g,p,r,a)last={goal=g,target=p,root=r,active=a}end,route=function()return{},1 end}
local map={update=function(_,_,g)displayed=g end}
local player={GetAttribute=function()return nil end};local function typeof()return "nil"end
local function t(k)return k end
local function run(travel,active)
 local s=state;local rootPart=root;local target=wall;local goal=travel or base;local nearWall=false;local navigating=active~=false
'''
checks=r'''
run(nil);assert(last.goal==prepGoal and last.target==prepPart and displayed==prepGoal and observed==state,"Preparation did not reach the ONE navigation/map")
for _,kind in {"Shop","Home"}do local g={kind=kind,roomName="home"};run(g);assert(observed==nil and last.goal==g and displayed==g and last.target==(if kind=="Home"then homeSpawn else counter),"Preparation overrode explicit travel")end
enabled=false;run(nil);assert(last.goal==base and last.target==wall and displayed==base,"No preparation changed normal navigation")
enabled=true;run(nil,false);assert(not last.active,"Projection bypassed existing navigation guard")
print("PASS PreparationNavigationUI: actual JobController bridge, one map/route, Shop/Home reset/precedence and guard")
'''
nav=(ROOT/'src/client/JobNavigation.luau').read_text();a=nav.index('\t\t\t\tif target then');b=nav.index('\n\t\t\telseif nextPoint then',a);beacon=nav[a:b]
head=r'''
local Strings=require("../src/shared/Strings");local lang="en";local function t(k)return Strings.text(lang,k)end
local marker,badge={},{}
local function render(s,target)
 marker.Enabled=false;local nameKey=s.labelKey
'''
verify=r'''
for _,locale in {"en","ru"}do
 lang=locale;local part={};render({labelKey="oldFinish",actionKey="scrapeBeaconHint"},part)
 assert(marker.Adornee==part and marker.Enabled and badge.Text==t("oldFinish").."\n"..t("scrapeBeaconHint"),"Patch beacon asks for unrelated HUD action")
 render({labelKey="protectFloor"},part);assert(badge.Text==t("protectFloor").."\n"..t("useActionBelow"),"Floor lost existing action")
 render({labelKey="oldFinish",actionKey="scrapeBeaconHint"},nil);assert(not marker.Enabled,"Missing patch left active beacon")
end
print("PASS PreparationNavigationUI: actual EN/RU native-hold beacon and normal-action fallback")
'''
for name,code in [('bridge',header+bridge+'\nend\n'+checks),('beacon',head+beacon+'\nend\n'+verify)]:
 with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
  f.write(code);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
