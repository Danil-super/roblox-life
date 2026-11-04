#!/usr/bin/env python3
"""Execute server talk cooldown and exact work identity checks."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'src/server/JobService.luau').read_text()
a=source.index('\ttalk = function(');b=source.index('\n\tlocal function changed',a)
body=source[a:b]
header='''
local Dialogue=require("../src/shared/ClientDialogue")
local EconomyConfig=require("../src/server/Domain/EconomyConfig")
local now=10
local os={clock=function()return now end}
local data={jobs={active={templateId="paint-tutorial-v1"}}}
local profiles={read=function()return data end}
local player={}
local ctx={lastTalk=-math.huge,saving=false}
local permitted=true
local function canTalk(_,_,_,available)return permitted and available end
local function phaseOf()return "Inspect"end
local sent={}
local function send(_,_,reason,conversation)table.insert(sent,{reason=reason,conversation=conversation})end
local talk
'''
checks='''
talk(player,ctx);assert(#sent==1 and sent[1].conversation.action=="inspect","Valid talk did not use inspection")
for i=1,10 do talk(player,ctx)end
assert(#sent==1,"Repeated talk bypassed cooldown")
now=10.99;talk(player,ctx);assert(#sent==1,"Cooldown lower boundary ignored")
now=11;talk(player,ctx);assert(#sent==2,"Cooldown exact boundary rejected")
now=12;ctx.saving=true;talk(player,ctx);assert(sent[3].conversation==nil,"Saving profile opened dialogue")
ctx.saving=false;now=13;permitted=false;talk(player,ctx);assert(sent[4].conversation==nil,"Denied geometry opened dialogue")
permitted=true;data=nil;now=14;talk(player,ctx);assert(sent[5].conversation==nil,"Missing profile opened dialogue")
'''
a=source.index('\t\tif action == "talk" then');b=source.index('\n\t\tif action == "submit"',a)
boundary=source[a:b]
pa=source.index('\t\t\tscene.prompt.Triggered:Connect(');pb=source.index('\n\t\tend',pa)
prompt=source[pa:pb]
prompt_checks='''
local triggered,ensures,talks=nil,0,0
local scene={prompt={Triggered={Connect=function(_,fn)triggered=fn end}}}
local player,foreign,ctx={},{},{}
local function ensure()ensures+=1 end
local function talk()talks+=1 end
'''+prompt+'''
triggered(foreign);assert(ensures==0 and talks==0,"Foreign prompt actor affected owner context")
triggered(player);assert(ensures==1 and talks==1,"Owner prompt not routed through validated talk")
'''
identity=''' 
local count=0
local function talk()count+=1 end
local ctx={}
local player={}
local action="talk"
local job={id="current"}
local work={workId="work"}
local function request(data)
'''+boundary+'''
end
request({jobId="foreign",workId="work"});request({jobId="current",workId="old"})
assert(count==0,"Stale work opened conversation")
request({jobId="current",workId="work"});assert(count==1)
work=nil;request({jobId="current",workId=""});assert(count==2,"Completed job without work cannot say thanks")
job=nil;request({jobId="current",workId=""});assert(count==2,"Missing job opened conversation")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
    f.write(header+body+checks+'\ndo\n'+identity+'\nend\ndo\n'+prompt_checks+'\nend\n');f.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
print('PASS ClientTalk: server cooldown, saving/missing profile, geometry denial and exact job/work identity')
