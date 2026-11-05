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
finish=source.index('\n\t\tresultContinue.Text =',start)
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
