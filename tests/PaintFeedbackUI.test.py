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
local snapshot={count=0,mask=string.rep("0",96),error=nil,phase="Painting"}
local function language()return "en"end
local Strings={text=function(_,key)
    return if key=="paintProgress" then "%s · %d%% / %d%%" elseif key=="paintOptional"then "optional %d%%"elseif key=="paintExcellent"then "excellent %d%%"elseif key=="paintPerfect"then "perfect %d%%"elseif key=="surfaceProgress" then "Wall %d / %d" elseif key=="paintGapsShow"then "show %d"elseif key=="paintGapsHide"then "hide %d"else key
end}
local UDim2={fromScale=function(x,y)return {x=x,y=y}end}
local title,review,leave,fill={},{},{},{}
local cells,strokes={},{}
for i=1,96 do cells[i]={};strokes[i]={}end
local receivedMask=nil
local ink={update=function(mask)receivedMask=mask end,step=function()end}
local missing=false
local disposed=false
local active,manualGaps=true,false
local cameraReady=true
local toggle
local gaps={Activated={Connect=function(_,fn)toggle=fn end}}
local queue,current,inflight,sequence,inspectPending={17},{23},7,7,false
local held,touch=true,{}
local sends=0
local function send()sends+=1 end
'''
checks = '''
cameraReady=false;render()
assert(not review.Active and not gaps.Active,"Moving camera enabled work controls")
cameraReady=true
render()
assert(fill.Size.x==0 and receivedMask==snapshot.mask,"Visual layer invented confirmed area")
for _,s in strokes do assert(not s.Enabled,"Grid shown during normal painting")end
snapshot.count=76;snapshot.mask=string.rep("1",76)..string.rep("0",20);missing=true
render()
assert(title.Text=="paintMissing · 79% / 80%","Missing area instruction unclear")
for i=1,96 do assert(strokes[i].Enabled==(i>76),"Wrong gap highlighted")end
snapshot.count=77;snapshot.mask=string.rep("1",77)..string.rep("0",19)
render()
assert(title.Text=="optional 80%" and fill.Size.x==77/96,"Threshold readiness missing")
for _,s in strokes do assert(not s.Enabled,"Unnecessary exact-coverage demand")end
manualGaps=true;render()
assert(gaps.Text=="hide 19"and gaps.Active,"Optional gap guide unavailable above acceptance threshold")
for i=1,96 do assert(strokes[i].Enabled==(i>77),"Optional guide lost the remaining accepted-wall gaps")end
manualGaps=false;render()
snapshot.error="Drying";render()
assert(title.Text=="paintWait · 80% / 80%","Covered wall falsely asks for more paint")
assert(snapshot.count==77 and snapshot.error=="Drying" and receivedMask==snapshot.mask,"Rendering changed authoritative state")
snapshot.error=nil;render();assert(title.Text:find("optional",1,true))
snapshot.count=91;render();assert(title.Text=="optional 94%","Excellent goal reached early")
snapshot.count=92;render();assert(title.Text=="excellent 95%","Excellent goal missing")
snapshot.count=96;snapshot.mask=string.rep("1",96);render();assert(fill.Size.x==1,"Full bar failed")
assert(gaps.Text=="paintNoGaps"and not gaps.Active,"Full wall still asks for repairs")
snapshot.surfaceIndex=2;snapshot.surfaceTotal=2;render()
assert(title.Text=="Wall 2 / 2 · perfect 100%","Two-wall toolbar lost current surface")
'''
start = source.index("\tgaps.Activated:Connect(")
toggle_body = source[start:source.index("\n\treview.Activated:Connect(", start)]
toggle_checks = '''
local originalTouch,originalQueue,originalCurrent=touch,queue,current
snapshot.count=77;snapshot.mask=string.rep("1",77)..string.rep("0",19)
missing=true;manualGaps=false;render()
toggle();assert(manualGaps and not missing and gaps.Text=="hide 19","Cannot opt into the last 20%")
for i,s in strokes do assert(s.Enabled==(i>77),"Guide differs from confirmed mask")end
toggle();assert(not manualGaps and gaps.Text=="show 19","Optional guide cannot be hidden")
snapshot.count=10;snapshot.mask=string.rep("1",10)..string.rep("0",86);missing=true;render()
assert(gaps.Text=="hide 86","Automatic Coverage-error guide missing")
toggle();assert(not manualGaps and not missing and gaps.Text=="show 86","Explicit hide did not override automatic guide")
toggle();render();render();assert(manualGaps and gaps.Text=="hide 86","Sync/render reset the user's choice")
for i,s in strokes do assert(s.Enabled==(i>10),"Guide highlighted already confirmed paint")end
assert(snapshot.count==10 and snapshot.mask==receivedMask and snapshot.phase=="Painting" and snapshot.error==nil,"Guide wrote server state")
assert(held and touch==originalTouch and queue==originalQueue and current==originalCurrent and inflight==7 and sequence==7 and sends==0,"Guide changed a gesture or sent a work command")
local function blocked(label)
 manualGaps=false;missing=false;toggle();assert(not manualGaps and not missing,label)
end
active=false;blocked("Inactive renderer accepted a late toggle");active=true
disposed=true;blocked("Destroyed renderer accepted a late toggle");disposed=false
inspectPending=true;blocked("Pending review toggled guide");inspectPending=false
snapshot.phase="SurfaceReady";blocked("Ready surface still allows editing");snapshot.phase="Painting"
snapshot.count=96;blocked("Full wall requested repairs")
local previous=snapshot;snapshot=nil;blocked("Missing snapshot accepted a toggle");snapshot=previous
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + render + toggle_body + checks + toggle_checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS PaintFeedbackUI: confirmed progress, optional gaps below/above threshold, real toggle, guards and unchanged input/packet/server state")
