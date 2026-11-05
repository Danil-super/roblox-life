#!/usr/bin/env python3
"""Execute the complete receipt viewport renderer with bounded Roblox objects."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/PaintResultScene.luau").read_text()
body = source[source.index("function Scene.start("):source.rindex("\nreturn Scene")]
header = r'''
local Finish=require("../src/shared/PaintFinish")
local Config=require("../src/shared/PaintConfig")
local Scene={}
local pool={}
local Instance={new=function(kind)
 local n={ClassName=kind};table.insert(pool,n)
 n.Destroying={Once=function(_,fn)n.onDestroy=fn end}
 function n:IsA(class)return class==self.ClassName end
 function n:GetChildren()local children={};for _,o in pool do if o.Parent==self and not o.dead then table.insert(children,o)end end;return children end
 function n:Destroy()
  if self.dead then return end;self.dead=true
  if self.onDestroy then self.onDestroy()end
  for _,o in self:GetChildren()do o:Destroy()end
  self.Parent=nil
 end
 return n
end}
local Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end}
local CFrame={}
local meta={__mul=function(a,b)return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},getmetatable(a))end}
function CFrame.new(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},meta)end
function CFrame.Angles()return CFrame.new()end
function CFrame.lookAt(from)return CFrame.new(from.X,from.Y,from.Z)end
local UDim2={fromOffset=function(x,y)return{x=x,y=y}end,new=function(xs,xo,ys,yo)return{xs=xs,xo=xo,ys=ys,yo=yo}end}
local Color3={fromRGB=function(r,g,b)return r..":"..g..":"..b end,new=function(r,g,b)return r..":"..g..":"..b end}
local Enum={Font={GothamMedium=1},SurfaceType={Smooth=1},Material={SmoothPlastic=1}}
local function child(parent,name)
 for _,n in parent:GetChildren()do if n.Name==name then return n end end
 error("Missing "..name)
end
local function alive(kind)
 local count=0;for _,n in pool do if not n.dead and (not kind or n.ClassName==kind)then count+=1 end end;return count
end
'''
checks = r'''
local parent=Instance.new("Frame")
local api=Scene.start(parent);local root=child(parent,"Comparison")
assert(alive()==7 and not root.Visible,"Idle preview allocated models")
local receipt={operationId="job:1",primaryColorId="warm-white",finish={columns=12,rows=8,masks={string.rep("1",96)}}}
api.render(receipt,"old")
assert(root.Visible and alive("WorldModel")==2 and alive("Camera")==2,"Preview did not create isolated worlds/cameras")
assert(alive("Part")==8,"Full single wall needs no per-cell parts")
local after=child(child(root,"After"),"Room")
assert(child(after,"Wall1").Color==Color3.new(table.unpack(Config.color)),"Wrong receipt colour")
local count=#pool;for _=1,120 do api.render(receipt,"translated")end
assert(#pool==count,"Ordinary render allocated geometry")
receipt.finish.masks[1]="0"..string.rep("1",95);api.render(receipt,"old")
after=child(child(root,"After"),"Room")
assert(child(after,"Wall1").Color==Color3.fromRGB(145,148,140),"Preview concealed the unpainted base")
assert(math.abs(child(after,"Paint1_0_1").Size.X-110/12)<.001,"Paint strip crossed confirmed gap")
receipt.operationId="job:duo";receipt.primaryColorId="mint";receipt.secondaryColorId="rose"
receipt.finish.masks={string.rep("1",96),string.rep("1",96)};api.render(receipt,"old")
after=child(child(root,"After"),"Room")
assert(child(after,"Wall1").Color==Color3.new(table.unpack(Config.palette.mint))and child(after,"Wall2").Color==Color3.new(table.unpack(Config.palette.rose)),"Two walls became a misleading blended gradient")
receipt.finish.masks={string.rep("10",48),string.rep("10",48)};api.render(receipt,"old")
assert(alive("Part")==110 and alive()<=120,"Alternating mask exceeded viewport object budget")
for _,n in pool do if not n.dead and n.ClassName=="Part"then assert(n.Anchored and not n.CanCollide and not n.CanTouch and not n.CanQuery and not n.CastShadow,"Cosmetic geometry has physics")end end
api.render(nil,"");api.render(nil,"")
assert(not root.Visible and alive("WorldModel")==0 and alive("Part")==0 and alive()==7,"Close retained geometry or churned cameras")
api.render({operationId="legacy"},"No saved preview")
assert(child(root,"Legacy").Visible and child(root,"Legacy").Text=="No saved preview"and alive("WorldModel")==0,"Legacy receipt invented geometry")
local otherParent=Instance.new("Frame");local other=Scene.start(otherParent);other.render(receipt,"old")
root:Destroy();count=#pool;api.render(receipt,"old")
assert(#pool==count and alive("WorldModel")==2,"Destroyed renderer resurrected or removed another preview")
otherParent:Destroy();parent:Destroy();assert(alive()==0,"Destroy HUD leaked viewport objects")
print("PASS PaintResultScene: real renderer, masks/colours, <=118 objects, cache, legacy, isolation, close and destroy")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + body + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
