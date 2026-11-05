#!/usr/bin/env python3
"""Execute actual cancellation UI callbacks and lifecycle with a controlled clock."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/JobAbandonController.luau").read_text()
tail = source[source.index("\tlocal function pending()"):source.rindex("\nend\nreturn Controller")]
header = '''
local Flow=require("../src/shared/JobAbandonFlow")
local Strings=require("../src/shared/Strings")
local target,state=nil,nil
local disposed=false
local now=10
local os={clock=function()return now end}
local profileReady=true
local player={GetAttribute=function()return if profileReady then "Ready"else "Error"end}
local function language()return "en"end
local contractKey="jobs"
local panel={Visible=false}
local title,order,message,body={},{},{},{}
local Vector2={zero=0}
local clicks={}
local function button(name)
 return {Activated={Connect=function(_,fn)clicks[name]=fn end}}
end
local keep,confirm=button("keep"),button("confirm")
local destroying
local screen={Destroying={Once=function(_,fn)destroying=fn end}}
local requests,closures={},{}
local function sendCancel(job,work)table.insert(requests,{jobId=job,workId=work})end
local function closed(waiting)table.insert(closures,waiting)end
local function snapshot()
 return {available=true,phase="Painting",jobId="job-one",workId="work-one",count=40,
 contractId="tutorial",offers={{id="tutorial",titleKey="contractTutorial"}}}
end
local function start()
'''
checks = '''
local s=snapshot()
api.ask(s);assert(panel.Visible and confirm.Active and #requests==0,"Question sent cancellation")
assert(order.Text==Strings.text("en","contractTutorial") and message.Text==Strings.text("en","abandonWarning"))
clicks.keep();assert(not panel.Visible and not api.pending() and closures[1]==false,"Keep abandoned work")
assert(s.count==40 and s.phase=="Painting","Keep mutated work")
api.ask(s);clicks.confirm();clicks.confirm()
assert(#requests==1 and requests[1].jobId=="job-one" and requests[1].workId=="work-one" and api.pending(),"Rapid confirm changed/duplicated target")
api.hide();assert(api.pending() and not panel.Visible,"Closing lost unknown cancellation")
api.resume();assert(panel.Visible)
now=17.99;api.render(s);assert(not confirm.Active,"Retry too early")
now=18;api.render(s);assert(confirm.Active and confirm.Text==Strings.text("en","abandonRetry"))
profileReady=false;api.render(s);clicks.confirm();assert(#requests==1 and not confirm.Active,"Lost profile retried")
profileReady=true;s.available=false;api.render(s);assert(api.pending() and not confirm.Active,"Busy released cancellation")
s.available=true;api.render(s);clicks.confirm()
assert(#requests==2 and requests[2].jobId==requests[1].jobId and requests[2].workId==requests[1].workId,"Retry targeted another order")
s.phase="Offer";s.workId="";api.render(s)
assert(not panel.Visible and not api.pending() and closures[#closures]==false,"Server cancellation did not return to orders")
local next=snapshot();next.jobId="job-two";next.workId="work-two"
api.ask(next);clicks.confirm();clicks.keep()
assert(api.pending() and not panel.Visible and closures[#closures]==true,"Close pretended pending cancellation was undone")
api.ask(s);assert(api.pending() and not confirm.Active,"New question replaced old pending target")
api.render(s);assert(not api.pending(),"Changed identity retained old request")
api.ask(next);clicks.confirm();clicks.keep()
local closeCount=#closures
local finished=snapshot();finished.phase="Offer";finished.jobId="job-two";finished.workId=""
api.render(finished)
assert(not api.pending() and not panel.Visible and #closures==closeCount,"Hidden resolution stole focus from another mode")
api.ask(next);local before=#requests;api.hide();clicks.confirm();assert(#requests==before,"Hidden confirm sent cancellation")
api.ask(next);destroying();api.resume();api.ask(next);clicks.confirm()
assert(#requests==before and not api.pending(),"Destroyed HUD sent cancellation")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + tail + "\nend\nlocal api=start()\n" + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS JobAbandonUI: question, keep, debounce, pending close/resume, exact retry, profile and cleanup")

controller = (ROOT / 'src/client/JobController.luau').read_text()
a = controller.index('\tlocal function send(actionName:')
b = controller.index('\n\tlocal offers =', a)
send_body = controller[a:b]
checks = '''
local waiting=true
local abandon={pending=function()return waiting end}
local state={jobId="old-job",workId="old-work"}
local packets={}
local command={FireServer=function(_,p)table.insert(packets,p)end}
'''+send_body+'''
for _,action in {"accept","submit","choose","tool","cancel","talk"}do send(action,nil)end
assert(#packets==0,"Pending cancellation allowed another job command")
send("sync",nil);assert(#packets==1 and packets[1].action=="sync","Pending cancellation stopped reconciliation")
waiting=false;send("choose",{color="mint"})
assert(#packets==2 and packets[2].jobId=="old-job" and packets[2].workId=="old-work","Resolved cancellation broke normal commands")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as script:
    script.write(checks);script.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),script.name],cwd=ROOT,check=True)
print('PASS JobAbandonUI: pending blocks job mutations and keeps sync available')
