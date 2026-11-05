#!/usr/bin/env python3
"""Execute actual offer selection/eligibility and acceptance callback."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/JobOffersController.luau").read_text()
start = source.index("\tlocal function selectedOffer()")
finish = source.index("\n\tlocal render:", start)
selection = source[start:finish]
start = source.index("\t\tconfirm.Active =")
finish = source.index("\n\t\tconfirm.AutoButtonColor", start)
eligibility = source[start:finish]
start = source.index("\tconfirm.Activated:Connect(function()")
finish = source.index("\n\treturn {", start)
callback = source[start:finish]
header = '''
local state={available=true,offers={{id="mint",unlocked=false},{id="basic",unlocked=true}}}
local selected="mint"
local awaiting,epoch=false,0
local panel={Parent={}}
local clicked
local confirm={Activated={Connect=function(_,fn)clicked=fn end}}
local requests,timers={},{}
local function accept(id)table.insert(requests,id)end
local task={delay=function(_,fn)table.insert(timers,fn)end}
'''
render = "\nlocal function render()\nlocal s=state;local offer=selectedOffer()\n" + eligibility + "\nend\n"
checks = '''
render();clicked();assert(#requests==0 and not confirm.Active,"Locked card sent accept")
selected="missing";render();clicked();assert(#requests==0,"Missing offer accepted")
selected="basic";render();clicked();clicked()
assert(#requests==1 and requests[1]=="basic" and awaiting,"Busy accept was duplicated")
timers[1]();assert(confirm.Active,"Unknown accept outcome left button stuck")
state.available=false;render();clicked();assert(#requests==1,"Unavailable profile accepted job")
state.available=true;render();clicked();assert(#requests==2)
panel.Parent=nil;timers[2]();assert(awaiting,"Timer redrew destroyed panel")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + selection + render + callback + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS JobOffersUI: lock, selection, busy, timeout, unavailable and cleanup")

start=source.index('\t\tshow = function(id: string?): ()')+len('\t\tshow = function(id: string?): ()')
finish=source.index('\n\t\tend,\n\t\tback =',start)
show='\nlocal function show(id)\n'+source[start:finish]+'\nend\n'
setup='''
local Vector2={zero=0}
local list,details={},{}
'''
checks='''
state.phase="Completed"
show("basic");assert(selected=="basic" and confirm.Active,"Recommended offer not previewed")
assert(#requests==0,"Preview automatically accepted a job")
show("mint");assert(selected==nil and not confirm.Active,"Locked recommendation opened as ready")
show("missing");assert(selected==nil,"Missing recommendation selected")
state.available=false;show("basic");assert(selected==nil,"Busy snapshot previewed recommendation")
state.available=true;state.phase="Inspect";show("basic");assert(selected==nil,"Recommendation interrupted current work")
state.phase="Offer";show();assert(selected==nil and list.CanvasPosition==0,"Default list changed")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as script:
    script.write(header+setup+selection+render+show+checks);script.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),script.name],cwd=ROOT,check=True)
print('PASS JobOffersUI: recommendation is preview-only, explicit accept and snapshot guards')
