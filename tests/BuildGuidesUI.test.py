#!/usr/bin/env python3
"""Run the complete local guide renderer with deterministic Roblox object/transform boundaries."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/BuildGuidesController.luau").read_text()
body = source[source.index("function Controller.start("):source.rindex("\nreturn Controller")]
header = r'''
local Layout=require("../src/server/Domain/Furniture").layout
local Strings=require("../src/shared/Strings")
local Controller={}
local pool={}
local Instance={new=function(kind)
 local o={ClassName=kind,Transparency=0}
 table.insert(pool,o)
 function o:Destroy()
  for _,child in pool do if child.Parent==self then child:Destroy()end end
  self.Destroyed=true;self.Parent=nil
 end
 return o
end}
local function find(name)
 for i=#pool,1,-1 do if pool[i].Name==name and not pool[i].Destroyed then return pool[i]end end
 error("Missing guide "..name)
end
local Vector3={}
local vmeta={__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end}
function Vector3.new(x,y,z)return setmetatable({X=x,Y=y,Z=z},vmeta)end
local CFrame={}
local cmeta={}
cmeta.__mul=function(a,b)
 local c,s=math.cos(a.angle),math.sin(a.angle)
 return setmetatable({X=a.X+c*b.X+s*b.Z,Y=a.Y+b.Y,Z=a.Z-s*b.X+c*b.Z,angle=a.angle+b.angle},cmeta)
end
function CFrame.new(x,y,z)
 if type(x)=="table"then return setmetatable({X=x.X,Y=x.Y,Z=x.Z,angle=0},cmeta)end
 return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,angle=0},cmeta)
end
function CFrame.Angles(_,y,_)return setmetatable({X=0,Y=0,Z=0,angle=y},cmeta)end
local Color3={fromRGB=function(r,g,b)return r..":"..g..":"..b end}
local UDim2={fromOffset=function(x,y)return {X=x,Y=y}end,fromScale=function(x,y)return {X=x,Y=y}end}
local Enum={Material={SmoothPlastic=1},Font={GothamBold=1},SurfaceType={Smooth=1}}
local workspace={}
local language="en"
local function lang()return language end
local base={Position=Vector3.new(64,-.5,128),Size=Vector3.new(32,1,24)}
'''
checks = r'''
local api=Controller.start(base,{width=3,depth=2},Layout,lang)
local root=find("FurnitureGuides")
assert(root.Parent==workspace and #pool==72,"Guide budget is not bounded")
local parts,lines=0,0
for _,node in pool do
 if node.ClassName=="Part"then
  parts+=1
  assert(node.Anchored and not node.CanCollide and not node.CanQuery and not node.CanTouch and not node.CastShadow,"Guide interferes with physics or raycast")
  assert(node.CFrame.Y>0 and node.CFrame.Y<.2,"Guide outside floor overlay")
  if node.Name:sub(1,4)=="Grid"then lines+=1 end
 end
end
assert(parts==67 and lines==54,"Unexpected physical geometry budget")
for _,locale in {"ru","en"}do
 language=locale;api.update(5,3,0,"Grid",false,"Checking")
 assert(find("PassageLabel").Text==Strings.text(locale,"buildPassage"),"Passage not localized")
 assert(find("SpawnLabel").Text==Strings.text(locale,"buildSpawn"),"Spawn not localized")
end
local first=find("Footprint1")
local a=first.CFrame
api.update(5,3,90,"Grid",true,"Valid")
local b=first.CFrame
assert(math.abs(a.X-(64+5))<.001 and math.abs(a.Z-(128+3-1))<.001,"Footprint ignores room origin/dimensions")
assert(math.abs(b.X-(64+5-1))<.001 and math.abs(b.Z-(128+3))<.001,"Rectangular footprint did not rotate")
assert(first.Color==Color3.fromRGB(103,193,130),"Unconfirmed footprint shown valid")
api.update(5,3,90,"Free",false,"Blocked")
assert(first.Color==Color3.fromRGB(213,105,92),"Refusal not visible")
for _,node in pool do if node.Name and node.Name:sub(1,4)=="Grid"then assert(node.Transparency==1,"Free mode kept snap grid")end end
api.update(5,3,90,"Grid",false,"Checking")
for _,node in pool do if node.Name and node.Name:sub(1,4)=="Grid"then assert(node.Transparency<1,"Grid mode lost snap grid")end end
for _=1,120 do api.update(5,3,90,"Grid",false,"Checking")end
assert(#pool==72,"Update allocates more objects")
local other=Controller.start({Position=Vector3.new(0,-.5,0),Size=base.Size},{width=2,depth=2},Layout,lang)
other.update(8,6,0,"Free",true,"Valid")
assert(first.Color==Color3.fromRGB(232,190,94),"Another editor changed this renderer")
api.destroy();api.destroy();api.update(9,3,0,"Grid",true,"Valid")
assert(root.Destroyed and first.Destroyed,"Destroy retained guide objects")
local alive=0;for _,node in pool do if not node.Destroyed then alive+=1 end end
assert(alive==72,"Destroy removed another editor or leaked objects")
other.destroy();for _,node in pool do assert(node.Destroyed,"Final cleanup leaked object")end
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + body + "\n" + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS BuildGuidesUI: fixed budget, physics/raycast exclusion, translated origin, rotation, Grid/Free, status, isolation and cleanup")
