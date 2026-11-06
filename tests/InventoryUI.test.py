#!/usr/bin/env python3
"""Execute actual inventory construction, render, filters and purchase navigation."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/HomeController.luau").read_text()
a = source.index("\tinventoryTitle.Visible = false")
construction = source[a:source.index("\n\tlocal returnButton", a)]
a = source.index("\tlocal function render(): ()")
helper = source[source.index('\tlocal function homeObjective('):source.index('\tlocal function thumbnail(')]
render = source[a:source.index("\n\tfor _, entry in sections do", a)]
a = source.index("\tfor _, entry in sections do", a + len(render))
callbacks = source[a:source.index("\n\tplanner = RoomPlanner.start", a)]
a = source.index("\tfor _, back in { shopBack, inventoryBack } do", source.index("\tplanner = RoomPlanner.start"))
back = source[a:source.index("\n\treturnButton.Activated", a)]
header = r'''
local Objective=require("../src/shared/HomeObjective")
local screen={SetAttribute=function()end}
local Inventory=require("../src/shared/FurnitureInventory")
local Strings=require("../src/shared/Strings")
local StoreFlow=require("../src/shared/StoreFlow")
local PurchaseFlow=require("../src/shared/PurchaseFlow")
local now=0;local os={clock=function()return now end}
local Vector2={zero={X=0,Y=0},new=function(x,y)return{X=x,Y=y}end}
local UDim2={fromOffset=function(x,y)return{X={Offset=x},Y={Offset=y}}end,new=function(xs,xo,ys,yo)return{X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end}
local function node(name)
 local n={Name=name,Visible=true,children={},CanvasPosition=Vector2.zero}
 function n:ClearAllChildren()self.children={}end
 function n:FindFirstChild(id)return self.children[id]end
 function n:GetDescendants()return{}end
 function n:IsA(kind)return kind=="Frame"or kind=="GuiObject"end
 return n
end
local Instance={new=function()return node("new")end}
local function text(parent,name)
 local n=node(name);parent.children[name]=n;return n
end
local function button(parent,name)
 local b=text(parent,name);b.Activated={Connect=function(_,fn)b.fire=fn end};return b
end
local rows=0
local function row(parent,name,index,_,height)
 rows+=1;local n=text(parent,name);n.Position=UDim2.fromOffset(4,(index-1)*(height+8));return n
end
local shop,inventory=node("shop"),node("inventory")
local shopTitle,shopInfo,shopBody,shopBack=node("title"),node("info"),node("body"),button(shop,"back")
local inventoryTitle,inventoryInfo,inventoryBody,inventoryBack=node("title"),node("info"),node("body"),button(inventory,"back")
local returnButton,routeButton,homePanel=node("return"),node("route"),node("home")
local lang,status="en","Ready"
local player={GetAttribute=function()return status end}
local builder={render=function()end,isActive=function()return false end}
local planner={render=function()end}
local purchase,storing,purchasedItem,focus=nil,nil,nil,nil
local routeActive=false
local lastError,errorUntil=nil,0
local listKey=""
local inventoryFilter="All"
local state={available=true,nearHome=true,nearShop=false,dollars=70,revision=1,
 catalog={},items={
 {id="plant1",catalogId="floor-plant-v1",purchaseOperationId="buy1"},
 {id="plant2",catalogId="floor-plant-v1",purchaseOperationId="buy2",placed={x=8,z=6,rotationY=345}},
 {id="lamp",catalogId="floor-lamp-v1",purchaseOperationId="buy3"}}}
local function language()return lang end
local function t(key)return Strings.text(lang,key)end
local function planBlocked()return purchase~=nil or storing~=nil or builder.isActive()or status~="Ready"end
local function buy()error("Filter bought furniture")end
local function storeItem()error("Filter stored furniture")end
local function hidePanels()inventory.Visible=false;shop.Visible=false end
local function show(tab)inventory.Visible=tab=="Furniture";shop.Visible=tab=="Shop";listKey=""end
'''
checks = r'''
assert(not inventoryTitle.Visible and inventoryInfo.Position.Y.Offset==52 and inventoryInfo.Size.Y.Offset==54)
for _,b in filterButtons do
 for _,width in {320,374,666,1161}do
  local pixels=(math.min(600,width-24)-16)*b.Size.X.Scale+b.Size.X.Offset
  assert(pixels>=44 and filters.Size.Y.Offset==44,"Small inventory filter")
 end
end
render()
assert(filterButtons.All.Text=="✓ 3 · All"and filterButtons.Stored.Text=="2 · Stored"and filterButtons.Placed.Text=="1 · In room")
assert(inventoryBody.children.plant1 and inventoryBody.children.plant2 and inventoryBody.children.lamp)
inventoryBody.CanvasPosition=Vector2.new(0,100)
local before=rows;render();assert(rows==before and inventoryBody.CanvasPosition.Y==100,"Ordinary sync rebuilt/reset the list")
filterButtons.Stored.fire()
assert(inventoryFilter=="Stored"and inventoryBody.CanvasPosition.Y==0)
assert(inventoryBody.children.plant1 and inventoryBody.children.lamp and not inventoryBody.children.plant2)
assert(inventoryBody.CanvasSize.Y.Offset==216,"Canvas counted filtered-out items")
filterButtons.Placed.fire()
assert(inventoryBody.children.plant2 and not inventoryBody.children.plant1)
state.items[2].placed=nil;state.revision+=1;render()
assert(inventoryBody.children.Empty.Text==t("emptyInventoryPlaced")and inventoryBody.CanvasSize.Y.Offset==90)
lang="ru";render();assert(filterButtons.All.Text=="3 · Всё"and filterButtons.Placed.Text=="✓ 0 · В комнате")
focus={tab="Furniture",id="lamp"};render()
assert(inventoryFilter=="All"and focus==nil and inventoryBody.CanvasPosition.Y==216,"Plan target remained hidden by a section")
filterButtons.Stored.fire();inventoryBody.CanvasPosition=Vector2.new(0,50)
for _,blocked in {"purchase","store","build","profile","unavailable","hidden"}do
 purchase=if blocked=="purchase"then {}else nil
 storing=if blocked=="store"then {requestId="store1",itemId="plant1",retryAt=8}else nil
 builder.isActive=function()return blocked=="build"end
 status=if blocked=="profile"then "Error"else "Ready"
 state.available=blocked~="unavailable";inventory.Visible=blocked~="hidden"
 filterButtons.Placed.fire();assert(inventoryFilter=="Stored","Blocked callback changed section: "..blocked)
end
purchase=nil;storing={requestId="store1",itemId="plant1",retryAt=8};builder.isActive=function()return false end
status="Ready";state.available=true;inventory.Visible=true
render();assert(inventoryFilter=="All"and not filterButtons.Stored.Active,"Pending store was hidden")
local intent=storing;now=8;render();filterButtons.Placed.fire()
assert(storing==intent and storing.requestId=="store1"and inventoryFilter=="All","Filter replaced retry intent")
storing=nil;state.available=false;state.items={};render()
assert(filterButtons.All.Text=="✓ — · Всё"and not filterButtons.All.Active and inventoryBody.children.Empty.Text==t("offerWaiting"),"Unavailable shown as confirmed empty inventory")
state.available=true;state.items={{id="newplant",catalogId="floor-plant-v1",purchaseOperationId="newbuy"}}
inventoryFilter="Placed";purchasedItem="newplant";shopBack.fire()
assert(inventory.Visible and inventoryFilter=="All"and inventoryBody.children.newplant and purchasedItem==nil,"Purchase opened a filter hiding new furniture")
assert(state.dollars==70 and state.revision==2,"Filters mutated money or housing")
print("PASS InventoryUI: actual tabs/render/callbacks, counts, empty/unknown, focus, scroll and pending intent")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + helper + construction + render + callbacks + back + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
