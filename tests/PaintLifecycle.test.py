#!/usr/bin/env python3
"""Execute the actual painting cleanup and death/removal hooks."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/PaintController.luau").read_text()
start = source.index("\tlocal function stop(): ()")
stop = source[start:source.index("\n\tlocal function flush()", start)]
start = source.index("\t\tdeathConnection = humanoid.Died")
hook = source[start:source.index("\n\t\twall = target", start)]
start = source.index("\tlocal removingConnection = player.CharacterRemoving:Connect")
removal = source[start:source.index("\n\tlocal beganConnection = UIS.InputBegan", start)]
header = r'''
local active,held,touch = true,true,{}
local disposed=false
local queue,current,inflight,inspectPending = {{points={1}}},{},7,true
local toolbar={Visible=true}
local unbound,disconnected,destroyed,inkDestroyed=0,0,0,0
local ink={destroy=function()inkDestroyed+=1 end}
local CAS={UnbindAction=function() unbound+=1 end}
local camera={CameraType="Scriptable"}
local workspace={CurrentCamera=camera}
local Enum={CameraType={Custom="Custom"}}
local previousCameraType,previousSubject,previousFrame,previousFov=nil,{Parent=true},"saved",70
local part={Parent=true,LocalTransparencyModifier=1}
local altered={[part]=0.3}
local surface={Destroy=function() destroyed+=1 end}
local roller={Destroy=function() destroyed+=1 end}
local cylinder,handle,sound={},{},{}
local strokes={1}
local gui={Visible=false,IsA=function() return true end}
local onDestroy,viewUnbound,inputDisconnected=nil,0,0
local screen={FindFirstChild=function() return gui end,Destroying={Once=function(_,fn)onDestroy=fn end}}
local RunService={UnbindFromRenderStep=function()viewUnbound+=1 end}
local beganConnection={Disconnect=function()inputDisconnected+=1 end}
local changedConnection=beganConnection
local endedConnection=beganConnection
local died,removed,deathConnection
local humanoid={Died={Once=function(_,fn)
    died=fn;return {Disconnect=function() disconnected+=1 end}
end}}
local player={CharacterRemoving={Connect=function(_,fn) removed=fn;return {Disconnect=function()inputDisconnected+=1 end}end}}
'''
cases = {
    "death_clears_input_and_effects": '''
died()
assert(not active and not held and touch==nil and #queue==0 and current==nil and inflight==nil)
assert(not toolbar.Visible and not inspectPending and destroyed==2 and disconnected==1 and inkDestroyed==1 and ink==nil)
''',
    "camera_and_visibility_restored": '''
stop()
assert(camera.CameraType=="Custom" and camera.CameraSubject==previousSubject)
assert(camera.CFrame=="saved" and camera.FieldOfView==70 and gui.Visible)
assert(part.LocalTransparencyModifier==0.3 and #strokes==0 and inkDestroyed==1)
''',
    "removal_fallback": '''
removed();assert(not active and not toolbar.Visible and unbound==1)
''',
    "repeated_close_is_safe": '''
stop();died();removed();stop()
assert(destroyed==2 and disconnected==1 and unbound==1 and inkDestroyed==1,"Cleanup repeated")
''',
    "camera_removed_during_cleanup": '''
workspace.CurrentCamera=nil;died()
assert(not active and destroyed==2 and gui.Visible,"Missing camera prevented cleanup")
''',
}
start = source.index("\tscreen.Destroying:Once(")
finish = source.index("\n\treturn {", start)
teardown = source[start:finish]
start=source.index("\tlocal function enter(")
finish=source.index("\n\t\tlocal camera = workspace.CurrentCamera",start)
entry_guard=source[start:finish]+"\n entered+=1\nend\n"
cases["screen_destroy_releases_surface_and_input"] = '''
onDestroy()
local entered=0
'''+entry_guard+'''
enter({},{});assert(entered==0 and disposed,"Late callback recreated destroyed painting view")
assert(not active and inkDestroyed==1 and destroyed==2 and viewUnbound==1 and inputDisconnected==4,"Destroyed HUD retained paint graphics or service input")
'''
for name, checks in cases.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + stop + "\n" + hook + "\n" + removal + "\n" + teardown + "\n" + checks)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS PaintLifecycle:", name)
