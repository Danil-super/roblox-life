#!/usr/bin/env python3
"""Run actual editor cleanup with its actual housing exit callback."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/BuildController.luau").read_text()
housing = (ROOT / "src/client/HomeController.luau").read_text()
start = source.index("\tlocal function stop(")
stop = source[start:source.index("\n\tlocal function change()", start)]
start = source.index("\tplayer.CharacterRemoving:Connect")
removal = source[start:source.index('\n\tlocal event =', start)]
start = source.index("update = function(s: Types.Snapshot)")
update = "local " + source[start:source.index("\n\t\tend,", start) + len("\n\t\tend")]
start = housing.index("\tlocal builder = Build.start(")
exit_callback = housing[start:housing.index("\n\tlocal function thumbnail", start)]
start = source.index("\t\tdeathConnection = humanoid.Died:Once")
death_hook = source[start:source.index("\n\t\tmouseHeld = false", start)]
header = r'''
local active, waiting, valid, touch = true, true, true, {}
local mouseHeld=true
local pending = {requestId="place-old"}
local bar = {Visible=true}
local attributes = {}
local screen = {SetAttribute=function(_,key,value) attributes[key]=value end}
local send, language = function() end, function() return "en" end
local inventory, homePanel = {Visible=false}, {Visible=false}
local exits=0
local function show() inventory.Visible=true;exits+=1 end
local function hidePanels() inventory.Visible=false;exits+=1 end
local onExit
local Build={start=function(_,_,_,fn) onExit=fn;return {} end}
local unbound, disconnected = 0, 0
local CAS={UnbindAction=function() unbound+=1 end}
local camera={CameraType="Scriptable"}
local workspace={CurrentCamera=camera}
local oldType, oldSubject, oldFrame, oldFov = "Custom",{Parent=true},"saved",70
local altered, visibility = {}, {}
local destroyed=0
local ghost={Destroy=function() destroyed+=1 end}
local guideDestroyed=0
local guides={destroy=function()guideDestroyed+=1 end}
local item, floor = {}, {}
local deathConnection={Disconnect=function() disconnected+=1 end}
local died
local humanoid={Died={Once=function(_,fn)
    died=fn
    return {Disconnect=function() disconnected+=1 end}
end}}
local removed
local player={CharacterRemoving={Connect=function(_,fn) removed=fn end}}
local snapshot={editorId="old",homeName="Home_1",nearHome=true}
'''
cases = {
    "cancel_returns_inventory": '''
stop()
assert(inventory.Visible and exits==1,"Cancel should return to inventory")
assert(not active and not bar.Visible and destroyed==1 and unbound==1)
assert(camera.CameraType=="Custom" and attributes.Building==false and pending==nil,"Cancel retained an old intent")
''',
    "removal_returns_exploration": '''
removed()
assert(not inventory.Visible and not homePanel.Visible,"Death reopened a modal and hid touch controls")
assert(not active and destroyed==1 and camera.CameraType=="Custom" and pending==nil,"Death retained an old intent")
''',
    "nonce_change_returns_exploration": '''
update({editorId="new",homeName="Home_1",nearHome=true,available=false,items={}})
assert(not active and not inventory.Visible,"Stale editor reopened inventory")
''',
    "left_home_returns_exploration": '''
update({editorId="old",homeName="Home_1",nearHome=false,available=true,items={}})
assert(not active and not inventory.Visible,"Invalid location reopened inventory")
''',
    "repeated_cleanup_is_safe": '''
removed();removed();stop()
assert(destroyed==1 and unbound==1 and exits==1,"Cleanup repeated side effects")
assert(guideDestroyed==1 and guides==nil,"Repeated cleanup retained or destroyed guides twice")
''',
    "death_signal_returns_exploration": '''
died()
assert(not active and not inventory.Visible,"Died signal reopened inventory")
assert(disconnected==1,"Death listener was not released")
''',
    "cancel_releases_listener": '''
stop();died()
assert(inventory.Visible and exits==1 and disconnected==1,"Old death callback affected a closed editor")
''',
}
for name, checks in cases.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + exit_callback + stop + "\n" + removal + "\n" + update + "\n" + death_hook + "\n" + checks)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS BuildLifecycle:", name)

start = source.index("\tscreen.Destroying:Once(function()")
hook = source[start:source.index("\n\treturn {", start)]
destroy_setup = '''
local disposed=false
local focusDisconnected=0
local focusConnection={Disconnect=function()focusDisconnected+=1 end}
local destroyHud
screen.Destroying={Once=function(_,fn)destroyHud=fn end}
local cameraUnbound=0
local RunService={UnbindFromRenderStep=function(_,name)
 assert(name=="FurnitureView","Wrong binding released");cameraUnbound+=1
end}
'''
destroy_checks = '''
destroyHud()
assert(disposed and not active and not inventory.Visible and not bar.Visible,"Destroyed HUD retained editor")
assert(guideDestroyed==1 and guides==nil and destroyed==1 and cameraUnbound==1,"Destroyed HUD retained guides or camera binding")
assert(camera.CameraType=="Custom" and pending==nil,"Destroyed HUD retained camera or placement")
assert(focusDisconnected==1 and not mouseHeld,"Destroyed HUD retained focus observer or drag")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + exit_callback + stop + destroy_setup + hook + destroy_checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS BuildLifecycle: HUD destruction removes guides, clears placement and releases camera binding")
