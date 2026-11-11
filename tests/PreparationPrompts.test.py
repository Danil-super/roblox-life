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
player.CharacterRemoving=signal()
local death=signal();local hum={Health=100,Died=death};local char={IsDescendantOf=function()return true end,FindFirstChildOfClass=function()return hum end};player.Character=char
local hold,release,hidden,trigger=signal(),signal(),signal(),signal()
local Prompts={PromptButtonHoldBegan=hold,PromptButtonHoldEnded=release,PromptHidden=hidden,PromptTriggered=trigger}
local Input={WindowFocusReleased=signal()};local settings=signal();local Gui={ReducedMotionEnabled=false,GetPropertyChangedSignal=function()return settings end}
local tools={};local Tool={new=function(parent,part,animate)
 local t={parent=parent,part=part,animate=animate};function t.freeze()t.frozen=true end;function t.destroy()t.dead=true end;table.insert(tools,t);return t
end}
local Players={LocalPlayer=player};local attrs={};local modal,enabled,destroy=signal(),signal(),signal()
local screen={Enabled=true,GetAttribute=function(_,k)return attrs[k]end,GetAttributeChangedSignal=function()return modal end,GetPropertyChangedSignal=function()return enabled end,Destroying=destroy}
local function prompt(owner)
 local data={OwnerUserId=owner};local part={AttributeChanged=signal(),GetAttribute=function(_,k)return data[k]end,IsA=function()return true end}
 return{Parent=part,Name="ScrapeOldFinish",IsA=function(_,k)return k=="ProximityPrompt"end},data
end
local own,data=prompt(7);local foreign=prompt(8)
local added,removed=signal(),signal();local homes={DescendantAdded=added,DescendantRemoving=removed,GetDescendants=function()return{own,foreign}end}
local cameraChanged=signal();local workspace={CurrentCamera={},WaitForChild=function()return homes end,GetPropertyChangedSignal=function()return cameraChanged end};local lang="en"
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
hold:Fire(foreign,player);hold:Fire(own,{});assert(#tools==0,"Foreign hold created tool")
hold:Fire(own,player);local first=tools[#tools];assert(first and first.part==own.Parent and first.animate,"Native hold did not show tool")
hold:Fire(own,player);assert(#tools==1,"Duplicate hold created second tool")
attrs.LightPaintEffects=true;modal:Fire();assert(first.frozen and not first.dead,"Light mode did not freeze current gesture")
release:Fire(foreign,player);assert(not first.dead,"Another release stopped tool")
release:Fire(own,player);assert(first.dead,"Release retained tool")
hold:Fire(own,player);assert(not tools[#tools].animate,"Light mode animated tool");hidden:Fire(own);assert(tools[#tools].dead)
attrs.LightPaintEffects=false;Gui.ReducedMotionEnabled=true;hold:Fire(own,player);assert(not tools[#tools].animate);trigger:Fire(own,player);assert(tools[#tools].dead,"Native completion retained tool")
Gui.ReducedMotionEnabled=false;hold:Fire(own,player);Gui.ReducedMotionEnabled=true;settings:Fire();assert(tools[#tools].frozen);hidden:Fire(own);Gui.ReducedMotionEnabled=false
for _,event in {Input.WindowFocusReleased,player.CharacterRemoving,cameraChanged,death}do
 hold:Fire(own,player);local t=tools[#tools];event:Fire();assert(t.dead,"Lifecycle retained scraper")
 release:Fire(own,player);assert(t.dead,"Late release revived tool")
end
hold:Fire(own,player);attrs.ModalOpen=true;modal:Fire();assert(tools[#tools].dead,"Menu retained tool");attrs.ModalOpen=false;modal:Fire()
hold:Fire(own,player);screen.Enabled=false;enabled:Fire();assert(tools[#tools].dead);screen.Enabled=true;enabled:Fire()
hold:Fire(own,player);status="Error";profile:Fire();assert(tools[#tools].dead);status="Ready";profile:Fire()
hold:Fire(own,player);data.Cleared=true;own.Parent.AttributeChanged:Fire("Cleared");assert(tools[#tools].dead,"Confirmed clear retained tool");data.Cleared=false;own.Parent.AttributeChanged:Fire("Cleared")
hum.Health=0;local n=#tools;hold:Fire(own,player);assert(#tools==n,"Dead avatar started scraper");hum.Health=100
hold:Fire(own,player);removed:Fire(own);assert(tools[#tools].dead,"Removed prompt retained tool");own.Enabled=false;data.Cleared=false;modal:Fire();assert(not own.Enabled,"Removed prompt retained subscription")
added:Fire(own);assert(own.Enabled);local count=#connections;added:Fire(own);assert(#connections==count,"Duplicate event subscribed twice")
hold:Fire(own,player);destroy:Fire();assert(tools[#tools].dead,"Destroyed HUD retained tool");for _,c in connections do assert(not c.Connected,"Destroyed HUD retained prompt subscription")end
local n=#tools;hold:Fire(own,player);assert(#tools==n,"Destroyed HUD accepted late hold");own.Enabled=false;api.render();modal:Fire();assert(not own.Enabled,"Late render revived prompt")
print("PASS PreparationPrompts: actual owner/late replication, EN-RU, menus/profile, confirmed clear, removal/dedup and cleanup")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(header+s+checks);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
