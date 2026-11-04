#!/usr/bin/env python3
"""Execute the actual surface renderer with deterministic GUI/tween boundaries."""
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'src/client/PaintSurfaceController.luau').read_text()
a=source.index('function Surface.new(')
b=source.index('\nreturn Surface',a)
body=source[a:b]
header=r'''
local Field=require("../src/shared/PaintSurface")
local Config=require("../src/shared/PaintConfig")
local Surface={}
local created,played,cancelled,destroyed=0,0,0,0
local instances={}
local Instance={new=function(kind)
 created+=1
 local obj={ClassName=kind,Destroy=function(self)self.Destroyed=true end}
 table.insert(instances,obj);return obj
end}
local UDim2={fromScale=function(x,y)return {x=x,y=y}end}
local Vector2={new=function(x,y)return{x=x,y=y}end}
local UDim={new=function()return 0 end}
local TweenInfo={new=function()return 0 end}
local Enum={EasingStyle={Quad=0},EasingDirection={Out=0}}
local Tweens={Create=function(_,frame,_,goal)
 return {Play=function()played+=1;frame.BackgroundTransparency=goal.BackgroundTransparency end,
 Cancel=function()cancelled+=1 end,Destroy=function()destroyed+=1 end}
end}
local function child(name)
 for _,v in instances do if v.Name==name then return v end end
 error("Missing "..name)
end
'''
checks=r'''
local gui={}
local view=Surface.new(gui,{})
local budget=created
assert(budget==898,"Unexpected renderer allocation budget")
local blank=string.rep("0",96)
view.update(blank,true)
assert(played==0 and child("Pixel40").BackgroundTransparency==1,"Blank snapshot painted or animated")
for i=1,200 do view.predict(.5,.5,1,1);view.step(1)end
assert(created==budget,"Pointer motion allocated new GUI")
assert(child("Pixel40").BackgroundTransparency==1 and played==0,"Prediction mutated accepted paint")
view.step(1.34);assert(child("Mark1").Visible,"Prediction expired too early")
view.step(1.35);assert(not child("Mark1").Visible,"Prediction did not expire")
for _,bad in {0/0,math.huge,-1,2}do view.predict(bad,.5,1,2)end
assert(not child("Mark1").Visible and created==budget,"Invalid pointer created a mark")
view.update(string.rep("0",39).."1"..string.rep("0",56))
local first=played
assert(first>0 and first<864,"Single cell did not animate a local region")
view.update(string.rep("0",39).."1"..string.rep("0",56));view.step(4)
assert(played==first,"Unchanged mask restarted tweens")
view.update(string.rep("1",96))
assert(cancelled>0,"Updated target retained previous animation")
local latest=played
view.destroy();assert(destroyed==latest and cancelled==latest,"Renderer did not release every tween")
assert(child("Ink").Destroyed and child("Predictions").Destroyed,"Layers survived cleanup")
view.destroy();view.update(blank);view.predict(.5,.5,1,5);view.step(5)
assert(created==budget and played==latest and destroyed==latest,"Closed renderer revived or double-destroyed")
local other=Surface.new({},{});other.update(blank,true)
assert(created==budget*2,"New wall did not receive an independent renderer")
other.destroy()
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(header+body+'\n'+checks);f.flush()
 subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
print('PASS PaintSurfaceUI: bounded pool, accepted-only field, expiry, tween dedup/replacement, cleanup and isolation')
