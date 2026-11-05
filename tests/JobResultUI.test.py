#!/usr/bin/env python3
"""Exercise actual receipt-display and Continue callbacks, without Roblox rendering."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/JobController.luau").read_text()
start = source.index("\t\tlocal result = s.result")
finish = source.index("\n\t\trender()", start)
gate = "local function update(s)\n" + source[start:finish] + "\nend\n"
start = source.index("\tresultContinue.Activated:Connect(function()")
finish = source.index("\n\tend)", start) + len("\n\tend)")
callback = source[start:finish]
header = r'''
local results, homePanel = {Visible=false}, {Visible=true}
local shownOperation = nil
local Vector2={zero={}}
local resultBody={CanvasPosition={}}
local hidden = 0
local function hidePanels() hidden+=1;results.Visible=false end
local clicked
local resultContinue={Activated={Connect=function(_,fn) clicked=fn end}}
local step="BUY"
local accepting=false
local function acceptancePending()return accepting end
local status="Ready"
local Mastery=require("../src/shared/PaintingMastery")
local state={available=true,phase="Completed",paintingXP=120,result={operationId="job:current",xp=70},offers={
 {id="basic",titleKey="basic",requiredXP=0,unlocked=true},
 {id="mint",titleKey="mint",requiredXP=50,unlocked=true},
 {id="rose",titleKey="rose",requiredXP=120,unlocked=true},
 {id="duo",titleKey="duo",requiredXP=210,unlocked=false}}}
local player={GetAttribute=function(_,key) return if key=="ProfileStatus"then status else step end}
local preview,previews=nil,0
local offers={show=function(id)preview=id;previews+=1 end}
local jobs={Visible=false}
local function stopTravel()end
local function hideHousing()end
local function render()end
local route=nil
local function homeAction(tab) route=tab end
local function send() error("Results must not send a financial command") end
'''
cases = {
    "continue_acceptance_pending": '''
accepting=true;results.Visible=true;clicked()
assert(results.Visible and route==nil and previews==0,"Pending acceptance opened another recommendation")
''',
    "first_receipt_and_duplicate": '''
update({result={operationId="job:a"},available=true})
assert(results.Visible and hidden==1 and not homePanel.Visible)
assert(resultBody.CanvasPosition==Vector2.zero,"New receipt did not reveal payment/grade")
results.Visible=false
update({result={operationId="job:a"},available=true})
assert(not results.Visible and hidden==1,"Dismissed receipt reopened")
''',
    "unconfirmed_then_confirmed": '''
update({result={operationId="job:a"},available=false})
assert(not results.Visible and shownOperation==nil)
update({result={operationId="job:a"},available=true})
assert(results.Visible and shownOperation=="job:a")
''',
    "new_receipt_and_no_receipt": '''
update({result={operationId="job:a"},available=true})
update({available=true})
assert(not results.Visible)
update({result={operationId="job:b"},available=true})
assert(results.Visible and shownOperation=="job:b")
''',
    "continue_purchase": '''
results.Visible=true;clicked()
assert(not results.Visible and route=="Shop")
''',
    "continue_placement": '''
step="PLACE";results.Visible=true;clicked()
assert(not results.Visible and route=="Furniture")
''',
    "continue_unavailable": 'status="Error";results.Visible=true;clicked();assert(results.Visible and previews==0 and route==nil,"Lost profile continued result")',
    "continue_busy": 'state.available=false;results.Visible=true;clicked();assert(results.Visible and previews==0 and route==nil,"Busy profile continued result")',
    "continue_stale": 'state.phase="Inspect";results.Visible=true;clicked();assert(results.Visible and previews==0 and route==nil,"Old result navigated during new work")',
    "continue_after_onboarding": '''
step="DONE";results.Visible=true;clicked()
assert(not results.Visible and route==nil and jobs.Visible and preview=="rose","Continue did not preview recommended work")
clicked();assert(previews==1,"Hidden Continue repeated navigation")
''',
}
for name, checks in cases.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + gate + callback + "\n" + checks)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS JobResultUI:", name)

start=source.index('\t\tlocal required = if receipt')
finish=source.index('\n\t\tlocal quality = Finish.evaluate',start)
colours=source[start:finish]
header='''
local Config=require("../src/shared/PaintConfig")
local Strings=require("../src/shared/Strings")
local lang="en"
local function t(key)return Strings.text(lang,key)end
local Color3={new=function(r,g,b)return {r=r,g=g,b=b}end}
local ColorSequence={new=function(first,last)return {first=first,last=last}end}
local afterGradient,after,resultQuality={},{},{}
local function paintResult(s)
 local receipt=s.result
'''
checks='''
for _,locale in {"en","ru"}do
 lang=locale
 local receipt={primaryColorId="mint",secondaryColorId="rose"}
 for _,current in {"rose","mint","warm-white"}do
  paintResult({result=receipt,requiredColorId=current})
  assert(afterGradient.Enabled and after.BackgroundColor3.r==1,"Two-wall result lost gradient")
  assert(afterGradient.Color.first.r==Config.palette.mint[1] and afterGradient.Color.last.r==Config.palette.rose[1],"Result used transient last wall")
  assert(after.Text==t("resultAfterDuo") and resultQuality.Text==t("resultAcceptedDuo"),"Whole-contract result unclear")
 end
 paintResult({result={primaryColorId="warm-white"},requiredColorId="rose"})
 assert(not afterGradient.Enabled and after.BackgroundColor3.r==Config.color[1],"Single-wall result changed")
end
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as script:
    script.write(header+colours+'\nend\n'+checks);script.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),script.name],cwd=ROOT,check=True)
print('PASS JobResultUI: stable confirmed two-colour result, EN/RU and single-wall compatibility')

start=source.index('\t\tlocal quality = Finish.evaluate')
finish=source.index('\n\t\tresultContinue.Text =',start)
quality=source[start:finish]
header='''
local Finish=require("../src/shared/PaintFinish")
local Strings=require("../src/shared/Strings")
local lang="en"
local function t(key)return Strings.text(lang,key)end
local resultQuality={}
local results={Visible=true}
local shown
local comparison={render=function(receipt)shown=receipt end}
local function renderQuality(receipt,available)
 local s={available=available};resultQuality.Text=t("resultAccepted")
'''
checks='''
for _,locale in {"en","ru"}do
 lang=locale
 for _,count in {77,92,96}do
  local receipt={finish={columns=12,rows=8,masks={string.rep("1",count)..string.rep("0",96-count)}}}
  renderQuality(receipt,true)
  local key=if count==96 then "finishperfect"elseif count>=92 then "finishexcellent"else "finishaccepted"
  assert(resultQuality.Text==string.format(t(key),math.floor(count*100/96)).."\\n"..t("finishPaid"),"Wrong confirmed grade text")
  assert(shown==receipt,"Visible receipt did not render its scene")
  results.Visible=false;renderQuality(receipt,true);assert(shown==nil,"Closed result retained geometry");results.Visible=true
  renderQuality(receipt,false);assert(shown==nil,"Unavailable result created geometry")
 end
 local duo={finish={columns=12,rows=8,masks={string.rep("1",96),string.rep("1",77)..string.rep("0",19)}}}
 renderQuality(duo,true)
 assert(resultQuality.Text==string.format(t("finishaccepted"),80).."\\n"..string.format(t("finishWalls"),100,80),"Weak wall hidden by average")
 renderQuality({},true);assert(resultQuality.Text==t("resultAccepted"),"Legacy receipt invented grade")
end
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as script:
    script.write(header+quality+'\nend\n'+checks);script.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),script.name],cwd=ROOT,check=True)
print('PASS JobResultUI: confirmed grades, worst wall, legacy and closed/unavailable geometry guards')
