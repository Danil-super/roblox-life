#!/usr/bin/env python3
"""Execute actual preparation prompt ownership, localization, modal state and cleanup."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
s=(ROOT/'src/client/PreparationPrompts.luau').read_text();s=s[s.index('function Controller.start'):s.rindex('\nreturn Controller')]
header=r'''
local Strings=require("../src/shared/Strings");local Controller={};local connections={}
local function signal()
 local r={list={}};function r:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(connections,c);table.insert(self.list,{fn=fn,c=c});return c end
 function r:Once(fn)local c;c=self:Connect(function(...)c:Disconnect();fn(...)end);return c end
 function r:Fire(...)for _,e in self.list do if e.c.Connected then e.fn(...)end end end;return r
end
local status="Ready";local profile=signal();local player={UserId=7,GetAttribute=function()return status end,GetAttributeChangedSignal=function()return profile end}
local Players={LocalPlayer=player};local attrs={};local modal,enabled,destroy=signal(),signal(),signal()
local screen={Enabled=true,GetAttribute=function(_,k)return attrs[k]end,GetAttributeChangedSignal=function()return modal end,GetPropertyChangedSignal=function()return enabled end,Destroying=destroy}
local function prompt(owner)
 local data={OwnerUserId=owner};local part={AttributeChanged=signal(),GetAttribute=function(_,k)return data[k]end,IsA=function()return true end}
 return{Parent=part,Name="ScrapeOldFinish",IsA=function(_,k)return k=="ProximityPrompt"end},data
end
local own,data=prompt(7);local foreign=prompt(8)
local added,removed=signal(),signal();local homes={DescendantAdded=added,DescendantRemoving=removed,GetDescendants=function()return{own,foreign}end}
local workspace={WaitForChild=function()return homes end};local lang="en"
'''
checks=r'''
local api=Controller.start(screen,function()return lang end)
assert(own.Enabled and not foreign.Enabled and own.ActionText==Strings.text("en","scrapeAction"),"Prompt ownership/locale incorrect")
attrs.ModalOpen=true;modal:Fire();assert(not own.Enabled,"Prompt covers phone")
attrs.ModalOpen=false;modal:Fire();assert(own.Enabled)
data.Cleared=true;own.Parent.AttributeChanged:Fire("Cleared");assert(not own.Enabled,"Cleared patch still interactive")
modal:Fire();assert(not own.Enabled,"Menu reenabled a cleared patch")
data.Cleared=false;data.OwnerUserId=nil;own.Parent.AttributeChanged:Fire("OwnerUserId");assert(not own.Enabled)
data.OwnerUserId=7;own.Parent.AttributeChanged:Fire("OwnerUserId");assert(own.Enabled,"Late owner replication never enabled prompt")
lang="ru";api.render();assert(own.ActionText==Strings.text("ru","scrapeAction")and own.ObjectText==Strings.text("ru","oldFinish"))
screen.Enabled=false;enabled:Fire();assert(not own.Enabled);screen.Enabled=true;enabled:Fire();assert(own.Enabled)
status="Error";profile:Fire();assert(not own.Enabled);status="Ready";profile:Fire();assert(own.Enabled)
removed:Fire(own);own.Enabled=false;data.Cleared=false;modal:Fire();assert(not own.Enabled,"Removed prompt retained subscription")
added:Fire(own);assert(own.Enabled);local count=#connections;added:Fire(own);assert(#connections==count,"Duplicate event subscribed twice")
destroy:Fire();for _,c in connections do assert(not c.Connected,"Destroyed HUD retained prompt subscription")end
own.Enabled=false;api.render();modal:Fire();assert(not own.Enabled,"Late render revived prompt")
print("PASS PreparationPrompts: actual owner/late replication, EN-RU, menus/profile, confirmed clear, removal/dedup and cleanup")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(header+s+checks);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
