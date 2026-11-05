#!/usr/bin/env python3
"""Exercise actual decoration factory and style replacement with geometry/physics bounds."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
factory = (ROOT / 'src/assets/ClientDecorModels.luau').read_text().rsplit('return Models', 1)[0]
scene = (ROOT / 'src/server/ClientScene.luau').read_text()
apply = scene[scene.index('\tlocal current ='):scene.index('\n\treturn { resident =')]
header = r'''
local Styles=require("../src/server/Domain/ClientRoomConfig")
local pool={}
local Instance={new=function(kind)
 local n={ClassName=kind,attributes={}};table.insert(pool,n)
 function n:SetAttribute(k,v)self.attributes[k]=v end
 function n:GetChildren()local r={};for _,o in pool do if not o.dead and o.Parent==self then table.insert(r,o)end end;return r end
 function n:Destroy()if self.dead then return end;for _,o in self:GetChildren()do o:Destroy()end;self.dead=true;self.Parent=nil end
 function n:ClearAllChildren()for _,o in self:GetChildren()do o:Destroy()end end
 function n:PivotTo(cf)self.pivot=cf end
 return n
end}
local Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end}
local CFrame={}
local meta={}
function CFrame.new(x,y,z)
 if type(x)=="table"then return CFrame.new(x.X,x.Y,x.Z)end
 return setmetatable({p={x or 0,y or 0,z or 0},r={{1,0,0},{0,1,0},{0,0,1}}},meta)
end
function meta.__mul(a,b)
 local c=CFrame.new()
 for i=1,3 do
  c.p[i]=a.p[i];for k=1,3 do c.p[i]+=a.r[i][k]*b.p[k]end
  for j=1,3 do c.r[i][j]=0;for k=1,3 do c.r[i][j]+=a.r[i][k]*b.r[k][j]end end
 end
 return c
end
function CFrame.Angles(x,y,z)
 local a,b,c=CFrame.new(),CFrame.new(),CFrame.new()
 a.r={{1,0,0},{0,math.cos(x),-math.sin(x)},{0,math.sin(x),math.cos(x)}}
 b.r={{math.cos(y),0,math.sin(y)},{0,1,0},{-math.sin(y),0,math.cos(y)}}
 c.r={{math.cos(z),-math.sin(z),0},{math.sin(z),math.cos(z),0},{0,0,1}}
 return a*b*c
end
CFrame.identity=CFrame.new()
local Color3={new=function(...)return{...}end,fromRGB=function(...)return{...}end}
local Enum={Material={SmoothPlastic=1},SurfaceType={Smooth=1},PartType={Ball=1}}
'''
checks = r'''
local Details=Models
local count=#pool;assert(Details.create("missing")==nil and #pool==count,"Unknown decor allocated geometry")
for kind,b in Details.bounds do
 local model=Details.create(kind);assert(model and model.attributes.DecorKind==kind)
 assert(model.PrimaryPart.Name=="Pivot" and model.PrimaryPart.Transparency==1)
 assert(#model:GetChildren()==b.parts,"Part budget drift: "..kind)
 for _,p in model:GetChildren()do
  assert(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow,"Decor affects physics/rays")
  if p~=model.PrimaryPart then
   for _,sx in {-1,1}do for _,sy in {-1,1}do for _,sz in {-1,1}do
    local corner=p.CFrame*CFrame.new(sx*p.Size.X/2,sy*p.Size.Y/2,sz*p.Size.Z/2)
    assert(math.abs(corner.p[1])<=b.width/2+.001 and math.abs(corner.p[3])<=b.depth/2+.001 and corner.p[2]>=-.001 and corner.p[2]<=b.height+.001,"Geometry outside promised bounds: "..kind.." / "..p.Name)
   end end end
  end
 end
 local other=Details.create(kind);assert(other~=model and other.PrimaryPart~=model.PrimaryPart)
 model:Destroy();assert(not other.dead and not other.PrimaryPart.dead,"Models shared mutable objects");other:Destroy()
end
for name,style in Styles do
 local total=0
 if style.details then for _,d in style.details do
  local b=Details.bounds[d.kind];assert(b,"Missing decor factory")
  local angle=math.rad(d.yaw);local rx=(math.abs(math.cos(angle))*b.width+math.abs(math.sin(angle))*b.depth)/2
  local rz=(math.abs(math.sin(angle))*b.width+math.abs(math.cos(angle))*b.depth)/2
  assert(math.abs(d.x)-rx>6.5 and math.abs(d.x)+rx<15.4 and math.abs(d.z)+rz<11 and d.y>=0,"Decor blocks working strip or crosses room: "..name)
  total+=b.parts
 end end
 assert(total<=32,"Room exceeds custom decoration budget")
end
local Models={create=function()return Instance.new("Model")end}
local room,resident,torso,decor=Instance.new("Model"),Instance.new("Model"),Instance.new("Part"),Instance.new("Folder")
local frame=CFrame.new(64,1,128)
'''
apply_checks = r'''
apply("sunroom","residentNina")
local first=decor:GetChildren();local count=#pool
apply("sunroom","newSpeaker");assert(#pool==count and resident.attributes.SpeakerKey=="newSpeaker","Sync recreated room or lost speaker")
apply("atelier","residentLev")
for _,o in first do assert(o.dead,"Style change retained previous geometry")end
local detailCount=0
for _,o in decor:GetChildren()do if o.attributes.DecorKind then
 detailCount+=1;local d=Styles.atelier.details[tonumber(string.sub(o.Name,7))]
 assert(o.pivot.p[1]==64+d.x and o.pivot.p[2]==1+d.y and o.pivot.p[3]==128+d.z,"Style ignored room floor transform")
end end
assert(detailCount==3,"Atelier decoration missing")
local previous=decor:GetChildren();assert(not pcall(apply,"missing","residentLev"))
for _,o in previous do assert(not o.dead,"Unknown style destroyed existing room")end
apply("intro","residentNina")
for _,o in previous do assert(o.dead,"Returning to intro retained atelier geometry")end
for _,o in decor:GetChildren()do assert(not o.attributes.DecorKind,"Legacy room gained new props")end
print("PASS ClientDecorModels: real factory, tilted bounds, <=32 parts, physics/rays, isolation, cache and style replacement")
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT / '.tools') as script:
    script.write(header + factory + checks + apply + apply_checks)
    script.flush()
    subprocess.run([str(ROOT / '.tools/bin/luau'), script.name], cwd=ROOT, check=True)
