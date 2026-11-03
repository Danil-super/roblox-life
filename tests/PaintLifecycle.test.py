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
start = source.index("\tplayer.CharacterRemoving:Connect")
removal = source[start:source.index("\n\tUIS.InputBegan", start)]
header = r'''
local active,held,touch = true,true,{}
local queue,current,inflight,inspectPending = {{points={1}}},{},7,true
local toolbar={Visible=true}
local unbound,disconnected,destroyed=0,0,0
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
local cells,strokes,predictions={1},{1},{1}
local gui={Visible=false,IsA=function() return true end}
local screen={FindFirstChild=function() return gui end}
local died,removed,deathConnection
local humanoid={Died={Once=function(_,fn)
    died=fn;return {Disconnect=function() disconnected+=1 end}
end}}
local player={CharacterRemoving={Connect=function(_,fn) removed=fn end}}
'''
cases = {
    "death_clears_input_and_effects": '''
died()
assert(not active and not held and touch==nil and #queue==0 and current==nil and inflight==nil)
assert(not toolbar.Visible and not inspectPending and destroyed==2 and disconnected==1)
''',
    "camera_and_visibility_restored": '''
stop()
assert(camera.CameraType=="Custom" and camera.CameraSubject==previousSubject)
assert(camera.CFrame=="saved" and camera.FieldOfView==70 and gui.Visible)
assert(part.LocalTransparencyModifier==0.3 and #cells==0 and #strokes==0)
''',
    "removal_fallback": '''
removed();assert(not active and not toolbar.Visible and unbound==1)
''',
    "repeated_close_is_safe": '''
stop();died();removed();stop()
assert(destroyed==2 and disconnected==1 and unbound==1,"Cleanup repeated")
''',
    "camera_removed_during_cleanup": '''
workspace.CurrentCamera=nil;died()
assert(not active and destroyed==2 and gui.Visible,"Missing camera prevented cleanup")
''',
}
for name, checks in cases.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + stop + "\n" + hook + "\n" + removal + "\n" + checks)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS PaintLifecycle:", name)
