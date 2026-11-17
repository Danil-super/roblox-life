#!/usr/bin/env python3
"""Execute the real catalogue factory, including shared art props and native sofa seat."""
from pathlib import Path
import ast
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
# Share the existing transform/instance mock, without executing its tests.
tree = ast.parse((ROOT / 'tests/ClientDecorModels.test.py').read_text())
header = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
              and any(isinstance(t, ast.Name) and t.id == 'header' for t in n.targets))
header += '\nVector3.zero=Vector3.new(0,0,0);Enum.Material.Fabric=2\n'
header += 'local Finishes=require("../src/shared/FurnitureFinishes")\n'
decor = (ROOT / 'src/assets/ClientDecorModels.luau').read_text().rsplit('return Models', 1)[0]
factory = (ROOT / 'src/assets/FurnitureModels.luau').read_text()
factory = factory[factory.index('local Models ='):factory.rindex('return Models')]
checks = r'''
local Config=require("../src/server/Domain/EconomyConfig")
local count=#pool;assert(Models.create("unknown")==nil and #pool==count)
for id,total in {["cozy-sofa-v1"]=14,["floor-easel-v1"]=11,["floor-planter-v1"]=6}do
 local m=Models.create(id);local spec=Config.catalog[id]
 assert(m and m.Name==id and m.PrimaryPart.Name=="Pivot"and #m:GetChildren()==total,"New catalogue factory/budget missing")
 local seats=0
 for _,p in m:GetChildren()do
  assert(p.Anchored,"New furniture is not static")
  if p.ClassName=="Seat"then seats+=1;assert(p.Disabled and p.Transparency==1,"Factory seat can sit in showroom/ghost")end
  if p~=m.PrimaryPart then for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
   local v=p.CFrame*CFrame.new(x*p.Size.X/2,y*p.Size.Y/2,z*p.Size.Z/2)
   assert(math.abs(v.p[1])<=spec.width/2+.001 and math.abs(v.p[3])<=spec.depth/2+.001 and v.p[2]>=-.001 and v.p[2]<=spec.height+.001,"Model extends outside authoritative placement bounds: "..id.." / "..p.Name)
  end end end end
 end
 assert(seats==(if id=="cozy-sofa-v1"then 1 else 0),"Wrong native seat count")
 local other=Models.create(id);m:Destroy();assert(not other.dead and not other.PrimaryPart.dead,"Factory shares mutable furniture")
 other:Destroy()
end
print("PASS CreativeModels: real factory, shared props, conservative geometry, 14/11/6 Parts, disabled seat and isolation")
for id, variant in Finishes.variants do
    local base, styled = Models.create(variant.baseId), Models.create(id)
    local originals, parts = base:GetChildren(), styled:GetChildren()
    local changed = {}
    local colors = Finishes.colors[variant.accent]
    assert(styled.Name==id and #originals==#parts and base.PrimaryPart~=styled.PrimaryPart)
    for index,part in parts do
        local original=originals[index]
        assert(part.Name==original.Name and part.Size.X==original.Size.X and part.Size.Y==original.Size.Y and part.Size.Z==original.Size.Z)
        assert(table.concat(part.CFrame.p,",")==table.concat(original.CFrame.p,","))
        assert(part.ClassName==original.ClassName and part.Disabled==original.Disabled and part.CanCollide==original.CanCollide)
        if part.Color and table.concat(part.Color,",")~=table.concat(original.Color,",") then
            assert(table.concat(part.Color,",")==table.concat(colors,","))
            changed[part.Name]=true
        end
    end
    assert(next(changed) and (if variant.baseId=="floor-plant-v1" then changed.Pot else changed.Back and changed.Arm))
end
print("PASS CreativeModels: actual Coral/Lagoon colors, identical footprints and seats")
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT / '.tools') as script:
    script.write(header + decor + '\nlocal Decor=Models\n' + factory + checks)
    script.flush()
    subprocess.run([str(ROOT / '.tools/bin/luau'), script.name], cwd=ROOT, check=True)
