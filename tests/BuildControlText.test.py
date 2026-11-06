#!/usr/bin/env python3
"""Execute real button construction/render for compact labels and actionable states."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/BuildController.luau").read_text()
a = source.index("\tlocal buttons:")
construction = source[a:source.index("\n\tlocal function t(", a)]
a = source.index("\tlocal function render(): ()")
render = source[a:source.index("\n\tlocal function stop(", a)]
header = r'''
local Strings=require("../src/shared/Strings")
local PlacementFlow=require("../src/shared/PlacementFlow")
local UDim2={new=function(xs,xo,ys,yo)return {XS=xs,XO=xo,YS=ys,YO=yo}end}
local Color3={fromRGB=function()return{}end}
local Enum={Font={GothamBold=1}}
local Instance={new=function()return{}end}
local bar={}
local title,status={},{}
local now=0
local os={clock=function()return now end}
local UIS={TouchEnabled=false}
local lang="en"
local function t(key)return Strings.text(lang,key)end
local item={catalogId="floor-plant-v1"}
local x,z,rotation,mode=8,6,105,"Free"
local active,valid,pinned,waiting=true,true,false,false
local confirmedAt,reason,pending=0,"Valid",nil
local snapshot={available=true}
local ghost,guides=nil,nil
local mouseHeld,touch=false,nil
'''
checks = r'''
local count=0
for _,b in buttons do
 count+=1
 for _,width in {320,374,666,1161}do
  local pixels=math.min(640,width-24)*b.Size.XS+b.Size.XO
  assert(pixels>=44 and b.Size.YO>=44,"Build target below 44px")
 end
end
assert(count==5,"Missing direction control")
for _,locale in {"en","ru"}do
 lang=locale
 for _,deviceTouch in {false,true}do
  UIS.TouchEnabled=deviceTouch;waiting=false;pending=nil;valid=true;pinned=false;now=0
  render()
  assert(title.Text==string.format(t("buildAngle"),t(item.catalogId),105),"Current item/angle missing")
  assert(status.Text==t(if deviceTouch then "touchFloor"else "clickFloor"),"Wrong input instruction")
  assert(buttons.Rotate.Text:find("+15°",1,true)and buttons.RotateLeft.Text:find("-15°",1,true),"Free rotation step missing")
  assert(not buttons.Confirm.Active,"Unpinned preview enabled save")
  for _,gesture in {"mouse","touch"}do
   mouseHeld=gesture=="mouse";touch=if gesture=="touch"then {}else nil
   render();assert(status.Text==t("releaseFurniture")and not buttons.Confirm.Active,"Dragging enabled save or hid release instruction")
   valid=false;reason="Blocked";render();assert(status.Text==t("homeErrorBlocked"),"Drag hint concealed server refusal")
   valid=true;reason="Valid"
  end
  mouseHeld=false;touch=nil
  pinned=true;render();assert(buttons.Confirm.Active,"Confirmed pose did not enable save")
  if deviceTouch then
   assert(buttons.Mode.Text==t("buildFreeCompact") and buttons.Confirm.Text==t("buildConfirmCompact"),"Compact controls kept long labels")
   assert(not buttons.Rotate.Text:find("R",1,true),"Touch requested keyboard")
  else
   assert(buttons.RotateLeft.Text:find("Q",1,true)and buttons.Mode.Text:find("[G]",1,true)and buttons.Confirm.Text:find("[Enter]",1,true),"Keyboard bindings invisible")
  end
  snapshot.available=false;render();assert(not buttons.Confirm.Active,"Unavailable profile enabled save")
  snapshot.available=true
  pending=PlacementFlow.start("place-one","editor","plant",2,{x=x,z=z,rotationY=rotation,mode=mode},0)
  waiting=true;render()
  assert(not buttons.Confirm.Active,"Waiting enabled immediate retry")
  assert(not buttons.RotateLeft.Active and not buttons.Rotate.Active and not buttons.Mode.Active and not buttons.Cancel.Active,"Pending controls remained active")
  assert(buttons.Confirm.Text==(if deviceTouch then t("buildWaitCompact")else t("saving").." [Enter]"),"Wrong pending caption")
  now=8;render()
  assert(buttons.Confirm.Active and buttons.Confirm.Text==(if deviceTouch then t("buildRetryCompact")else t("retryPlacement").." [Enter]"),"Retry label/guard missing")
 end
end
active=false;render();assert(not buttons.Confirm.Active and not buttons.RotateLeft.Active,"Closed controls remained active")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + construction + render + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS BuildControlText: actual 44px targets, EN/RU, angle, touch/keyboard, ready/wait/retry and profile guards")
