#!/usr/bin/env python3
"""Run the actual server lamp adapter with deterministic engine boundaries."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/server/HomeLights.luau").read_text()
body = source[source.index("local Lights = {}"):].removesuffix("\n").removesuffix("return Lights")
header = '''
local Use=require("../src/server/Domain/HomeUse")
local RoomRules=require("../src/server/Domain/RoomRules")
local now=10
local os={clock=function()return now end}
local function vec(x,y,z)
    return setmetatable({X=x,Y=y,Z=z},{__sub=function(a,b)
        local x,y,z=a.X-b.X,a.Y-b.Y,a.Z-b.Z
        return {X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)}
    end})
end
local Players={}
local owner={UserId=1,Parent=Players}
local root={Position=vec(5,3.5,7),IsA=function()return true end}
local hum={Health=100}
local character={FindFirstChild=function()return root end,FindFirstChildOfClass=function()return hum end,IsDescendantOf=function()return true end}
owner.Character=character
local light={Enabled=false,IsA=function()return true end}
local switch={Position=vec(5,3.2,3),IsA=function()return true end}
local prompt,created=nil,0
function switch:FindFirstChild()return prompt end
local attrs={CatalogId="floor-lamp-v1",OwnerUserId=1}
local folder={}
local model={Name="lamp",Parent=folder,GetAttribute=function(_,n)return attrs[n]end,SetAttribute=function(_,n,v)attrs[n]=v end}
function model:FindFirstChild(n)return if n=="Switch"then switch elseif n=="LampLight"then light else nil end
local current=model
function folder:FindFirstChild()return current end
local homeOwner=1
local home={origin=vec(0,0,0),model={FindFirstChild=function()return folder end,GetAttribute=function()return homeOwner end}}
local p={wallet={dollars=70},inventory={lamp={catalogItemId="floor-lamp-v1"}},housing={placements={lamp={x=5,z=3}}}}
local data=p
local reads=0
local profiles={read=function()reads+=1;return data end,home=function()return home end,change=function()error("Lamp attempted a profile write")end}
local blocked=false
local rays=0
local workspace={Raycast=function(_,origin,direction)
    rays+=1;assert(direction.Magnitude==direction.Magnitude and direction.Magnitude<math.huge,"Invalid ray reached engine")
    return if blocked then {Instance={IsDescendantOf=function()return false end}} else nil
end}
local RaycastParams={new=function()return {}end}
local Enum={RaycastFilterType={Exclude=1},Material={Neon=1,SmoothPlastic=2},KeyCode={E=1},ProximityPromptExclusivity={OnePerButton=1}}
local Color3={fromRGB=function(r,g,b)return {r,g,b}end}
local Instance={new=function()
    created+=1
    local callback
    local object={Triggered={Connect=function(_,fn)callback=fn end},fire=function(actor)callback(actor)end}
    return setmetatable(object,{__newindex=function(t,k,v)rawset(t,k,v);if k=="Parent"then prompt=t end end})
end}
'''
checks = '''
Lights.attach(model,owner,profiles)
assert(created==1 and light.Enabled and attrs.LightOn and prompt.Parent==switch,"Placed lamp not attached")
Lights.attach(model,owner,profiles);assert(created==1,"Reconcile duplicated prompt/reset state")
prompt.fire(owner);assert(not light.Enabled and attrs.LightOn==false,"Valid use did not turn off")
prompt.fire(owner);now=10.49;prompt.fire(owner);assert(not light.Enabled,"Cooldown bypassed")
now=10.5;prompt.fire(owner);assert(light.Enabled,"Exact cooldown boundary refused")
local beforeReads=reads
prompt.fire({UserId=2,Parent=Players,Character=character})
assert(reads==beforeReads and light.Enabled,"Foreign player reached owner state")
local function denied(change,restore)
    now+=1;change();prompt.fire(owner);assert(light.Enabled,"Invalid use changed light");restore()
end
denied(function()data=nil end,function()data=p end)
denied(function()hum.Health=0 end,function()hum.Health=100 end)
denied(function()owner.Character=nil end,function()owner.Character=character end)
denied(function()owner.Parent=nil end,function()owner.Parent=Players end)
denied(function()root.Position=vec(30,3.5,3)end,function()root.Position=vec(5,3.5,7)end)
local beforeRays=rays
denied(function()root.Position=vec(0/0,3,3)end,function()root.Position=vec(5,3.5,7)end)
assert(rays==beforeRays,"Nonfinite distance reached engine")
denied(function()blocked=true end,function()blocked=false end)
denied(function()attrs.OwnerUserId=2 end,function()attrs.OwnerUserId=1 end)
denied(function()homeOwner=2 end,function()homeOwner=1 end)
denied(function()model.Parent=nil end,function()model.Parent=folder end)
denied(function()current={}end,function()current=model end)
local item=p.inventory.lamp
denied(function()p.inventory.lamp=nil end,function()p.inventory.lamp=item end)
denied(function()item.catalogItemId="floor-plant-v1"end,function()item.catalogItemId="floor-lamp-v1"end)
local placed=p.housing.placements.lamp
denied(function()p.housing.placements.lamp=nil end,function()p.housing.placements.lamp=placed end)
denied(function()switch.Position=vec(15,3.2,3);root.Position=vec(16.1,3.5,3)end,function()switch.Position=vec(5,3.2,3);root.Position=vec(5,3.5,7)end)
now+=1;prompt.fire(owner);assert(not light.Enabled and p.wallet.dollars==70,"Final valid use failed or changed money")
Lights.attach(model,owner,profiles);assert(not light.Enabled and created==1,"Profile sync reset switched-off lamp")
local first=prompt
local light2={Enabled=false,IsA=function()return true end}
local switch2={Position=vec(69,3.2,3),IsA=function()return true end,FindFirstChild=function()return nil end}
local root2={Position=vec(69,3.5,7),IsA=function()return true end}
local char2={FindFirstChild=function()return root2 end,FindFirstChildOfClass=function()return {Health=100}end,IsDescendantOf=function()return true end}
local owner2={UserId=2,Parent=Players,Character=char2}
local folder2={}
local attrs2={CatalogId="floor-lamp-v1",OwnerUserId=2}
local model2={Name="lamp2",Parent=folder2,GetAttribute=function(_,n)return attrs2[n]end,SetAttribute=function(_,n,v)attrs2[n]=v end}
function model2:FindFirstChild(n)return if n=="Switch"then switch2 elseif n=="LampLight"then light2 else nil end
function folder2:FindFirstChild()return model2 end
local p2={inventory={lamp2={catalogItemId="floor-lamp-v1"}},housing={placements={lamp2={x=5,z=3}}}}
local home2={origin=vec(64,0,0),model={FindFirstChild=function()return folder2 end,GetAttribute=function()return 2 end}}
Lights.attach(model2,owner2,{read=function()return p2 end,home=function()return home2 end})
local second=prompt
second.fire(owner2)
assert(not light2.Enabled and not light.Enabled,"Players shared state or cooldown")
now+=.5;first.fire(owner)
assert(light.Enabled and not light2.Enabled,"First owner's action toggled another home")
second.fire(owner);assert(not light2.Enabled,"Cross-owner prompt accepted")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + body + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS HomeLights: actual adapter, cooldown, ownership, live profile/character, LOS, stale model and no profile writes")
