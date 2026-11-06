#!/usr/bin/env python3
"""Execute actual HUD arbitration, action callback and captions, without granting progress."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
s = (ROOT/'src/client/JobController.luau').read_text()
a = s.index('\tlocal function currentHomeCue(')
selector = s[a:s.index('\tlocal function send(', a)]
a = s.index('\tlocal function activateObjective(')
activate = s[a:s.index('\tlocal navigation =', a)]
a = s.index('\t\tscreen:SetAttribute("HomeObjectiveQuiet"')
render = s[a:s.index('\n\tend\n\taction.Activated', a)]
header = r'''
local Strings=require("../src/shared/Strings")
local attrs={};local labels={Title={IsA=function()return true end},Hint={IsA=function()return true end}}
local objective={IsA=function()return true end,FindFirstChild=function(_,name)return labels[name]end}
local screen={SetAttribute=function(_,k,v)attrs[k]=v end,GetAttribute=function(_,k)return attrs[k]end,FindFirstChild=function()return objective end}
local ready,step="Ready","DONE"
local player={GetAttribute=function(_,key)return if key=="ProfileStatus"then ready else step end}
local accepting,abandoning=false,false
local function acceptancePending()return accepting end
local abandon={pending=function()return abandoning end}
local travel=nil
local function travelGoal()return travel end
local lastError,errorUntil=nil,0;local os={clock=function()return 10 end}
local state={available=true,phase="Completed"}
local cue={kind="Base",placed=1,total=5,key="Base:1/5"}
local function getHomeObjective()return cue end
local opened,oldActions=0,0
local function homeAction(tab)assert(tab=="Room");opened+=1 end
local function activate()oldActions+=1 end
local lang="en"
local function t(key)return Strings.text(lang,key)end
local function stepHint()return "job-error-or-hint"end
local phaseKeys={Completed="jobDone",Offer="jobOffer",Inspect="jobInspect"}
'''
checks = r'''
assert(currentHomeCue()==cue);activateObjective();assert(opened==1 and oldActions==0,"HUD did not open room plan exclusively")
for _,blocked in {"accept","abandon","route","unavailable","profile","onboarding","build","error","work","nohome"}do
 accepting=blocked=="accept";abandoning=blocked=="abandon";travel=if blocked=="route"then {}else nil
 state.available=blocked~="unavailable";ready=if blocked=="profile"then "Saving"else "Ready"
 step=if blocked=="onboarding"then "PLACE"else "DONE";attrs.Building=blocked=="build"
 lastError=if blocked=="error"then "TooFar"else nil;errorUntil=20
 state.phase=if blocked=="work"then "Inspect"else "Completed"
 local old=cue;if blocked=="nohome"then cue=nil end
 assert(currentHomeCue()==nil,"Home cue overrode priority: "..blocked)
 activateObjective();assert(opened==1,"Blocked cue opened housing: "..blocked)
 cue=old
end
assert(oldActions==10,"HUD bypassed existing dispatcher")
accepting=false;abandoning=false;travel=nil;state.available=true;ready="Ready";step="DONE";attrs.Building=false;lastError=nil;state.phase="Completed"
errorUntil=0
'''
render_checks = r'''
local function redraw()
 local s=state;local phase=state.phase;local homeCue=currentHomeCue()
''' + render + r'''
end
for _,locale in {"en","ru"}do
 lang=locale
 for _,kind in {"Base","Creative","Ready"}do
  cue={kind=kind,placed=if kind=="Base"then 1 else 3,total=if kind=="Base"then 5 else 3,key=kind}
  redraw();assert(attrs.HomeObjectiveQuiet and labels.Title.Text~=t("jobDone")and labels.Hint.Text==t("homeHudHint"),"Old job completion hid home progress")
  if kind~="Ready"then assert(labels.Title.Text:find("/",1,true),"Home count missing")else assert(labels.Title.Text==t("homeHudReady"))end
 end
end
lastError="TooFar";errorUntil=20;redraw()
assert(not attrs.HomeObjectiveQuiet and attrs.JobHintError and labels.Hint.Text=="job-error-or-hint","Error stayed compact or lost its text")
lastError=nil;travel={near=false};redraw();assert(not attrs.HomeObjectiveQuiet and labels.Title.Text==t("goToShop"),"Home cue overrode shop route")
travel=nil;cue=nil;state.phase="Inspect";redraw();assert(labels.Title.Text==t("jobInspect"),"No-home changed work caption")
print("PASS HomeObjectiveUI: real selector, HUD-only callback, all guards, captions/EN/RU and error/route priority")
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT/'.tools') as f:
    f.write(header+selector+activate+checks+render_checks);f.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)

# Idle exploration must refresh authoritative room presence using the existing throttle.
home = (ROOT/'src/client/HomeController.luau').read_text()
a = home.index('\tlocal homeSync = RunService.RenderStepped:Connect')
b = home.index('\n\tsend("sync", nil)', a)
body = home[a:b]
probe = r'''
local now,syncAt=0,0;local os={clock=function()return now end}
local state={onboarding="DONE"};local routeActive=false
local shop,inventory={Visible=false},{Visible=false}
local planner={isVisible=function()return false end}
local builder={isActive=function()return false end}
local sent,drawn=0,0
local function send(action)assert(action=="sync","Presence poll mutated gameplay");sent+=1 end
local function render()drawn+=1 end
local step,destroy
local connected=true
local RunService={RenderStepped={Connect=function(_,callback)
 step=callback;return {Disconnect=function()connected=false end}
end}}
local screen={Destroying={Once=function(_,callback)destroy=callback end}}
''' + body + r'''
local function tick()if connected then step()end end
tick();assert(sent==0)
now=1.1;tick();assert(sent==1 and drawn==1,"Idle home presence remained stale")
now=1.2;tick();assert(sent==1,"Presence bypassed existing throttle")
now=2.2;tick();assert(sent==2,"Walking outside/inside could not refresh")
state.onboarding="PLACE";now=4;tick();assert(sent==2,"Intro added idle traffic")
shop.Visible=true;tick();assert(sent==3,"Existing shop sync stopped")
destroy();now=8;tick();assert(sent==3 and not connected,"Destroyed HUD retained idle presence polling")
print("PASS HomeObjectiveUI: existing 1-second sync refreshes DONE exploration, throttles, keeps intro quiet and disconnects")
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT/'.tools') as f:
    f.write(probe);f.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)

# The actual observer block must refresh both snapshot and attribute ordering, then detach.
a = s.index('\tlocal homeChanged =')
b = s.index('\n\tsend("sync", nil)', a)
observers = s[a:b]
probe = r'''
local signals={};local draws=0
local function signal(name)
 if signals[name]then return signals[name]end
 local listeners={}
 local value={Connect=function(_,callback)
  local connection={Connected=true};function connection:Disconnect()self.Connected=false end
  table.insert(listeners,{callback=callback,connection=connection});return connection
 end,Fire=function()
  for _,entry in listeners do if entry.connection.Connected then entry.callback()end end
 end}
 function value:Once(callback)return self:Connect(callback)end
 signals[name]=value;return value
end
local screen={GetAttributeChangedSignal=function(_,name)return signal(name)end,Destroying=signal("Destroy")}
local player={GetAttributeChangedSignal=function(_,name)return signal(name)end}
local function render()draws+=1 end
''' + observers + r'''
for _,name in {"HomeObjectiveState","OnboardingStep","Building"}do signal(name):Fire()end
assert(draws==3,"Snapshot/attribute/build changes did not refresh HUD")
signal("Destroy"):Fire()
for _,name in {"HomeObjectiveState","OnboardingStep","Building"}do signal(name):Fire()end
assert(draws==3,"Destroyed HUD retained new home observers")
print("PASS HomeObjectiveUI: actual observers cover event ordering and disconnect on HUD destruction")
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT/'.tools') as f:
    f.write(probe);f.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
