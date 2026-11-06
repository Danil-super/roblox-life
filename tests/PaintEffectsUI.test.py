#!/usr/bin/env python3
"""Run the real preference callback and renderer replacement with bounded adapters."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(source):
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as file:
        file.write(source)
        file.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), file.name], check=True, cwd=ROOT)


main = (ROOT / "src/client/Main.client.luau").read_text()
start = main.index("effectsButton.Activated:Connect(function()")
callback = main[start:main.index("\nend)", start) + len("\nend)")]
run('''
local click
local effectsButton={Activated={Connect=function(_,fn)click=fn end}}
local attrs={}
local screen={GetAttribute=function(_,key)return attrs[key]end,SetAttribute=function(_,key,value)attrs[key]=value end}
local panel={Visible=true}
local status,working="Ready",false
local player={GetAttribute=function()return status end}
local jobs={isWorking=function()return working end}
local renders=0
local function render()renders+=1 end
''' + callback + '''
click();assert(attrs.LightPaintEffects==true and renders==1,"Default effects did not become light")
click();assert(attrs.LightPaintEffects==false and renders==2,"Full effects cannot be restored")
panel.Visible=false;click();assert(not attrs.LightPaintEffects and renders==2,"Hidden callback changed preferences")
panel.Visible=true;status="Saving";click();assert(renders==2,"Saving callback changed preferences")
status="Ready";attrs.Building=true;click();assert(renders==2,"Build callback changed preferences")
attrs.Building=false;working=true;click();assert(renders==2,"Paint callback changed preferences")
working=false;click();assert(attrs.LightPaintEffects and renders==3,"Preference did not recover")
''')

paint = (ROOT / "src/client/PaintController.luau").read_text()
start = paint.index("\tlocal function refreshInk()")
refresh = paint[start:paint.index("\n\tlocal function enter(", start)]
start = paint.index("\tlocal effectsConnection =")
hooks = paint[start:paint.index("\n\tscreen.Destroying:Once(", start)]
run('''
local destroyed,created,updates=0,0,0
local function renderer()return {destroy=function()destroyed+=1 end,update=function(mask,instant)
 assert(mask=="1010" and instant,"Replacement lost accepted mask or animated a restored snapshot")
 updates+=1
end}end
local ink=renderer()
local wall={Size={X=16,Y=6}}
local surface,snapshot,disposed={},{mask="1010",workId="same",sequence=7},false
local screen={GetAttribute=function()return true end}
local GuiService={ReducedMotionEnabled=true}
local function paintColor()return "mint" end
local PaintSurface={new=function(gui,colour,light,motion,width,height)
 assert(width==16 and height==6,"Effect replacement lost wall geometry")
 assert(gui==surface and colour=="mint" and light and motion,"Wrong effect settings")
 created+=1;return renderer()
end}
-- Gameplay context must survive replacement: no command, input or camera adapter exists here.
local held,inflight,queue=true,7,{{points={1}}}
local effectsChanged,motionChanged
function screen:GetAttributeChangedSignal(name)
 assert(name=="LightPaintEffects")
 return{Connect=function(_,fn)effectsChanged=fn;return{}end}
end
function GuiService:GetPropertyChangedSignal(name)
 assert(name=="ReducedMotionEnabled")
 return{Connect=function(_,fn)motionChanged=fn;return{}end}
end
''' + refresh + '\n' + hooks + '''
effectsChanged();motionChanged()
assert(destroyed==2 and created==2 and updates==2,"Replacement leaked or kept both renderers")
assert(held and inflight==7 and #queue==1 and snapshot.workId=="same" and snapshot.sequence==7,"Cosmetic replacement reset gameplay")
surface=nil;refreshInk();assert(ink==nil and destroyed==3 and created==2,"Closed wall retained ink")
surface={};disposed=true;refreshInk();assert(ink==nil and created==2,"Destroyed HUD recreated graphics")
''')
print("PASS PaintEffectsUI: session toggle, hidden/busy/work guards, accepted-mask replacement, context and cleanup")
