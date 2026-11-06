#!/usr/bin/env python3
"""Execute actual editor pointer handlers and frame tracking without any placement writes."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
s=(ROOT/'src/client/BuildController.luau').read_text()
a=s.index('\tUIS.InputBegan:Connect');b=s.index('\n\tplayer.CharacterRemoving',a);handlers=s[a:b]
a=s.index('\t\tlocal mouse = if touch then');b=s.index('\n\t\tmodel:PivotTo(',a);tracking=s[a:b]
header=r'''
local active,waiting,pinned,mouseHeld=true,false,true,false
local touch=nil
local Vector2={};local meta={__add=function(a,b)return Vector2.new(a.X+b.X,a.Y+b.Y)end}
function Vector2.new(x,y)return setmetatable({X=x,Y=y},meta)end
local pointer,mouse,inset=Vector2.new(20,20),Vector2.new(30,40),Vector2.new(0,32)
local callbacks={};local disconnected=0
local function signal(name)return {Connect=function(_,fn)callbacks[name]=fn;return{Disconnect=function()disconnected+=1 end}end}end
local focused=nil
local UIS={TouchEnabled=false,MouseEnabled=true,InputBegan=signal("began"),InputChanged=signal("changed"),InputEnded=signal("ended"),WindowFocusReleased=signal("focus"),GetMouseLocation=function()return mouse end,GetFocusedTextBox=function()return focused end}
local GuiService={GetGuiInset=function()return inset end}
local Enum={UserInputType={MouseButton1="MouseButton1",Touch="Touch"},KeyCode={Escape="Escape",Q="Q",R="R",G="G",Return="Return"}}
local bar={AbsolutePosition=Vector2.new(0,300)}
local allowed,aimed,drawn=true,0,0
local last=nil
local function aim(p)aimed+=1;last=p;return allowed end
local function render()drawn+=1 end
local function stop()error("Unexpected stop")end
local function rotate()end
local function toggleMode()end
local function confirmPlacement()error("Pointer sent placement")end
local function tick()
''' + tracking + r'''
end
'''
checks=r'''
local function began(kind,processed)
 local input={UserInputType=kind,KeyCode="None",Position=pointer}
 callbacks.began(input,processed==true);return input
end
local function ended(input)callbacks.ended(input)end
tick();assert(aimed==0,"Installed item moved from its pin on hover")
local press=began("MouseButton1")
assert(mouseHeld and not pinned,"Mouse down pinned immediately and disabled drag")
mouse=Vector2.new(50,70);local calls=aimed;tick();assert(aimed==calls+1 and last==mouse and not pinned,"Held mouse did not track floor")
ended(press);assert(not mouseHeld and pinned and last==mouse,"Mouse release did not pin final point")
calls=aimed;mouse=Vector2.new(80,90);tick();assert(aimed==calls,"Released pinned item followed hover")
press=began("MouseButton1");allowed=false;ended(press);assert(not pinned and not mouseHeld,"Invalid release fixed a pose")
allowed=true;pinned=true;began("MouseButton1",true);assert(not mouseHeld and pinned,"UI press started drag")
focused={};began("MouseButton1");assert(not mouseHeld and pinned,"Typing started drag");focused=nil
waiting=true;began("MouseButton1");assert(not mouseHeld and pinned,"Pending request started drag");waiting=false
local t=began("Touch");assert(touch==t and not pinned)
local other=began("MouseButton1");assert(not mouseHeld and touch==t,"Mouse stole Touch")
callbacks.changed({Position=Vector2.new(1,1)});assert(pointer.X==20,"Foreign touch moved active finger")
t.Position=Vector2.new(60,80);callbacks.changed(t);UIS.TouchEnabled=true;tick();assert(last.X==60 and last.Y==112,"Touch tracking changed inset conversion")
ended(t);assert(touch==nil and pinned and last.Y==112,"Touch release did not pin")
UIS.TouchEnabled=false;press=began("MouseButton1");local t2=began("Touch");assert(touch==nil and mouseHeld,"Touch stole mouse drag")
assert(callbacks.focus,"Focus loss handler missing");callbacks.focus();assert(not mouseHeld and touch==nil and not pinned,"Focus loss retained gesture/pin")
ended(press);assert(not pinned,"Late mouse up after focus loss pinned")
pinned=true;callbacks.focus();assert(pinned,"Idle focus loss changed a selected position")
press=began("MouseButton1");waiting=true;pinned=true;callbacks.focus();assert(not mouseHeld and pinned,"Focus loss changed pending pose")
ended(press);assert(pinned,"Late up changed pending pose")
waiting=false;active=false;calls=aimed;began("MouseButton1");ended(press);assert(aimed==calls,"Closed editor accepted pointer")
print("PASS BuildDrag: actual mouse drag/release/pin, hover, UI/focus/pending guards, Touch ownership/inset and focus loss")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(header+handlers+checks);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)

# Reject toolbar/top inset/offscreen before any ray query, including a release.
a=s.index('\tlocal function aim(');b=s.index('\n\t\tlocal ray =',a)
guard=s[a:b]+'\n queries+=1;return true\nend\n'
probe=r'''
local snapshot,floor={},{}
local camera={ViewportSize={X=640,Y=480}}
local workspace={CurrentCamera=camera}
local GuiService={GetGuiInset=function()return {X=0,Y=32}end}
local bar={AbsolutePosition={X=0,Y=300}}
local queries=0
''' + guard + r'''
for _,p in {{X=-1,Y=50},{X=640,Y=50},{X=50,Y=31},{X=50,Y=332},{X=50,Y=400},{X=0/0,Y=50},{X=50,Y=0/0},{X=math.huge,Y=50},{X=50,Y=-math.huge}}do assert(not aim(p),"UI/outside/invalid release reached floor query")end
assert(queries==0)
assert(aim({X=30,Y=100})and queries==1,"Working area no longer queries floor")
snapshot=nil;assert(not aim({X=30,Y=100})and queries==1)
snapshot={};floor=nil;assert(not aim({X=30,Y=100})and queries==1)
floor={};workspace.CurrentCamera=nil;assert(not aim({X=30,Y=100})and queries==1)
print("PASS BuildDrag: actual aim preflight blocks toolbar/inset/offscreen/invalid and missing state before raycast")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(probe);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)

# Constructor state must preserve a real placement, while storage starts unpinned.
a=s.index('\t\titem = owned',s.index('\tlocal function enter('));b=s.index('\n\t\toldType =',a)
entry=s[a:b]
probe=r'''
local item,snapshot,ghost,floor,active,deathConnection,pinned,mouseHeld,mode,waiting,sequence,sentSequence,x,z,rotation
local created,base,s={},{},{}
local humanoid={Died={Once=function()return {}end}}
local screen={SetAttribute=function(_,name,v)assert(name=="Building"and v)end}
local function stop()error("Unexpected exit")end
local function initialize(owned)
''' + entry + r'''
end
mouseHeld=true
local owned={id="owned",placed={x=8,z=6,rotationY=105}}
initialize(owned);assert(pinned and not mouseHeld and x==8 and z==6 and rotation==105 and mode=="Free","Opening installed item moved/unpinned its original pose")
assert(owned.placed.x==8 and item==owned)
initialize({id="stored"});assert(not pinned and not mouseHeld and x==5 and z==3 and rotation==0 and mode=="Grid","Stored furniture acquired a false chosen spot")
print("PASS BuildDrag: actual enter preserves installed pose and starts storage without a selected position")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(probe);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
