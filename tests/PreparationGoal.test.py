#!/usr/bin/env python3
"""Exercise the actual preparation goal resolver against a bounded spatial fixture."""
from pathlib import Path
import ast
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
tree=ast.parse((ROOT/'tests/ClientDecorModels.test.py').read_text())
header=next(ast.literal_eval(n.value)for n in tree.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='header'for t in n.targets))
header+=r'''
local baseNew=Instance.new
Instance.new=function(kind)
 local n=baseNew(kind)
 function n:GetAttribute(k)return self.attributes[k]end
 function n:FindFirstChild(name)for _,p in self:GetChildren()do if p.Name==name then return p end end end
 function n:IsA(k)return k==self.ClassName or(k=="BasePart"and self.ClassName=="Part")end
 return n
end
local vm={};vm.__index=function(v,k)if k=="Magnitude"then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end end
vm.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
Vector3.new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
meta.__index={PointToWorldSpace=function(cf,v)local p=cf*CFrame.new(v);return Vector3.new(table.unpack(p.p))end}
local workspace=Instance.new("Model");local homes=Instance.new("Folder");homes.Name,homes.Parent="Homes",workspace
local room=Instance.new("Model");room.Name,room.Parent="Client_7",homes;room:SetAttribute("OwnerUserId",7)
local folder=Instance.new("Folder");folder.Name,folder.Parent="WallPreparation",room
local function patch(name,x,owner)
 local p=Instance.new("Part");p.Name,p.Parent=name,folder;p.Position=Vector3.new(x,5,0);p.CFrame=CFrame.new(x,5,0)*CFrame.Angles(0,math.pi/2,0);p:SetAttribute("OwnerUserId",owner or 7);return p
end
local a,b,c=patch("OldFinish1",0),patch("OldFinish2",4),patch("OldFinish3",8)
local foreign=patch("OldFinish4",.5,8)
local floor=Instance.new("Part");floor.Name,floor.Parent="Protection",room;floor.CFrame=CFrame.new(12,.5,7)
local root=Instance.new("Part");root.Parent={};root.Position=Vector3.new(1,3,4)
local cleanup;local screen={Destroying={Once=function(_,fn)cleanup=fn end}}
local s={available=true,phase="Prepare",jobId="job",workId="work",location="Client_7",preparationRequired=3,preparedCount=0}
local Goal={}
'''
s=(ROOT/'src/client/PreparationGoal.luau').read_text();s=s[s.index('local Goal = {}')+len('local Goal = {}'):s.rindex('\nreturn ')]
checks=r'''
local resolve=Goal.start(screen,7);local goal,target=resolve(s,root)
assert(goal and target==a and goal.labelKey=="oldFinish" and goal.actionKey=="scrapeBeaconHint","No nearest owned preparation target")
assert(goal.destination[1]==4 and goal.destination[2]==3.5 and math.abs(goal.destination[3])<.001,"Rotated stand point ignored patch CFrame")
local first=goal.key;root.Position=Vector3.new(8,3,0);goal,target=resolve(s,root);assert(target==a and goal.key==first,"Moving player changed unfinished target")
a:SetAttribute("Cleared",true);s.preparedCount=1;goal,target=resolve(s,root);assert(target==c and goal.key~=first,"Confirmed clear did not choose next patch")
root.Position=Vector3.new(table.unpack(goal.destination));goal=resolve(s,root);assert(goal.near,"Arrived stand point still routing")
c:SetAttribute("OwnerUserId",8);goal,target=resolve(s,root);assert(target==b,"Foreign attribute kept selected patch")
b:SetAttribute("Cleared",true);assert(resolve(s,root)==nil,"Missing confirmed targets invented floor completion")
s.preparedCount=3;goal,target=resolve(s,root);assert(target==floor and goal.labelKey=="protectFloor"and not goal.actionKey,"Completed patches did not point to protection")
assert(goal.destination[1]==12 and goal.destination[2]==3.5 and goal.destination[3]==7,"Floor point is not walkable")
s.preparedCount,s.preparationRequired=0,0;goal,target=resolve(s,root);assert(target==floor,"Starter preparation changed")
s.phase="Painting";assert(resolve(s,root)==nil,"Painting retained preparation target");s.phase="Prepare"
s.available=false;assert(resolve(s,root)==nil);s.available=true
room:SetAttribute("OwnerUserId",8);assert(resolve(s,root)==nil,"Foreign room navigable");room:SetAttribute("OwnerUserId",7)
s.preparationRequired=3;s.preparedCount=0;a:SetAttribute("Cleared",false);c:SetAttribute("OwnerUserId",7)
root.Position=Vector3.new(0,3,0);goal,target=resolve(s,root);assert(target==a)
s.workId="new";root.Position=Vector3.new(8,3,0);goal,target=resolve(s,root);assert(target==c,"New work inherited target")
c:Destroy();goal,target=resolve(s,root);assert(target==a,"Removed patch kept route")
assert(resolve(s,nil)==nil,"Missing avatar kept target");assert(resolve(nil,root)==nil,"Travel reset retained target")
cleanup();assert(resolve(s,root)==nil,"Destroyed HUD revived goal")
assert(s.preparedCount==0 and not a:GetAttribute("Cleared")and not b.dead,"Projection changed preparation/world")
print("PASS PreparationGoal: actual nearest/latched selection, rotated geometry, confirmed next/floor, owners, phases/work/avatar, no writes and cleanup")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(header+s+checks);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
