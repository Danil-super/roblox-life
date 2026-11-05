#!/usr/bin/env python3
"""Execute the real diagnostic adapter with a deterministic Output/HTTP boundary."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/server/Diagnostics.luau").read_text().removeprefix("--!strict\n")
source = source.replace('require("./Domain/', 'require("../src/server/Domain/')
header = '''
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local output, payloads = {}, {}
local encodingFails, printingFails = false, false
local Http = {JSONEncode=function(_,payload)
 if encodingFails then error("private encoding failure") end
 table.insert(payloads,payload)
 return "encoded"
end}
local game = {GetService=function(_,name)assert(name=="HttpService");return Http end}
local function print(value)
 if printingFails then error("private output failure") end
 table.insert(output,value)
end
'''
cases = '''
local trace = "12345678-1234-1234-1234-123456789abc"
local p = Profile.new(123456789)
local state = Diagnostics.observe(trace,nil,p)
assert(#output==0 and #payloads==0,"Join replayed old progress")
assert(Jobs.accept(p,"private-job","paint-tutorial-v1"))
state = Diagnostics.observe(trace,state,p)
assert(#output==1 and #payloads==1)
local event = payloads[1]
assert(event.event=="profile_change" and event.entry=="confirmed" and event.schema==1 and event.trace==trace)
assert(event.revision==p.revision and event.dollarsDelta==0 and event.xpDelta==0)
local allowed = {schema=true,event=true,trace=true,entry=true,revision=true,dollarsDelta=true,xpDelta=true,changes=true,omitted=true}
for key in event do assert(allowed[key],"Unapproved profile field logged") end
for _,change in event.changes do
 for key,value in change do
  assert(key=="event" or key=="subject" or key=="amount" or key=="xp","Unapproved change field")
  if type(value)=="string" then assert(not string.find(value,"private",1,true),"Private identifier leaked") end
 end
end
Diagnostics.observe(trace,state,p)
assert(Diagnostics.observe(trace,state,Profile.new(123456789))==state,"Rollback replaced newer baseline")
assert(#output==1,"Replay/rollback emitted another transaction")
encodingFails=true
assert(Jobs.cancel(p,"private-job"))
state = Diagnostics.observe(trace,state,p)
assert(state.revision==p.revision,"Encoding failure blocked the committed baseline")
encodingFails=false
Diagnostics.observe(trace,state,p)
assert(#output==1,"Sink recovery duplicated an event")
assert(Jobs.accept(p,"private-new-job","paint-tutorial-v1"))
printingFails=true
state=Diagnostics.observe(trace,state,p)
assert(state.revision==p.revision,"Output failure escaped into gameplay")
Diagnostics.emit("profile_failure","private-trace","change",false,"private error with personal data")
printingFails=false
Diagnostics.emit("profile_failure","private-trace","change",false,"private error with personal data")
local failure=payloads[#payloads]
assert(failure.trace=="redacted" and failure.reason=="Other" and failure.outcome=="blocked")
Diagnostics.emit("profile_recovery",trace,"manual",true,"Requested")
assert(payloads[#payloads].reason=="Requested")
Diagnostics.emit("profile_failure",trace,"spawn",false,"CharacterLoad")
assert(payloads[#payloads].reason=="CharacterLoad","Known recovery reason was lost")
local separate=Diagnostics.observe(trace,nil,Profile.new(98765))
assert(separate.revision==0 and separate.job==nil,"Another profile inherited baseline")
local Store=require("../src/server/Domain/ProfileStore")
local saved, failAfter=nil,false
local adapter={update=function(_,transform)
 saved=transform(saved)
 return not failAfter,if failAfter then "private storage error" else saved
end}
local session=Store.new(adapter,99,"private-owner-token",function()return 100 end,60)
assert(session.load())
local confirmed
local function publish()
 local profile=session.read()
 if profile then confirmed=Diagnostics.observe(trace,confirmed,profile)end
end
publish()
local count=#output
failAfter=true
assert(not session.transact(function(profile)
 return Jobs.accept(profile,"private-uncertain-job","paint-tutorial-v1")
end))
publish()
assert(session.read()==nil and #output==count,"Unacknowledged write emitted a confirmed event")
failAfter=false
assert(session.retry())
publish()
assert(#output==count+1 and payloads[#payloads].changes[1].event=="job_accepted","Recovery lost confirmed milestone")
publish()
assert(#output==count+1,"Repeated publish duplicated recovered milestone")
'''
script = '--!strict\n' + header + '\nlocal Diagnostics=(function()\n' + source + '\nend)()\n' + cases
with tempfile.NamedTemporaryFile(mode="w", suffix=".luau", dir=ROOT / "tests") as file:
    file.write(script)
    file.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), file.name], cwd=ROOT, check=True)
print("Diagnostics: actual adapter schema/privacy, replay, sink failures and isolation passed")
