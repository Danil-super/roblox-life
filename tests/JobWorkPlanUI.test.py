#!/usr/bin/env python3
"""Run the complete work-plan renderer; native geometry is checked separately in Studio."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/JobWorkPlanController.luau").read_text()
body = source[source.index("function Controller.start("):source.rindex("\nreturn Controller")]
header = r'''
local Plan=require("../src/shared/JobWorkPlan")
local Strings=require("../src/shared/Strings")
local Theme=require("../src/shared/Theme")
local Controller={}
local pool={}
local Instance={new=function(kind)
 local o={ClassName=kind,Visible=true}
 table.insert(pool,o)
 function o:FindFirstChild(name)
  for _,child in pool do if child.Parent==self and child.Name==name then return child end end
  error("Missing GUI "..name)
 end
 o.Destroying={Once=function(_,fn)o.onDestroy=fn end}
 return o
end}
local UDim2={
 fromOffset=function(x,y)return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}}end,
 new=function(xs,xo,ys,yo)return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end,
}
local Color3={fromRGB=function(r,g,b)return tostring(r)..":"..tostring(g)..":"..tostring(b)end}
local Enum={Font={GothamBold=1,GothamMedium=2},TextXAlignment={Left=1,Center=2,Right=3}}
local lang="en"
local function language()return lang end
local function snapshot(phase)
 return {available=true,phase=phase,jobId="job",workId="work",count=0,mask="",sequence=0,reward=250,near=false}
end
local workBody=Instance.new("ScrollingFrame")
workBody.CanvasSize=UDim2.fromOffset(0,274)
workBody.CanvasPosition={Y=85}
'''
checks = r'''
local api=Controller.start(workBody,language)
local root=workBody:FindFirstChild("WorkPlan")
assert(not root.Visible and #pool==29,"Unexpected renderer budget or initial visibility")
for _,locale in {"en","ru"}do
 lang=locale
 for step,phase in {"Inspect","Prepare","ChooseMaterial","Painting","Ready"}do
  local s=snapshot(phase)
  local caption=api.render(s,true)
  local expected=string.format(Strings.text(lang,"workPlanStep"),step,5)..(if phase=="Painting"then " · 0%"else "")
  assert(caption==expected,"Caption invented coverage before painting")
  assert(root.Visible and workBody.CanvasSize.Y.Offset==666,"Plan outside scroll canvas")
  for i=1,5 do
   local row=root:FindFirstChild("Step"..i)
   local key=if i<step then "Done"elseif i==step then "Current"else "Next"
   assert(row:FindFirstChild("State").Text==Strings.text(lang,"workPlan"..key),"Color-only or wrong status")
   assert(row:FindFirstChild("Title").Font==(if i==step then Enum.Font.GothamBold else Enum.Font.GothamMedium),"Current step not highlighted")
  end
 end
 local s=snapshot("Painting");s.count=96
 api.render(s,true)
 assert(root:FindFirstChild("Step4"):FindFirstChild("State").Text==Strings.text(lang,"workPlanCurrent"),"Full mask accepted wall")
 assert(root:FindFirstChild("Note").Text==Strings.text(lang,"workPlanReviewHint"),"Missing review instruction")
 s.phase,s.surfaceIndex,s.surfaceTotal="SurfaceReady",1,2
 local caption=api.render(s,true)
 assert(caption==string.format(Strings.text(lang,"surfaceProgress"),1,2).." · "..Strings.text(lang,"workPlanWallChecked"),"Intermediate wall advertised handover")
 assert(root:FindFirstChild("Step5"):FindFirstChild("State").Text==Strings.text(lang,"workPlanNext"),"First wall enabled final step")
 assert(root:FindFirstChild("Note").Text==Strings.text(lang,"workPlanNextHint"),"No next-wall explanation")
 s.phase,s.surfaceIndex,s.count="ChooseMaterial",2,0
 api.render(s,true)
 assert(root:FindFirstChild("Step4"):FindFirstChild("State").Text==Strings.text(lang,"workPlanNext"),"New wall retained old check")
end
assert(#pool==29 and workBody.CanvasPosition.Y==85,"Render allocated objects or stole scroll position")
for _,phase in {"Offer","Completed","Unknown"}do
 assert(api.render(snapshot(phase),true)==nil and not root.Visible and workBody.CanvasSize.Y.Offset==274,"Stale plan survived inactive phase")
end
assert(api.render(nil,true)==nil and api.render(snapshot("Inspect"),false)==nil,"Unready profile exposed plan")
local s=snapshot("Inspect");s.available=false
assert(api.render(s,true)==nil,"Unavailable snapshot exposed plan")
local other=Instance.new("ScrollingFrame");other.CanvasSize=UDim2.fromOffset(0,274)
local second=Controller.start(other,language);second.render(snapshot("Ready"),true)
api.render(snapshot("Prepare"),true)
assert(root:FindFirstChild("Step2"):FindFirstChild("State").Text==Strings.text(lang,"workPlanCurrent"),"Other player's render changed current plan")
assert(other:FindFirstChild("WorkPlan"):FindFirstChild("Step5"):FindFirstChild("State").Text==Strings.text(lang,"workPlanCurrent"),"Instances share renderer state")
workBody.onDestroy();local before=#pool
assert(api.render(snapshot("Painting"),true)==nil and #pool==before,"Destroyed body revived renderer")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + body + "\n" + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS JobWorkPlanUI: EN/RU, confirmed phases, two walls, fixed 28-object budget, scroll, isolation and cleanup")
