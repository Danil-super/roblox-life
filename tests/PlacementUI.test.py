#!/usr/bin/env python3
"""Exercise real editor controls with delayed replies and repeated input."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/BuildController.luau").read_text()
a = source.index("\tlocal function toggleMode(): ()")
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
for _,name in {"Mode","RotateLeft","Rotate","Cancel","Confirm"} do
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
home_source=(ROOT/'src/client/HomeController.luau').read_text()
k=home_source.index('builder.enter(owned, current)')
a=home_source.rfind('\t\t\tb.Activated:Connect(function()',0,k)
b=home_source.index('\n\t\t\tend)',k)+len('\n\t\t\tend)')
placement_entry=home_source[a:b]
header='''
local clicked
local b={Activated={Connect=function(_,fn)clicked=fn end}}
local state={available=true,nearHome=true}
local purchase,storing=nil,nil
local inventory={Visible=false}
local building=false
local entered=0
local owned={id="bookcase"}
local builder={isActive=function()return building end,enter=function()entered+=1;building=true end}
local function hidePanels()inventory.Visible=false end
'''
checks='''
clicked();assert(entered==0,"Hidden inventory click reopened the editor")
inventory.Visible=true;building=true;clicked();assert(entered==0,"Stale click replaced an active/pending editor")
building=false;clicked();assert(entered==1 and building,"Visible inventory stopped opening the editor")
clicked();assert(entered==1,"Repeated click restarted the editor")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as script:
    script.write(header+placement_entry+checks);script.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),script.name],cwd=ROOT,check=True)
print('PASS PlacementUI: hidden/repeated inventory clicks preserve the active or pending editor')
