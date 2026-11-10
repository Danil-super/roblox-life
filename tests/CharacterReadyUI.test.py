#!/usr/bin/env python3
"""Run the actual entry/recovery controller through late parts, death and cleanup."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/ProfileRecoveryController.luau").read_text()
body = source[source.index("\tlocal function characterReady()"):source.index("\n\treturn {")]
api = "local api = " + source[source.index("\n\treturn {") + len("\n\treturn "):source.rindex("\nend\nreturn Controller")] + "\n"
header = '''
local Strings=require("../src/shared/Strings")
local function signal()
 local links={};local s={}
 function s:Connect(fn)
  local c={active=true,fn=fn};function c:Disconnect()self.active=false end
  table.insert(links,c);return c
 end
 s.Once=s.Connect
 function s:Fire(...)for _,c in table.clone(links)do if c.active then c.fn(...)end end end
 function s:live()local n=0;for _,c in links do if c.active then n+=1 end end;return n end
 return s
end
local attrs={ProfileStatus="Ready",ProfileRecoveryAllowed=true,ProfileCanRetry=true,ProfileErrorCode="Locked"}
local attrSignals={}
local player={CharacterAdded=signal(),CharacterRemoving=signal()}
function player:GetAttribute(k)return attrs[k]end
function player:GetAttributeChangedSignal(k)if not attrSignals[k]then attrSignals[k]=signal()end;return attrSignals[k]end
local function status(value)attrs.ProfileStatus=value;player:GetAttributeChangedSignal("ProfileStatus"):Fire()end
local camera={CameraType="Fixed"}
local workspace={CurrentCamera=camera}
local Enum={CameraType={Custom="Custom"}}
local paint={Visible=false,IsA=function()return true end}
local screen={Parent={},Destroying=signal(),GetAttribute=function()return false end,FindFirstChild=function()return paint end}
local panel={Visible=false};local heading,message,lang={},{},{}
local retry,exit={Activated=signal()},{Activated=signal()}
local locale="en";local function language()return locale end
local seenError,awaiting,exiting,epoch=false,false,false,0
local cameraPending,disposed=false,false
local connections,characterConnections={},{}
local observedCharacter,observedHumanoid,healthConnection=nil,nil,nil
local requests,delayed={},{}
local command={FireServer=function(_,action)table.insert(requests,action)end}
local task={delay=function(_,fn)table.insert(delayed,fn)end}
local suspended=0;local function suspend()suspended+=1 end
local function part(name,class)
 return{Name=name,IsA=function(_,kind)return kind==class end}
end
local function model(withRoot,health)
 local m={Parent=workspace,ChildAdded=signal(),ChildRemoved=signal(),AncestryChanged=signal(),children={}}
 function m:IsDescendantOf(parent)return self.Parent==parent end
 function m:FindFirstChild(name)return self.children[name]end
 function m:FindFirstChildOfClass(class)for _,c in self.children do if c:IsA(class)then return c end end;return nil end
 function m:add(child)child.Parent=self;self.children[child.Name]=child;self.ChildAdded:Fire(child)end
 function m:remove(name)local c=self.children[name];self.children[name]=nil;c.Parent=nil;self.ChildRemoved:Fire(c)end
 local h=part("Humanoid","Humanoid");h.Health=health or 100;h.HealthChanged=signal();m:add(h)
 if withRoot then m:add(part("HumanoidRootPart","BasePart"))end
 return m,h
end
local function spawn(m)player.Character=m;player.CharacterAdded:Fire(m)end
'''
cases = {
    "late_root_and_health_use_current_model": ("", '''
assert(panel.Visible and heading.Text==Strings.text("en","characterLoadingTitle"))
local m,h=model(false);spawn(m);assert(panel.Visible and not characterReady())
m:add(part("HumanoidRootPart","Folder"));assert(panel.Visible,"Wrong root class unblocked the world")
m:remove("HumanoidRootPart");m:add(part("HumanoidRootPart","BasePart"))
assert(not panel.Visible and characterReady() and camera.CameraSubject==h and suspended==1)
m:remove("HumanoidRootPart");assert(panel.Visible and suspended==2)
m:add(part("HumanoidRootPart","BasePart"));assert(not panel.Visible and #requests==0)
'''),
    "parent_and_late_humanoid_are_observed": ("", '''
local m,h=model(true);m.Parent=nil;m:remove("Humanoid");spawn(m);assert(panel.Visible)
m:add(h);assert(panel.Visible,"Unparented character unblocked the world")
m.Parent={};m.AncestryChanged:Fire();assert(panel.Visible,"Character outside workspace unblocked the world")
m.Parent=workspace;m.AncestryChanged:Fire();assert(not panel.Visible and camera.CameraSubject==h)
'''),
    "death_removal_and_stale_model_cannot_finish_respawn": ("", '''
local old,h=model(true);spawn(old);assert(not panel.Visible)
h.Health=0;h.HealthChanged:Fire(0);assert(panel.Visible and not retry.Active and not exit.Visible)
player.CharacterRemoving:Fire(old)
h.Health=100;h.HealthChanged:Fire(100);old.ChildAdded:Fire()
assert(panel.Visible,"Removed model finished waiting before player.Character changed")
local current,nextHumanoid=model(false);spawn(current)
player.CharacterRemoving:Fire(old);old.ChildAdded:Fire();assert(panel.Visible)
current:add(part("HumanoidRootPart","BasePart"))
assert(not panel.Visible and camera.CameraSubject==nextHumanoid)
assert(old.ChildAdded:live()==0 and h.HealthChanged:live()==0,"Old character kept observers")
'''),
    "initial_alive_character_does_not_steal_camera": (
        "local initial,initialHumanoid=model(true);player.Character=initial\n", '''
assert(not panel.Visible and camera.CameraType=="Fixed" and suspended==0)
render();assert(camera.CameraType=="Fixed" and #requests==0)
'''),
    "profile_failure_and_locale_keep_priority": ("", '''
status("Error");assert(retry.Active and message.Text==Strings.text("en","profileReasonLocked"))
locale="ru";render();assert(message.Text==Strings.text("ru","profileReasonLocked"))
retry.Activated:Fire();assert(requests[1]=="retry")
status("Loading");assert(heading.Text==Strings.text("ru","profileRecoveringTitle"))
status("Ready");assert(panel.Visible and message.Text==Strings.text("ru","characterLoading"))
retry.Activated:Fire();exit.Activated:Fire();assert(#requests==1,"Waiting dispatched a profile command")
local m=model(true);spawn(m);assert(not panel.Visible)
'''),
    "destroy_cancels_external_observers_and_delayed_retry": ("", '''
local m,h=model(true);spawn(m);status("Error");retry.Activated:Fire();assert(#delayed==1)
screen.Destroying:Fire();local title=heading.Text
for _,fn in delayed do fn()end
status("Ready");player.CharacterAdded:Fire(m);h.HealthChanged:Fire(0)
retry.Activated:Fire();exit.Activated:Fire()
assert(disposed and not panel.Visible and heading.Text==title and #requests==1)
assert(api.isBlocking(),"Destroyed recovery UI reopened the phone gate")
assert(player.CharacterAdded:live()==0 and player.CharacterRemoving:live()==0 and h.HealthChanged:live()==0)
for _,s in attrSignals do assert(s:live()==0,"Destroyed HUD retained profile listeners")end
assert(m.ChildAdded:live()==0 and m.ChildRemoved:live()==0 and m.AncestryChanged:live()==0)
'''),
}
for name, (setup, assertions) in cases.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + setup + body + api + assertions)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS CharacterReadyUI:", name)
