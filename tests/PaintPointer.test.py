#!/usr/bin/env python3
"""Execute the actual pointer sampling: hover/review/reduced modes cannot paint."""
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
s=(ROOT/'src/client/PaintController.luau').read_text()
needle='\t\tif held and os.clock() - lastSample >= 0.03 then'
a=s.index(needle if needle in s else '\t\tif os.clock() - lastSample >= 0.03 then')
b=s.index('\n\t\tif os.clock() - sentAt',a)
body=s[a:b]
header=r'''
local Config=require("../src/shared/PaintConfig")
local Aim=require("../src/shared/PaintAim")
local now=10;local os={clock=function()return now end}
local lastSample,lastHit=0,0
local held,touch=false,nil
local inspectPending=false
local light,motion=false,false
local screen={GetAttribute=function()return light end}
local GuiService={ReducedMotionEnabled=false}
local Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end}
local Vector2={};local vec={__add=function(a,b)return Vector2.new(a.X+b.X,a.Y+b.Y)end}
function Vector2.new(x,y)return setmetatable({X=x,Y=y},vec)end
local pointer,inset=Vector2.new(200,150),Vector2.new(0,32)
local UIS={TouchEnabled=false,GetMouseLocation=function()return pointer end}
local aimX=0
local camera={ViewportPointToRay=function()return {Origin=Vector3.new(aimX,0,10),Direction=Vector3.new(0,0,-1)}end}
local identity={PointToObjectSpace=function(_,p)return p end,VectorToObjectSpace=function(_,p)return p end}
local target={Size=Vector3.new(18,12,1),CFrame=identity}
local current={points={},starts=true}
local queue={current};local inflight,sequence=7,7
local predicted,updated,hidden=0,0,0
local ink={predict=function()predicted+=1 end}
local pressed,animated=nil,nil
local roller={update=function(_,u,v,p,a)assert(u>=0 and u<=1 and v>=0 and v<=1);updated+=1;pressed=p;animated=a end,hide=function()hidden+=1 end}
local sound={Playing=false}
local function brushScale()return 1 end
local function tick()now+=.04
''' + body + r'''
end
'''
checks=r'''
tick();assert(updated==1 and pressed==false,"Mouse hover has no tool preview")
assert(#current.points==0 and predicted==0 and not sound.Playing and lastHit==0,"Hover invented paint/contact")
held=true;tick();assert(updated==2 and pressed==true and animated and #current.points==1 and predicted==1 and sound.Playing,"Actual contact stopped painting")
tick();assert(#current.points==1 and predicted==1,"Stationary contact duplicated sampled points")
held=false;tick();assert(pressed==false and not sound.Playing and #current.points==1,"Release continued painting")
UIS.TouchEnabled=true;local old=updated;tick();assert(updated==old and hidden>0,"Touch showed hover without a gesture")
held=true;touch={};current={points={},starts=true};tick();assert(updated==old+1 and pressed and #current.points==1,"Touch contact lost tool/stroke")
light=true;tick();assert(animated==false,"Light mode kept decorative motion")
light=false;GuiService.ReducedMotionEnabled=true;tick();assert(animated==false,"ReducedMotion kept decorative motion")
GuiService.ReducedMotionEnabled=false;tick();assert(animated,"Full motion did not recover")
aimX=100;tick();assert(not sound.Playing and lastHit==0,"Leaving wall kept contact sound")
aimX=0;held=false;touch=nil;UIS.TouchEnabled=false;inspectPending=true;old=updated;local count=#current.points;local predictedBefore=predicted
tick();assert(updated==old and #current.points==count and predicted==predictedBefore and not sound.Playing,"Review admitted hover/strokes")
assert(inflight==7 and sequence==7 and #queue==1,"Pointer effects changed packet intent")
print("PASS PaintPointer: actual hover/contact/touch/release/review sampling, no invented coverage, light/reduced and packet context")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(header+checks);f.flush()
 subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
