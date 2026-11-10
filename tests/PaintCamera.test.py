#!/usr/bin/env python3
"""Execute real paint camera entry/framing and verify input stays behind the transition."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/PaintController.luau").read_text()
start = source.index("\tlocal function enter(")
entry = source[start:source.index("\n\t\tmissing = false", start)] + "\nend\n"
start = source.index("\n\t\tif not active then", source.index("RunService:BindToRenderStep"))
guard = source[start:source.index("\n\t\tlocal target, camera, s", start)]
start = source.index("\t\tlocal inset = GuiService:GetGuiInset()", source.index("RunService:BindToRenderStep"))
camera = source[start:source.index("\n\t\tif inflight", start)]
header = r'''
local now=10;local os={clock=function()return now end}
local View=require("../src/shared/PaintView")
local Enum={CameraType={Scriptable="Scriptable",Custom="Custom"}}
local Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end}
local CFrame={};local meta={}
function CFrame.new(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},meta)end
function CFrame.lookAt(from)return CFrame.new(from.X,from.Y,from.Z)end
meta.__mul=function(a,b)return CFrame.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
meta.__index={Lerp=function(self,goal,alpha)
 local r=CFrame.new(self.X+(goal.X-self.X)*alpha,self.Y+(goal.Y-self.Y)*alpha,self.Z+(goal.Z-self.Z)*alpha)
 r.alpha=alpha;return r
end}
local initial=CFrame.new(100,30,100)
local camera={CFrame=initial,FieldOfView=70,CameraType="Custom",CameraSubject={},ViewportSize={X=1449,Y=846}}
local workspace={CurrentCamera=camera}
local humanoid={Health=100,Died={Once=function()return{}end}}
local player={Character={FindFirstChildOfClass=function()return humanoid end}}
local target={Size=Vector3.new(16,8,1),Position=Vector3.new(0,4,0),CFrame={PointToWorldSpace=function(_,v)return v end}}
local s={sequence=7};local active,disposed=false,false
local wall,snapshot,sequence,deathConnection
local previousCameraType,previousSubject,previousFrame,previousFov
local focusStarted=0;local cameraReady=false
local GuiService={ReducedMotionEnabled=false,GetGuiInset=function()return{Y=32}end}
local light=false;local screen={GetAttribute=function()return light end}
local toolbar={AbsolutePosition={Y=700}}
local hidden=0
local roller={hide=function()hidden+=1 end}
local sound={Playing=false}
local samples=0
local function render()end
local function tick()
''' + guard + camera + r'''
 samples+=1
end
'''
checks = r'''
enter(target,s);assert(active and not cameraReady and previousFrame==initial)
tick();assert(camera.CFrame.alpha==0 and camera.FieldOfView==70 and samples==0,"Paint camera snapped instead of entering smoothly")
now+=.15;tick()
assert(math.abs(camera.CFrame.alpha-.5)<1e-8 and math.abs(camera.FieldOfView-60)<1e-8 and not cameraReady and samples==0,"Midpoint admitted paint or changed easing/FOV")
local middle=camera.CFrame
toolbar.AbsolutePosition.Y=420;camera.ViewportSize={X=666,Y=316};now+=.05;tick()
assert(camera.CFrame.alpha>.5 and camera.CFrame.alpha<1 and samples==0 and camera.CFrame~=middle,"Resize restarted/skipped the entry")
now=10.299999;tick();assert(not cameraReady and samples==0,"Paint became ready before the transition finished")
now=10.3;tick();assert(cameraReady and camera.FieldOfView==50 and samples==1,"Final fit never enabled painting")
local final=camera.CFrame;now+=1;tick();assert(cameraReady and camera.CFrame.Z==final.Z and camera.CFrame.Y==final.Y and samples==2,"Settled camera kept moving")
local function reopen()
 active=false;camera.CFrame=initial;camera.FieldOfView=70;enter(target,s)
 assert(not cameraReady,"Reentry reused the old ready flag")
end
reopen();tick();assert(not cameraReady and samples==2)
GuiService.ReducedMotionEnabled=true;tick();assert(cameraReady and camera.FieldOfView==50 and samples==3,"Reduced motion did not skip entry")
GuiService.ReducedMotionEnabled=false;tick();assert(cameraReady and camera.FieldOfView==50,"Turning motion on replayed the camera transition")
reopen();light=true;tick();assert(cameraReady and samples==5,"Light effects kept camera motion")
light=false;tick();assert(cameraReady and samples==6,"Turning full effects on replayed entry")
assert(sequence==7 and snapshot==s,"Camera rewrote packet/job state")
reopen();now+=.1;tick();active=false
local stopped=camera.CFrame;local count=samples;now+=1;tick()
assert(camera.CFrame==stopped and samples==count,"Stopped frame resumed the transition")
disposed=true;enter(target,s);tick()
assert(not active and camera.CFrame==stopped and samples==count,"Destroyed view restarted camera motion")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + entry + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS PaintCamera: actual entry/framing, time boundaries, resize, settled fit, reduced/light, no replay or early sampling")
