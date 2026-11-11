#!/usr/bin/env python3
"""Execute the real Main resize and caption code through shrinking and restoring."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/Main.client.luau").read_text()
start = source.index("local function phoneCaption()")
caption = source[start:source.index("\nlocal function render()", start)]
start = source.index("local function place(gui:")
body = source[start:source.index('\nscreen:GetPropertyChangedSignal("AbsoluteSize")', start)]
header = r'''
local Layout=require("../src/shared/HudLayout")
local Theme=require("../src/shared/Theme")
local Strings=require("../src/shared/Strings")
local InputConfig=require("../src/shared/InputConfig")
local function gui()return{Visible=true,IsA=function()return true end}end
local wallet,languageButton,homeButton,objective=gui(),gui(),gui(),gui()
local title,balance,objectiveTitle,objectiveHint=gui(),gui(),gui(),gui()
local objectiveLimit={}
local private,apps=gui(),gui()
local action,nav=gui(),gui()
function objective:FindFirstChild()return action end
local attrs={ShowHints=true};local status="Ready"
local player={GetAttribute=function()return status end}
local screen={AbsoluteSize={X=1449,Y=846},GetAttribute=function(_,k)return attrs[k]end,FindFirstChild=function()return nav end}
local UIS={TouchEnabled=false}
local Vector2={zero={},new=function(x,y)return{X=x,Y=y}end}
local UDim2={new=function(xs,x,ys,y)return{X={Scale=xs,Offset=x},Y={Scale=ys,Offset=y}}end}
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
local language="en"
local function size(w,h)screen.AbsoluteSize={X=w,Y=h}end
'''
checks = r'''
resize();local oldHome=homeButton.Position
size(625,230);resize()
assert(homeButton.Position~=oldHome and homeButton.Position.Y.Offset+homeButton.Size.Y.Offset<=230,"Shrinking below 240 kept stale Home geometry")
assert(not title.Visible and balance.Position.Y.Offset==8 and homeButton.Text==Strings.text(language,"home"),"Low HUD retained large captions")
assert(not private.Visible and apps.Position.Y.Offset==64 and apps.Size.Y.Offset==-144,"Low phone cannot show a full app row")
assert(objectiveTitle.Visible and not objectiveHint.Visible and action.Position.Y.Offset==48 and action.Size.Y.Offset>=44,"Compact HUD lost goal or action")
objectiveHint.Text="confirmed error";attrs.JobHintError=true;resize()
assert(not objectiveTitle.Visible and objectiveHint.Visible and objectiveHint.Position.Y.Offset==8 and objectiveHint.Size.Y.Offset==36,"Compact HUD hid its error")
assert(objectiveHint.Text=="confirmed error" and action.Visible,"Resize changed error text or removed the action")
attrs.JobHintError=false;attrs.ShowHints=false;resize()
assert(objectiveTitle.Visible and not objectiveHint.Visible,"Error expiry did not restore the goal")
for _,locale in {"en","ru"}do
 language=locale
 for _,s in {{280,224},{625,230},{625,359},{625,360},{1449,846},{625,230}}do
  size(s[1],s[2]);resize()
  assert(homeButton.Position.X.Offset+homeButton.Size.X.Offset<=s[1] and homeButton.Position.Y.Offset+homeButton.Size.Y.Offset<=s[2],"Home escaped after shrink/restore")
 end
end
size(1449,846);resize()
assert(title.Visible and balance.Position.Y.Offset==28 and private.Visible and apps.Position.Y.Offset==104 and apps.Size.Y.Offset==-184,"Growing window did not restore details")
assert(homeButton.Text==Strings.text(language,"home").." ["..InputConfig.phoneKey.."]","Desktop hotkey caption did not return")
attrs.ShowHints=true;attrs.JobHintError=true;resize()
assert(objectiveTitle.Visible and objectiveHint.Visible and objectiveHint.Position.Y.Offset==35 and objectiveHint.Size.Y.Offset==48,"Large HUD retained compact error placement")
attrs.JobHintError=false;UIS.TouchEnabled=true;size(374,608);resize()
assert(not title.Visible and homeButton.Text==Strings.text(language,"home") and action.Visible,"Touch layout regressed")
UIS.TouchEnabled=false;status="Error";size(625,230);resize()
assert(not action.Visible and objectiveTitle.Visible,"Resize enabled gameplay under a profile error")
status="Ready";resize();assert(action.Visible,"Profile recovery did not restore the action")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + caption + "\n" + body + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS HudResizeUI: actual resize/captions, low app rows, errors, EN/RU, shrink/restore, touch and profile guard")
