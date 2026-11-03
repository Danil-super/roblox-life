#!/usr/bin/env python3
"""Execute the real recovery request handler under concurrent and invalid requests."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/server/ProfileService.luau").read_text()
start = source.index("\tprofileRemote.OnServerEvent:Connect")
finish = source.index("\n\tremote.OnServerEvent", start)
body = source[start:finish]
header = '''
local callback
local profileRemote={OnServerEvent={Connect=function(_,fn)callback=fn end}}
local now,calls,finalized,failed,kicks=100,0,0,0,0
local os={clock=function()return now end}
local Players={}
local function player()
 local p={Parent=Players,attrs={ProfileStatus="Error"}}
 function p:GetAttribute(k)return self.attrs[k]end
 function p:SetAttribute(k,v)self.attrs[k]=v end
 function p:Kick()kicks+=1 end
 return p
end
local p=player()
local context={busy=false,closing=false,lastRetry=-math.huge,failure="StorageUnavailable",trace="safe-trace",session={status=function()return "Uncertain"end}}
local contexts={[p]=context}
local shuttingDown,Storage,RETRY_SECONDS=false,{},10
local shouldYield,success=false,true
local Recovery={
 action=function(_,reason)return if reason=="StorageUnavailable" then "retry" else nil end,
 attempt=function()
  calls+=1
  if shouldYield then coroutine.yield() end
  return success,if success then nil else "StorageUnavailable"
 end,
}
local events={}
local Diagnostics={emit=function(event,trace,entry,ok,reason)
 assert(trace=="safe-trace" and entry=="manual")
 table.insert(events,{event=event,ok=ok,reason=reason})
end}
local function finalizeReady(who,c)
 assert(not c.busy);finalized+=1;who:SetAttribute("ProfileStatus","Ready")
end
local function fail(who,c,reason)
 assert(not c.busy and reason=="StorageUnavailable");failed+=1;who:SetAttribute("ProfileStatus","Error")
end
'''
cases = {
    "busy_and_independent_players": '''
shouldYield=true
local running=coroutine.create(function()callback(p,"retry")end)
assert(coroutine.resume(running));assert(context.busy and calls==1)
for _=1,20 do callback(p,"retry")end
assert(calls==1 and finalized==0,"Concurrent retries entered storage")
local other=player();contexts[other]={busy=false,closing=false,lastRetry=-math.huge,failure="StorageUnavailable",trace="safe-trace",session=context.session}
shouldYield=false;callback(other,"retry");assert(calls==2 and finalized==1,"One player blocked another")
assert(coroutine.resume(running));assert(not context.busy and finalized==2)
''',
    "cooldown_and_failure": '''
success=false;callback(p,"retry");assert(calls==1 and failed==1)
now=109.99;callback(p,"retry");assert(calls==1,"Retry bypassed cooldown")
now=110;success=true;callback(p,"retry");assert(calls==2 and finalized==1)
''',
    "invalid_requests_and_terminal_failure": '''
for _,raw in {false,{},123,"load","retry-other-player"}do callback(p,raw)end
assert(calls==0)
context.failure="Corrupt";callback(p,"retry");assert(calls==0)
context.failure="StorageUnavailable";context.closing=true;callback(p,"retry");assert(calls==0)
context.closing=false;shuttingDown=true;callback(p,"retry");assert(calls==0)
''',
    "departure_during_recovery": '''
shouldYield=true;local running=coroutine.create(function()callback(p,"retry")end)
assert(coroutine.resume(running));p.Parent=nil;context.closing=true
assert(coroutine.resume(running));assert(finalized==0 and failed==0 and not context.busy,"Departed player was republished")
''',
    "exit_only_failed_or_loading_session": '''
p.attrs.ProfileStatus="Ready";callback(p,"exit");assert(kicks==0)
p.attrs.ProfileStatus="Error";callback(p,"exit");assert(kicks==1)
p.attrs.ProfileStatus="Loading";callback(p,"exit");assert(kicks==2 and calls==0)
''',
}
for name, assertions in cases.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + body + "\n" + assertions)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS ProfileRetry:", name)
