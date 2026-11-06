#!/usr/bin/env python3
"""Execute the full planner renderer and optional collection callbacks against current facts."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
s = (ROOT / 'src/client/HomePlannerController.luau').read_text()
body = s[s.index('local Planner ='):s.rindex('return Planner')]
header = r'''
local Plan=require("../src/shared/HomePlan")
local Budget=require("../src/shared/HomeBudget")
local Strings=require("../src/shared/Strings")
local Theme=require("../src/shared/Theme")
local Config=require("../src/server/Domain/EconomyConfig")
local pool={}
local Instance={new=function(kind)
 local n={ClassName=kind};table.insert(pool,n)
 n.Activated={Connect=function(_,fn)n.activate=fn end}
 function n:IsA(k)return self.ClassName==k end
 function n:GetChildren()local r={};for _,o in pool do if not o.dead and o.Parent==self then table.insert(r,o)end end;return r end
 function n:FindFirstChild(name)for _,o in self:GetChildren()do if o.Name==name then return o end end end
 function n:Destroy()for _,o in self:GetChildren()do o:Destroy()end;self.dead=true end
 function n:ClearAllChildren()for _,o in self:GetChildren()do o:Destroy()end end
 return n
end}
local UDim2={new=function(xs,xo,ys,yo)return{X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end}
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
local Vector2={new=function(x,y)return{X=x,Y=y}end}
local Color3={fromRGB=function(...)return{...}end}
local Enum={Font={GothamMedium=1}}
local function child(p,name)local n=p:FindFirstChild(name);assert(n,"Missing "..name);return n end
'''
checks = r'''
local screen=Instance.new("ScreenGui");local lang="en";local navigated,earned={},0
local api=Planner.start(screen,function()return lang end,function(id,item)table.insert(navigated,{id=id,item=item})end,function()earned+=1 end)
local panel=child(screen,"RoomPlanPanel");local body=child(panel,"Body")
local items={};local catalog={}
for id,spec in Config.catalog do table.insert(catalog,{id=id,dollars=spec.dollars})end
local state={available=true,items=items,catalog=catalog,dollars=0,plan=Plan.evaluate(items)}
api.render(state,false);api.show();assert(not body:FindFirstChild("creativeCorner"),"Empty room showed optional collection")
for i,id in {"floor-plant-v1","reading-chair-v1","side-table-v1","floor-lamp-v1","bookcase-v1"}do table.insert(items,{id="base"..i,catalogId=id,purchaseOperationId="buy-base"..i,placed={x=i,z=6,rotationY=0}})end
state.plan=Plan.evaluate(items);api.render(state,false)
local card=child(body,"creativeCorner");assert(child(card,"Earn").activate,"Missing optional Earn")
assert(child(panel,"Summary").Text:find("5",1,true)and child(panel,"Jobs").Visible,"Optional items changed base completion/footer")
local count=#pool;api.render(state,false);assert(#pool==count and child(body,"creativeCorner")==card,"Sync rebuilt stable collection")
local oldEarn=child(card,"Earn").activate;oldEarn();assert(earned==1)
state.dollars=240;oldEarn();assert(earned==1,"Stale Earn ignored latest affordability")
state.dollars=0
local sofa={id="sofa",catalogId="cozy-sofa-v1",purchaseOperationId="buy-sofa"};table.insert(items,sofa)
api.render(state,false);card=child(body,"creativeCorner")
assert(not card:FindFirstChild("Earn"),"Stored sofa suggested earning instead of placing")
local selectSofa=child(card,"cozy-sofa-v1").activate;selectSofa()
assert(#navigated==1 and navigated[1].item=="sofa","Collection did not focus owned sofa")
api.render(state,true);selectSofa();assert(#navigated==1 and not child(child(body,"creativeCorner"),"cozy-sofa-v1").Active,"Pending operation allowed optional navigation")
api.render(state,false);api.hide();selectSofa();oldEarn();assert(#navigated==1 and earned==1,"Hidden stale callbacks navigated")
api.show();sofa.placed={x=-7,z=9,rotationY=0}
for i,id in {"floor-easel-v1","floor-planter-v1"}do table.insert(items,{id="decor"..i,catalogId=id,purchaseOperationId="buy-decor"..i,placed={x=10,z=i,rotationY=0}})end
for _,locale in {"en","ru"}do lang=locale;api.render(state,false);card=child(body,"creativeCorner");assert(child(card,"Heading").Text:find(Strings.text(lang,"roomGoalComplete"),1,true),"Optional completion not translated")end
items[1].placed=nil;state.plan=Plan.evaluate(items);api.render(state,false)
assert(not body:FindFirstChild("creativeCorner")and not child(panel,"Jobs").Visible,"Stored base requirement kept optional/completion visible")
items[1].placed={x=5,z=3,rotationY=0};state.plan=Plan.evaluate(items);api.render(state,false)
assert(child(child(body,"creativeCorner"),"Heading").Text:find(Strings.text(lang,"roomGoalComplete"),1,true),"Restored base room lost confirmed optional progress")
state.available=false;api.render(state,false);selectSofa();assert(#navigated==1 and #body:GetChildren()==0,"Unavailable state retained actionable collection")
print("PASS CreativePlannerUI: real full render, base5/optional3, cache, budget/owned focus, pending/hidden/unavailable, store/restore and EN/RU")
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT / '.tools') as script:
    script.write(header + body + checks)
    script.flush()
    subprocess.run([str(ROOT / '.tools/bin/luau'), script.name], cwd=ROOT, check=True)
