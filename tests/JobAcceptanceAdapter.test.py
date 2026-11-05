#!/usr/bin/env python3
"""Execute the real accept command branch, including transaction baseline checks."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'src/server/JobService.luau').read_text()
a=source.index('\t\tif action == "accept" then')
b=source.index('\n\t\tensure(player, ctx)',a)
branch=source[a:b]
header='''
local Profile=require("../src/server/Domain/Profile")
local Jobs=require("../src/server/Domain/Jobs")
local EconomyConfig=require("../src/server/Domain/EconomyConfig")
local p=Profile.new(1)
local player,ctx={},{saving=false}
local serial,writes,ensures=0,0,0
local drift=false
local HttpService={GenerateGUID=function()serial+=1;return "server-job-"..serial end}
local profiles={change=function(_,mutate)
 if drift then assert(Jobs.accept(p,"concurrent-job","paint-tutorial-v1"));assert(Jobs.cancel(p,"concurrent-job"));drift=false end
 local ok=mutate(p);if ok then writes+=1 end;return ok
end}
local sent={}
local function send(_,_,reason,_,ack)table.insert(sent,{reason=reason,ack=ack})end
local function ensure()ensures+=1 end
local function request(data)
 local action="accept"
'''
checks='''
request({offerId="paint-tutorial-v1"});assert(serial==0 and writes==0,"Missing IDs accepted")
request({jobId="",requestId="",offerId="paint-tutorial-v1"});assert(serial==0)
request({jobId="",requestId=string.rep("x",81),offerId="paint-tutorial-v1"});assert(serial==0)
request({jobId="",requestId="locked",offerId="paint-mint-v1"})
assert(sent[#sent].ack.requestId=="locked"and sent[#sent].ack.offerId=="paint-mint-v1"and sent[#sent].ack.jobId==""and sent[#sent].reason=="OfferLocked"and writes==0)
request({jobId="",requestId="unknown",offerId="missing"})
assert(sent[#sent].ack.error=="UnknownOffer"and writes==0)
request({jobId="",requestId="one",offerId="paint-tutorial-v1"})
assert(writes==1 and ensures==1 and p.jobs.active.id=="server-job-1"and p.jobs.issuedSequence==1)
request({jobId="",requestId="one",offerId="paint-tutorial-v1"})
assert(writes==1 and serial==1 and sent[#sent].reason=="Stale","Replay generated or wrote a second job")
assert(Jobs.cancel(p,"server-job-1"))
request({jobId="",requestId="one",offerId="paint-tutorial-v1"})
assert(writes==1 and p.jobs.active.status=="Abandoned","Late accept resurrected abandoned work")
request({jobId="server-job-1",requestId="two",offerId="paint-tutorial-v1"})
assert(writes==2 and p.jobs.active.id=="server-job-2"and p.jobs.issuedSequence==2)
assert(p.wallet.dollars==0 and p.progression.paintingXP==0)
-- Profile may change while the write adapter waits. Validate the candidate again.
p=Profile.new(2);drift=true
request({jobId="",requestId="race",offerId="paint-tutorial-v1"})
assert(p.jobs.active.id=="concurrent-job"and p.jobs.issuedSequence==1 and writes==2,"Transaction ignored newer baseline")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as file:
 file.write(header+branch+'\nend\n'+checks);file.flush()
 subprocess.run([str(ROOT/'.tools/bin/luau'),file.name],cwd=ROOT,check=True)
print('PASS JobAcceptanceAdapter: malformed IDs, correlated refusal, one write, stale replay, next baseline and candidate drift')
