#!/usr/bin/env python3
"""Exercise real editor controls with delayed replies and repeated input."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/BuildController.luau").read_text()
a = source.index("\tbuttons.Mode.Activated:Connect")
b = source.index("\n\tlocal function enter(", a)
body = source[a:b]
header = r''' 
local PlacementFlow = require("../src/shared/PlacementFlow")
local now, generated = 0, 0
local os = {clock=function() return now end}
local Http = {GenerateGUID=function() generated+=1;return "request-"..generated end}
local active, pinned, valid, waiting = true, true, true, false
local pending = nil
local item = {id="plant"}
local snapshot = {available=true,editorId="editor",revision=2}
local confirmedAt, x, z, rotation, mode = 0, 5, 3, 0, "Grid"
local reason, stopped = "Valid", 0
local function pose() return {x=x,z=z,rotationY=rotation,mode=mode} end
local function render() end
local function stop() stopped+=1 end
local function change() end
local buttons = {}
for _,name in {"Mode","Rotate","Cancel","Confirm"} do
    buttons[name]={Activated={Connect=function(_,fn) buttons[name].fire=fn end}}
end
local sent={}
local function send(action,packet) assert(action=="place");table.insert(sent,packet) end
'''
cases = {
    "double_clicks_and_timeout": r'''
buttons.Confirm.fire();buttons.Confirm.fire()
assert(#sent==1 and generated==1 and waiting)
buttons.Mode.fire();buttons.Rotate.fire();buttons.Cancel.fire()
assert(mode=="Grid" and rotation==0 and stopped==0,"Pending controls changed the intent")
now=8;buttons.Confirm.fire();buttons.Confirm.fire()
assert(#sent==2 and generated==1,"Retry generated another operation")
assert(sent[1].requestId==sent[2].requestId and sent[2].revision==2)
assert(sent[2].pose.x==5 and sent[2].pose.rotationY==0)
sent[1].pose.x=50
assert(pending.pose.x==5 and sent[2].pose.x==5,"Transport mutated retained intent")
''',
    "retry_keeps_original_room_revision_and_pose": r'''
buttons.Confirm.fire()
snapshot.revision=99;x=12;z=8;rotation=180;valid=false;now=9
buttons.Confirm.fire()
assert(#sent==2 and sent[2].revision==2 and sent[2].pose.x==5 and sent[2].pose.rotationY==0)
''',
    "invalid_or_unavailable_preview_never_commits": r'''
valid=false;buttons.Confirm.fire();assert(#sent==0)
valid=true;now=1;buttons.Confirm.fire();assert(#sent==0)
now=0;snapshot.available=false;buttons.Confirm.fire();assert(#sent==0)
''',
}
for name, checks in cases.items():
    with tempfile.NamedTemporaryFile("w",suffix=".luau",dir=ROOT/".tools") as f:
        f.write(header+body+checks);f.flush()
        subprocess.run([str(ROOT/".tools/bin/luau"),f.name],cwd=ROOT,check=True)
    print("PASS PlacementUI:",name)
