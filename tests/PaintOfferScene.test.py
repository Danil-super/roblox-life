#!/usr/bin/env python3
"""Execute the plan renderer and real decor factory, including geometry budgets."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/PaintOfferScene.luau").read_text()
body = source[source.index("function Scene.start("):source.rindex("\nreturn Scene")]
decor = (ROOT / "src/assets/ClientDecorModels.luau").read_text()
header = r'''
local Geometry=require("../src/shared/PaintGeometry")
local Config=require("../src/shared/PaintConfig")
local Jobs=require("../src/server/Domain/Jobs")
local Profile=require("../src/server/Domain/Profile")
local Scene={};local pool={}
local Instance={new=function(kind)
 local n={ClassName=kind};table.insert(pool,n)
 n.Destroying={Once=function(_,fn)n.onDestroy=fn end}
 function n:GetChildren()local r={};for _,v in pool do if not v.dead and v.Parent==self then table.insert(r,v)end end;return r end
 function n:Destroy()if self.dead then return end;self.dead=true;if self.onDestroy then self.onDestroy()end;for _,v in self:GetChildren()do v:Destroy()end;self.Parent=nil end
 function n:SetAttribute(name,value)self[name]=value end
 function n:PivotTo(cf)self.pivot=cf;for _,v in self:GetChildren()do v.CFrame=cf*v.CFrame end end
 return n
end}
local Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end}
local CFrame={};local meta={__mul=function(a,b)return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},getmetatable(a))end}
function CFrame.new(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},meta)end
function CFrame.lookAt(from)return CFrame.new(from.X,from.Y,from.Z)end
function CFrame.Angles()return CFrame.new()end
CFrame.identity=CFrame.new()
local Color3={fromRGB=function(r,g,b)return r..":"..g..":"..b end,new=function(r,g,b)return r..":"..g..":"..b end}
local UDim2={new=function()return{}end,fromOffset=function()return{}end}
local Enum={Material={SmoothPlastic=1,WoodPlanks=2},SurfaceType={Smooth=1},PartType={Ball=1}}
local workspace={CurrentCamera={sentinel=true}}
local function live(kind)local n=0;for _,v in pool do if not v.dead and(not kind or v.ClassName==kind)then n+=1 end end;return n end
local function child(parent,name)for _,v in parent:GetChildren()do if v.Name==name then return v end end end
''' + "local Decor=(function()\n" + decor + "\nend)()\n"
checks = r'''
local parent=Instance.new("Frame");local api=Scene.start(parent)
local view=child(parent,"PlanPreview");assert(view,"Selected offer has no 3D plan")
assert(not view.Visible and live("WorldModel")==0 and live("Part")==0 and live("Camera")==1)
local player=Profile.new(7);local offers=Jobs.offers(player)
for _,offer in offers do
 assert(api.render(offer) and view.Visible,"Valid offer has no plan")
 local room=child(view,"Plan");local sizes=Geometry.layout(offer.id)
 assert(live("WorldModel")==1 and live("ViewportFrame")==1 and live("Camera")==1)
 assert(live("Part")<=11 and live()-1<=15,"Plan exceeds its bounded object budget")
 for i,size in sizes do
  local wall=child(room,"Wall"..i);assert(wall.Size.X==size.width and wall.Size.Y==size.height,"Wrong contract geometry")
  local colorId=if i==1 then offer.colorId else offer.secondaryColorId
  assert(wall.Color==Color3.new(table.unpack(Config.palette[colorId])),"Wrong planned material")
 end
 assert((child(room,"Wall2")~=nil)==(#sizes==2),"Secondary wall does not match contract")
 assert(child(room,"planter"),"Existing decor factory was not reused")
 for _,v in pool do if not v.dead and v.ClassName=="Part"then
  assert(v.Anchored and not v.CanCollide and not v.CanTouch and not v.CanQuery and not v.CastShadow,"Preview participates in world physics")
 end end
 local count=#pool;for _=1,50 do api.render(offer)end
 assert(#pool==count and child(view,"Plan")==room,"Same plan/sync allocated models")
 assert(player.wallet.dollars==0 and player.progression.paintingXP==0 and player.jobs.active==nil,"Preview changed authoritative progress")
end
local original=offers[1];api.render(original);local first=child(view,"Plan");local copy=table.clone(original)
copy.reward+=100;copy.unlocked=not copy.unlocked;api.render(copy)
assert(child(view,"Plan")==first,"Price/availability changed cosmetic geometry")
copy.colorId="rose";api.render(copy);assert(first.dead and child(view,"Plan")~=first)
local invalid=table.clone(copy);invalid.id="unknown";assert(not api.render(invalid) and not view.Visible and live("Part")==0)
invalid=table.clone(copy);invalid.secondaryColorId="invalid";assert(not api.render(invalid),"Unexpected second colour fabricated a single-wall plan")
invalid=table.clone(copy);invalid.colorId="invalid";assert(not api.render(invalid) and live("WorldModel")==0)
invalid=table.clone(offers[#offers]);invalid.secondaryColorId=nil;assert(not api.render(invalid),"Incomplete second material fabricated a plan")
api.render(original);local camera=view.CurrentCamera;api.render(nil);api.render(nil)
assert(not view.Visible and live("Part")==0 and live("WorldModel")==0 and view.CurrentCamera==camera,"Hide retained geometry or churned camera")
api.render(original);view:Destroy();local count=#pool
assert(not api.render(original) and #pool==count and live("Part")==0,"Destroyed preview revived")
assert(workspace.CurrentCamera.sentinel,"Plan changed the global gameplay camera")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + body + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS PaintOfferScene: six canonical plans, real decor, colours, <=15 objects, cache, malformed inputs, cleanup and no progress")
