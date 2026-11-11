#!/usr/bin/env python3
"""Exercise the actual scraper renderer, transforms, finite tweens and cleanup."""
from pathlib import Path
import ast
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
tree=ast.parse((ROOT/'tests/ClientDecorModels.test.py').read_text())
header=next(ast.literal_eval(n.value)for n in tree.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='header'for t in n.targets))
header+=r'''
Enum.Material.Metal=2;Enum.EasingStyle={Sine=1};Enum.EasingDirection={InOut=1}
local TweenInfo={new=function(time,style,direction,count,reverses)return{Time=time,RepeatCount=count,Reverses=reverses}end}
local tweens={};local Tweens={Create=function(_,part,info,goal)
 local t={part=part,info=info,goal=goal};function t:Play()self.played=true end;function t:Cancel()self.cancelled=true end;table.insert(tweens,t);return t
end}
local function same(a,b)
 for i=1,3 do if math.abs(a.p[i]-b.p[i])>.00001 then return false end
 for j=1,3 do if math.abs(a.r[i][j]-b.r[i][j])>.00001 then return false end end end;return true
end
'''
s=(ROOT/'src/client/PreparationTool.luau').read_text();s=s[s.index('local Tool = {}'):s.rindex('\nreturn ')]
checks=r'''
local camera=Instance.new("Camera");local patch=Instance.new("Part");patch.Size=Vector3.new(1.76,4.05,.06);patch.CFrame=CFrame.new(64,5,19)*CFrame.Angles(0,math.pi/2,0)
local before=#pool;local api=Tool.new(camera,patch,true)
local model=camera:GetChildren()[1];assert(model and model.Name=="LocalScraper" and #model:GetChildren()==5 and #pool-before==6,"Scraper exceeded five Parts/one Model")
assert(#tweens==5,"Unexpected tween budget")
for _,t in tweens do
 assert(t.played and t.info.RepeatCount==2 and t.info.Reverses and t.info.Time>0 and t.info.Time<.2,"Animation unbounded or inactive")
 assert(t.part.Anchored and not t.part.CanCollide and not t.part.CanTouch and not t.part.CanQuery and not t.part.CastShadow,"Tool affects physics/aim")
 assert(not same(t.part.CFrame,t.goal.CFrame),"Scraper never moves")
 assert(t.part.Transparency==nil or t.part.Transparency==0,"Tool invisible")
end
assert(same(model:GetChildren()[1].CFrame,patch.CFrame*CFrame.new(0,1.25,.16)),"Blade ignored rotated patch")
local n=#pool;api.freeze();api.freeze();assert(#pool==n,"Quiet mode allocated objects")
for _,t in tweens do assert(t.cancelled,"Quiet mode retained motion")end
local quiet=Tool.new(camera,patch,false);assert(#tweens==5,"Reduced motion still created tween")
api.destroy();api.freeze();api.destroy();assert(model.dead and #camera:GetChildren()==1 and #pool==n+6,"Destroy leaked/revived/crossed tool ownership")
quiet.destroy();assert(#camera:GetChildren()==0,"Static tool survived cleanup")
print("PASS PreparationTool: actual five-Part renderer/rotated patch, finite tween budget, quiet/freeze, isolation and cleanup")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(header+s+checks);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
