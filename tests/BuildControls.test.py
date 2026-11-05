#!/usr/bin/env python3
"""Execute actual editor commands and keyboard dispatch with a controlled clock."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/BuildController.luau").read_text()
a = source.index("\tlocal function toggleMode(): ()")
commands = source[a:source.index("\n\tlocal function enter(", a)]
a = source.index("\tUIS.InputBegan:Connect")
keyboard = source[a:source.index("\n\tUIS.InputChanged:Connect", a)]
header = r'''
local PlacementFlow=require("../src/shared/PlacementFlow")
local now,serial=0,0
local os={clock=function()return now end}
local Http={GenerateGUID=function()serial+=1;return "request-"..serial end}
local active,pinned,valid,waiting=true,true,true,false
local item={id="plant"}
local snapshot={available=true,editorId="editor",revision=2}
local confirmedAt,x,z,rotation,mode=0,8,6,0,"Grid"
local reason,pending="Valid",nil
local changes,stops=0,0
local function change()changes+=1;valid=false end
local function render()end
local function stop()stops+=1 end
local function pose()return{x=x,z=z,rotationY=rotation,mode=mode}end
local sent={}
local function send(action,packet)assert(action=="place");table.insert(sent,packet)end
local buttons={}
for _,name in {"Mode","RotateLeft","Rotate","Confirm","Cancel"}do
 buttons[name]={Activated={Connect=function(_,fn)buttons[name].fire=fn end}}
end
local inputBegan
local focused=nil
local UIS={InputBegan={Connect=function(_,fn)inputBegan=fn end},GetMouseLocation=function()return{}end,GetFocusedTextBox=function()return focused end}
local Enum={KeyCode={Escape="Escape",Q="Q",R="R",G="G",Return="Return"},UserInputType={MouseButton1="MouseButton1",Touch="Touch"}}
local touch,pointer=nil,nil
local Vector2={new=function(x,y)return{X=x,Y=y}end}
local function aim()return false end
local function key(k,processed)inputBegan({KeyCode=k,UserInputType="Keyboard"},processed==true)end
'''
cases = {
    "opposite_and_wrap": r'''
buttons.RotateLeft.fire();assert(rotation==270 and changes==1,"Grid reverse did not wrap")
buttons.Rotate.fire();assert(rotation==0 and changes==2,"Right did not undo left")
mode="Free";rotation=105
buttons.RotateLeft.fire();assert(rotation==90,"Free reverse changed step")
buttons.Rotate.fire();assert(rotation==105,"Free forward did not restore angle")
rotation=0;buttons.RotateLeft.fire();assert(rotation==345,"Free wrap negative")
buttons.Rotate.fire();assert(rotation==0,"Free wrap positive")
assert(x==8 and z==6 and #sent==0 and snapshot.revision==2,"Rotation moved/saved furniture")
''',
    "keyboard_matches_buttons": r'''
key("Q");assert(rotation==270)
key("R");assert(rotation==0)
key("G");assert(mode=="Free")
key("R");assert(rotation==15)
key("Q");assert(rotation==0)
key("G");assert(mode=="Grid"and #sent==0)
''',
    "processed_and_closed": r'''
for _,k in {"Q","R","G","Return"}do key(k,true)end
assert(rotation==0 and mode=="Grid"and changes==0 and #sent==0,"Processed input escaped UI")
focused={};for _,k in {"Q","R","G","Return"}do key(k)end
assert(changes==0 and #sent==0,"Typing changed editor state");focused=nil
active=false
for _,k in {"Q","R","G","Return"}do key(k)end
buttons.RotateLeft.fire();buttons.Rotate.fire();buttons.Mode.fire();buttons.Confirm.fire()
assert(changes==0 and #sent==0,"Closed editor accepted stale input")
''',
    "enter_guards_and_exact_retry": r'''
pinned=false;key("Return");pinned=true;valid=false;key("Return")
valid=true;snapshot.available=false;key("Return")
assert(#sent==0,"Enter bypassed placement validation")
snapshot.available=true;key("Return");key("Return")
assert(#sent==1 and pending and waiting,"Enter duplicated placement")
local id=pending.requestId
for _,k in {"Q","R","G","Escape"}do key(k)end
buttons.RotateLeft.fire();buttons.Rotate.fire();buttons.Mode.fire();buttons.Cancel.fire()
assert(rotation==0 and mode=="Grid"and changes==0 and stops==0,"Pending controls changed intent")
now=7.999;key("Return");assert(#sent==1,"Retry too early")
now=8;key("Return");assert(#sent==2 and serial==1,"Retry created new intent")
assert(sent[2].requestId==id and sent[2].revision==2 and sent[2].pose.x==8 and sent[2].pose.rotationY==0,"Retry changed saved pose")
''',
}
for name, checks in cases.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + commands + keyboard + checks)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS BuildControls:", name)
