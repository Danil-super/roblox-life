#!/usr/bin/env python3
"""Execute real world-sign discovery, localization, ownership and cleanup."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/WorldSignsController.luau").read_text()
body = source[source.index("local Controller = {}"):].removesuffix("\n").removesuffix("return Controller")
header = '''
local Labels=require("../src/shared/StreetLabels")
local Strings=require("../src/shared/Strings")
local Players={LocalPlayer={UserId=1}}
local function signal()
 local callbacks={}
 local s={}
 function s:Connect(fn)
  local c={active=true}
  function c:Disconnect()self.active=false end
  table.insert(callbacks,{fn=fn,c=c})
  return c
 end
 function s:Once(fn)
  local c
  c=self:Connect(function(...)c:Disconnect();fn(...)end)
  return c
 end
 function s:Fire(...)for _,v in table.clone(callbacks)do if v.c.active then v.fn(...)end end end
 return s
end
local function label(key,owner,name)
 local attrs={SignKey=key,SignOwnerId=owner}
 local signals={SignKey=signal(),SignOwnerId=signal()}
 local l={Name=name or "WorldLabel",Text="untouched",Destroying=signal()}
 function l:IsA(c)return c=="TextLabel"end
 function l:GetAttribute(k)return attrs[k]end
 function l:GetAttributeChangedSignal(k)return signals[k]end
 function l:set(k,v)attrs[k]=v;signals[k]:Fire()end
 return l
end
local own=label("streetHomeDoor",1)
local foreign=label("streetHomeDoor",2)
local ignored=label("streetShop",nil,"OtherLabel")
local workspace={DescendantAdded=signal(),GetDescendants=function()return {own,foreign,ignored}end}
local screen={Destroying=signal()}
local lang="en"
'''
checks = '''
local api=Controller.start(screen,function()return lang end)
assert(own.Text=="My home" and foreign.Text=="Private home" and ignored.Text=="untouched")
lang="ru";api.render();assert(own.Text=="Мой дом" and foreign.Text=="Частная комната")
local late=label("streetClientDoor",1);workspace.DescendantAdded:Fire(late)
assert(late.Text=="Мой заказчик","Late workplace missed localization")
local pending=label("streetHomeDoor",nil);workspace.DescendantAdded:Fire(pending)
assert(pending.Text=="Частная комната","Unconfirmed ownership called mine")
pending:set("SignOwnerId",1);assert(pending.Text=="Мой дом","Replicated owner not refreshed")
pending:set("SignKey","streetShop");assert(pending.Text=="Мебель","Replicated key not refreshed")
late.Destroying:Fire();lang="en";api.render();assert(late.Text=="Мой заказчик","Destroyed sign still tracked")
assert(own.Text=="My home" and pending.Text=="Furniture")
screen.Destroying:Fire()
local after=label("streetShop",nil);workspace.DescendantAdded:Fire(after)
lang="ru";api.render();own:set("SignOwnerId",2)
assert(after.Text=="untouched" and own.Text=="My home","Destroyed HUD retained listeners")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + body + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS WorldSignsUI: existing/late signs, EN/RU, replicated ownership/key and cleanup")
