#!/usr/bin/env python3
"""Exercise the real hints button without changing a job or calling the server."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/Main.client.luau").read_text()
start = source.index("hintsButton.Activated:Connect(function()")
finish = source.index("\nend)", start) + len("\nend)")
callback = source[start:finish]
header = '''
local click
local hintsButton={Activated={Connect=function(_,fn) click=fn end}}
local attrs={}
local screen={GetAttribute=function(_,k)return attrs[k]end,SetAttribute=function(_,k,v)attrs[k]=v end}
local renders,resizes=0,0
local function render() renders+=1 end
local function resize() resizes+=1 end
local command={FireServer=function()error("Hints sent a gameplay command")end}
'''
checks = '''
click();assert(attrs.ShowHints==false,"Default hints not hidden")
assert(renders==1 and resizes==1,"HUD did not update immediately")
click();assert(attrs.ShowHints==true,"Hidden hints cannot be restored")
click();assert(attrs.ShowHints==false,"Repeated toggle lost state")
assert(renders==3 and resizes==3,"Toggle duplicated HUD updates")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + callback + "\n" + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS HintsUI: hide, restore, repeat, immediate update")

jobs = (ROOT / "src/client/JobController.luau").read_text()
start = jobs.index("\t\tif s.error then", jobs.index("stateEvent.OnClientEvent"))
finish = jobs.index("\n\t\tstate = s", start)
error_body = jobs[start:finish]
expiry_header = '''
local now, renders = 0, 0
local os = {clock=function()return now end}
local queued = {}
local task = {delay=function(_,fn)table.insert(queued,fn)end}
local screen={Parent={}}
local lastError,errorUntil=nil,0
local function render() renders+=1 end
local function update(s)
'''
expiry_checks = '''
update({error="TooFar"})
assert(#queued==1,"Error cannot expire while navigation is idle")
now=1;update({error="Color"})
now=4;queued[1]();assert(renders==0,"Old timer redrew a newer error")
now=5;queued[2]();assert(renders==1,"Latest error did not expire")
update({error="Stale"});screen.Parent=nil;now=9;queued[3]()
assert(renders==1,"Expired error redrew a destroyed HUD")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(expiry_header + error_body + "\nend\n" + expiry_checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS HintsUI: idle error expiry, replacement and HUD cleanup")
