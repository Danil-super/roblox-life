#!/usr/bin/env python3
"""Exercise real room/wall/worksite geometry for every prepared contract layout."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
# Reuse the tested matrix/Instance boundary, including the real configureWalls implementation.
context={'__file__':str(ROOT/'tests/PaintWorksite.test.py')}
exec((ROOT/'tests/PaintWorksite.test.py').read_text().split("checks=r'''")[0],context)
checks=r'''
local templates={"paint-tutorial-v1","paint-mint-v1","paint-rose-v1","paint-duo-v1","paint-sunroom-v1","paint-atelier-v1"}
for index,id in templates do
 local room,cloth,frame=fixture(64+index*128)
 local sizes=Geometry.layout(id);local secondary=#sizes==2
 local walls=Scene.configureWalls(room,secondary,id)
 assert(#walls==#sizes and cloth.Size.X==sizes[1].width+2,"Shape/protection mismatch: "..id)
 for i,wall in walls do
  assert(wall.Size.X==sizes[i].width and wall.Size.Y==sizes[i].height,"Wrong real wall size")
  for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
   local v=localPoint(frame,wall.CFrame*CFrame.new(x*wall.Size.X/2,y*wall.Size.Y/2,z*wall.Size.Z/2))
   assert(math.abs(v[1])<15.5 and math.abs(v[3])<11.6 and v[2]>=-.001 and v[2]<=9.501,"Variant outside room/door: "..id)
  end end end
 end
 local site=Worksite.attach(room);site.update("Painting","mint",true,secondary)
 local model=room:FindFirstChild("PaintWorksite");assert(#model:GetChildren()==(if secondary then 33 else 24))
 if secondary then assert(model:FindFirstChild("SideCloth").Size.Z==sizes[2].width+2)end
 local count=#pool
 for _=1,10 do
  local repeatWalls=Scene.configureWalls(room,secondary,id);site.update("Painting","mint",true,secondary)
  assert(repeatWalls[1]==walls[1]and repeatWalls[2]==walls[2]and room:FindFirstChild("PaintWorksite")==model,"Sync recreated walls/site")
 end
 assert(#pool==count,"Variant sync allocated Parts")
 for _,part in model:GetChildren()do
  assert(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch and not part.CastShadow,"Prepared variant affects physics")
  for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
   local v=localPoint(frame,part.CFrame*CFrame.new(x*part.Size.X/2,y*part.Size.Y/2,z*part.Size.Z/2))
   assert(math.abs(v[1])<15.5 and math.abs(v[3])<11.6 and v[2]>=-.001 and v[2]<9.8,"Variant preparation outside room: "..id.." / "..part.Name)
   if part.Name:find("Tray")or part.Name:find("Bucket")or part.Name:find("ClothFold")then
    assert(math.abs(v[1])<=cloth.Size.X/2+.001 and v[3]>=-11 and v[3]<=-6,"Props outside protection: "..id.." / "..part.Name)
   end
  end end end
 end
 site.update("Completed","mint",true,secondary);assert(model.dead and cloth.Transparency==1)
 local wall=walls[1];wall.Color="completed"
 Scene.configureWalls(room,false,"paint-mint-v1")
 assert(wall.Color=="completed"and not room:FindFirstChild("PaintableWallB"),"Geometry reset result colour/retained B")
 room:Destroy()
end
print("PASS PaintShapeScene: six actual rotated layouts/cloth/tape/bounds, same 24/33 Parts, cache, colour preservation, cleanup and single/duo switch")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(context['header']+context['s']+checks);f.flush()
 subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
