#!/usr/bin/env python3
"""Run the real shop renderer and purchase callback with a server catalogue."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/HomeController.luau").read_text()
start = source.index("\tlocal function buy(")
body = source[start:source.index("\n\tlocal function storeItem(", start)]
header = r'''
local Finishes = require("../src/shared/FurnitureFinishes")
local Strings = require("../src/shared/Strings")
local PurchaseFlow = require("../src/shared/PurchaseFlow")
local Config = require("../src/server/Domain/EconomyConfig")
local selectedPrice, now, language = 250, 0, "en"
local os = {clock = function() return now end}
local Http = {GenerateGUID = function() return "one-purchase" end}
local UDim2 = {
    new = function(xs,xo,ys,yo) return {XS=xs,XO=xo,YS=ys,YO=yo} end,
    fromOffset = function(x,y) return {XS=0,XO=x,YS=0,YO=y} end,
}
local Color3 = {fromRGB = function(...) return {...} end}
local function t(key) return Strings.text(language,key) end
local function node(parent,name)
    local self = {Name=name, children={}, Visible=true}
    self.Activated = {Connect = function(_, callback) self.click=callback end}
    function self:ClearAllChildren() self.children={} end
    if parent then parent.children[name]=self end
    return self
end
local shop, shopBody = node(nil,"Shop"), node(nil,"Body")
local function text(parent,name) return node(parent,name) end
local button = text
local function row(parent,name,offset,catalogId,height)
    local card = node(parent,name)
    card.offset, card.height = offset,height
    local function preview(id) card.preview=id end
    preview(catalogId)
    return card, preview
end
local state = {available=true, nearShop=true, dollars=selectedPrice, catalog={}}
for id, spec in Config.catalog do
    table.insert(state.catalog, {id=id,dollars=spec.dollars,width=spec.width,depth=spec.depth})
end
table.sort(state.catalog,function(a,b)
    return a.dollars<b.dollars or (a.dollars==b.dollars and a.id<b.id)
end)
local purchase, storing, lastError, errorUntil, listKey
local shopSelection, sent = {}, {}
local function send(action, packet)
    assert(action=="buy"); table.insert(sent,packet)
end
'''
checks = r'''
local productId = "floor-plant-v1"
local coralId = Finishes.options[productId].Coral
local function refresh() renderShop(state,refresh) end
local function plant()
    local card = shopBody.children[productId]
    return card, card.children
end
refresh()
local card, controls = plant()
local count=0
for _,c in shopBody.children do count+=1 end
assert(count==8 and shopBody.CanvasSize.YO==8*164+3*52,"Variants became duplicate cards or changed scroll layout")
assert(card.preview==productId and controls.Buy.Active and controls.Price.Text=="$180")
assert(controls.FinishOriginal.Text=="✓ Original" and controls.FinishLagoon.Text=="Lagoon")
for _,width in {280, 320, 600} do
    for _,name in {"FinishOriginal","FinishCoral","FinishLagoon"} do
        local c=controls[name]
        assert((width-48)*c.Size.XS+c.Size.XO>=44 and c.Size.YO>=44,"Finish target is too small")
        assert(c.Position.YO+c.Size.YO<=controls.Buy.Position.YO,"Finish overlaps purchase")
    end
end
shop.Visible=false;controls.FinishCoral.click();assert(card.preview==productId)
shop.Visible=true;controls.FinishCoral.click()
assert(card==plant() and card.preview==coralId and #sent==0,"Finish choice rebuilt the list or sent a purchase")
assert(controls.FinishCoral.Text=="✓ Coral" and controls.FinishOriginal.Text=="Original")
language="ru";refresh();card,controls=plant()
assert(card.preview==coralId and controls.FinishCoral.Text=="✓ Коралл","Locale reset the preview choice")
controls.Buy.click()
assert(#sent==1 and sent[1].catalogId==coralId and purchase.catalogId==coralId)
card,controls=plant()
controls.FinishLagoon.click();controls.Buy.click()
assert(card.preview==coralId and not controls.FinishLagoon.Active and #sent==1,"Pending purchase allowed a changed finish")
state.dollars=0;now=10;refresh();card,controls=plant()
assert(controls.Buy.Active and controls.Buy.Text==t("retryPurchase"))
controls.Buy.click()
assert(#sent==2 and sent[2].catalogId==coralId and sent[2].requestId==sent[1].requestId)
local wrong={{id="wrong",catalogId=productId,purchaseOperationId="purchase:"..sent[1].requestId}}
local unchanged, status = PurchaseFlow.observe(purchase,wrong,nil,nil)
assert(unchanged==purchase and status~="Confirmed","Other finish confirmed a pending purchase")
local right={{id="owned",catalogId=coralId,purchaseOperationId="purchase:"..sent[1].requestId}}
local nextPurchase, result, itemId = PurchaseFlow.observe(purchase,right,nil,nil)
assert(nextPurchase==nil and result=="Confirmed" and itemId=="owned","Matching finish did not confirm")
purchase=nextPurchase;state.nearShop=false;state.dollars=250;refresh();card,controls=plant()
controls.FinishLagoon.click();controls.Buy.click()
assert(card.preview==Finishes.options[productId].Lagoon and #sent==2,"Remote catalogue allowed a purchase")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + body + "\n" + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS ShopFinishesUI: eight cards, EN/RU, 44px targets, live preview, exact pending SKU and retry")

start = source.index("\tlocal function thumbnail(")
thumbnail = source[start:source.index("\n\tlocal function row(", start)]
preview_fixture = r'''
local objects={}
local Instance={new=function(class)
    local n={ClassName=class}
    table.insert(objects,n)
    return n
end}
local UDim2={fromOffset=function()return{}end}
local Color3={new=function()return{}end,fromRGB=function()return{}end}
local position={}
local frame
local vector=setmetatable({},{__mul=function()return position end})
setmetatable(position,{__add=function()return position end})
local Vector3={new=function()return{Unit=vector}end}
local CFrame={lookAt=function()frame={};return frame end}
local models={}
local Models={create=function(id)
    local model={Name=id}
    function model:GetBoundingBox()return {Position=position},{Magnitude=5} end
    function model:Destroy() self.destroyed=true end
    table.insert(models,model)
    return model
end}
'''
preview_checks = r'''
local parent={}
local select=thumbnail(parent)
local viewport,camera=objects[1],objects[2]
assert(viewport.Parent==parent and viewport.CurrentCamera==camera)
select("floor-plant-v1")
assert(models[1].Parent==viewport and camera.CFrame==frame and #objects==2)
select("floor-plant-coral-v1")
assert(models[1].destroyed and models[2].Parent==viewport and viewport.CurrentCamera==camera)
select("floor-plant-coral-v1")
assert(#models==2 and not models[2].destroyed and #objects==2,"Selecting the same finish rebuilt the preview")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(preview_fixture + thumbnail + "\n" + preview_checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS ShopFinishesUI: real thumbnail uses one camera and replaces only the selected model")
