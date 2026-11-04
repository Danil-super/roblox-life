#!/usr/bin/env python3
"""Execute actual paint feedback: predictions never become confirmed progress."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/PaintController.luau").read_text()
start = source.index("\tlocal function render(): ()")
render = source[start:source.index("\n\tlocal function enter(", start)]
header = '''
local View=require("../src/shared/PaintView")
local Config=require("../src/shared/PaintConfig")
local snapshot={count=0,mask=string.rep("0",96),error=nil}
local function language()return "en"end
local Strings={text=function(_,key)
    return if key=="paintProgress" then "%s · %d%% / %d%%" else key
end}
local UDim2={fromScale=function(x,y)return {x=x,y=y}end}
local title,review,leave,fill={},{},{},{}
local cells,strokes={},{}
for i=1,96 do cells[i]={};strokes[i]={}end
local predictions={[1]=os.clock()}
local missing=false
'''
checks = '''
render()
assert(fill.Size.x==0 and cells[1].BackgroundTransparency==.25,"Prediction invented confirmed area")
snapshot.count=76;snapshot.mask=string.rep("1",76)..string.rep("0",20);missing=true
render()
assert(title.Text=="paintMissing · 79% / 80%","Missing area instruction unclear")
for i=1,96 do assert(strokes[i].Enabled==(i>76),"Wrong gap highlighted")end
snapshot.count=77;snapshot.mask=string.rep("1",77)..string.rep("0",19)
render()
assert(title.Text=="paintCovered · 80% / 80%" and fill.Size.x==77/96,"Threshold readiness missing")
for _,s in strokes do assert(not s.Enabled,"Unnecessary exact-coverage demand")end
snapshot.error="Drying";render()
assert(title.Text=="paintWait · 80% / 80%","Covered wall falsely asks for more paint")
assert(snapshot.count==77 and snapshot.error=="Drying","Rendering changed authoritative state")
snapshot.error=nil;render();assert(title.Text:find("paintCovered",1,true))
snapshot.count=96;render();assert(fill.Size.x==1,"Full bar failed")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + render + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS PaintFeedbackUI: predictions, gaps, threshold, waiting and no state mutation")
