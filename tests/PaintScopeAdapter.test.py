#!/usr/bin/env python3
"""Exercise actual server identity, wall routing and next-surface command branches."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'src/server/JobService.luau').read_text()
a = source.index('\t\tif\n\t\t\twork == nil')
b = source.index('\n\t\tif action == "cancel"', a)
identity = source[a:b]
a = source.index('\t\tlocal valid = eligible(player, ctx)')
b = source.index('\n\t\telseif action == "tool"', a)
routing = source[a:b] + '\nend\n'
header = '''
local Painting=require("../src/server/Domain/Painting")
local Config=require("../src/shared/PaintConfig")
local work=Painting.new("job","first",0,Config,{primary="mint",secondary="rose"})
local job={status="Accepted"}
local player,ctx={},{}
local near,ensures,now=true,0,20
local function eligible()return near end
local function ensure()ensures+=1 end
local HttpService={GenerateGUID=function()return "second" end}
local reasons={}
local function send(_,_,reason)table.insert(reasons,reason)end
local function request(action,data)
'''
checks = '''
request("nextSurface",{jobId="foreign",workId="first"})
request("nextSurface",{jobId="job",workId="old"})
assert(ensures==0 and work.workId=="first" and #reasons==2,"Stale identity advanced wall")
request("nextSurface",{jobId="job",workId="first"})
assert(ensures==0,"Unreviewed wall advanced")
work.phase="Ready";work.count=96
for i=1,96 do work.cells[i]=true end
near=false
request("nextSurface",{jobId="job",workId="first"})
assert(ensures==0,"Distant actor advanced wall")
near=true
request("nextSurface",{jobId="job",workId="first"})
assert(ensures==1 and work.workId=="second" and work.count==0 and work.seq==0)
request("nextSurface",{jobId="job",workId="first"})
request("nextSurface",{jobId="job",workId="second"})
assert(ensures==1 and Painting.surface(work)==2,"Replay skipped or recreated wall")
assert(Painting.step(work,"choose","rose",21,true));now=23
request("stroke",{jobId="job",workId="first",wallId="wall-a",sequence=1,points={{u=.5,v=.5}},starts=true})
request("stroke",{jobId="job",workId="second",wallId="wall-a",sequence=1,points={{u=.5,v=.5}},starts=true})
assert(work.count==0 and work.seq==0,"Old nonce/wall painted second surface")
request("stroke",{jobId="job",workId="second",wallId="wall-b",sequence=1,points={{u=.5,v=.5}},starts=true})
assert(work.count>0 and work.seq==1,"Assigned second wall rejected")
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT / '.tools') as f:
    f.write(header + identity + routing + '\nend\n' + checks)
    f.flush()
    subprocess.run([str(ROOT / '.tools/bin/luau'), f.name], cwd=ROOT, check=True)
print('PASS PaintScopeAdapter: actual stale/phase/distance guards, next dedup and per-wall stroke identity')

# The real client resolves the server-assigned wall and flushes that wall's identifier.
client=(ROOT/'src/client/JobController.luau').read_text()
a=client.index('\tlocal function currentWall()');b=client.index('\n\tlocal function activate()',a)
wall=client[a:b]
painter=(ROOT/'src/client/PaintController.luau').read_text()
a=painter.index('\tlocal function flush()');b=painter.index('\n\tlocal function render()',a)
flush=painter[a:b]
header='''
local Types={}
local Config=require("../src/shared/PaintConfig")
local primary={IsA=function()return true end}
local secondary={IsA=function()return true end}
local room={FindFirstChild=function(_,name)return if name=="PaintableWallB" then secondary elseif name=="PaintableWall" then primary else nil end}
local folder={FindFirstChild=function(_,name)return if name=="own"then room else nil end}
local workspace={FindFirstChild=function()return folder end}
local state={location="own",wallName="PaintableWallB"}
local snapshot={wallId="wall-b"}
local active,inflight,sequence,sentAt,inspectPending=true,nil,0,0,false
local queue={{points={{u=.5,v=.5}},starts=true}}
local current=nil
local packets={}
local function send(action,data)table.insert(packets,{action=action,data=data})end
'''
checks='''
assert(currentWall()==secondary,"Client still aims at first wall")
state.wallName=nil;assert(currentWall()==primary,"Legacy snapshot lost wall")
state.location="foreign";assert(currentWall()==nil,"Client used another room")
flush();assert(#packets==1 and packets[1].data.wallId=="wall-b" and packets[1].data.sequence==1,"Second wall emitted first wall ID")
flush();assert(#packets==1,"Inflight packet repeated")
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT/'.tools')as f:
    f.write(header+wall+'\n'+flush+'\n'+checks);f.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
print('PASS PaintScopeAdapter: actual client wall selection, packet wall identity and inflight guard')

# Existing ensure logic must reset both surfaces on character replacement, not just the active grid.
a=source.index('\t\tlocal old = ctx.work')
b=source.index('\n\tend\n\tlocal function phaseOf',a)
recovery=source[a:b]
header='''
local Painting=require("../src/server/Domain/Painting")
local Config=require("../src/shared/PaintConfig")
local oldCharacter,newCharacter={},{}
local ctx={work=Painting.new("job","first",0,Config,{primary="mint",secondary="rose"}),character=oldCharacter}
ctx.work.phase="Ready";ctx.work.count=96
for i=1,96 do ctx.work.cells[i]=true end
assert(Painting.nextSurface(ctx.work,"second",1))
assert(Painting.step(ctx.work,"choose","rose",2,true))
assert(Painting.batch(ctx.work,1,{{u=.5,v=.5}},true,3,true))
local player={Character=newCharacter}
local job={id="job"}
local contract={colorId="mint",secondaryColorId="rose"}
local cloth={Transparency=.35,IsA=function()return true end}
local room={model={FindFirstChild=function()return cloth end}}
local walls={{Color="mint",Size={X=16,Y=8}},{Color="partial rose",Size={X=8,Y=8}}}
local HttpService={GenerateGUID=function()return "respawn"end}
local os={clock=function()return 100 end}
local Color3={fromRGB=function()return "grey"end}
local function ensure()
'''
checks='''
ensure()
assert(ctx.character==newCharacter and ctx.wall==walls[1],"Respawn retained second active surface")
assert(ctx.work.workId=="respawn" and ctx.work.phase=="Inspect" and ctx.work.count==0 and #ctx.work.completedMasks==0,"Respawn inherited first wall or partial paint")
assert(walls[1].Color=="grey" and walls[2].Color=="grey" and cloth.Transparency==1,"Respawn retained misleading accepted wall")
assert(ctx.work.sizes[1].width==16 and ctx.work.sizes[2].width==8,"Recovery lost actual surface geometry")
local work=ctx.work;ensure();assert(ctx.work==work,"Sync reset live work")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
    f.write(header+recovery+'\nend\n'+checks);f.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
print('PASS PaintScopeAdapter: actual ensure resets both walls, mask, work nonce and preparation on respawn')

# A player may finish A from its far end. Do not offer an unusable palette at B.
a=client.index('\t\tif s.phase == "ChooseMaterial" and old and old.phase == "SurfaceReady" then')
b=client.index('\n\t\tif s.phase == "Painting"',a)
transition=client[a:b]
header='''
local jobs,homePanel={Visible=false},{Visible=true}
local mapVisible=false
local map={show=function()mapVisible=true end}
local function hidePanels()jobs.Visible=false;mapVisible=false end
local function advance(s,old)
'''
checks='''
advance({phase="ChooseMaterial",near=false},{phase="SurfaceReady"})
assert(mapVisible and not jobs.Visible and not homePanel.Visible,"Distant second wall opened unusable palette")
advance({phase="ChooseMaterial",near=true},{phase="SurfaceReady"})
assert(not mapVisible and jobs.Visible,"Nearby second wall did not open palette")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
    f.write(header+transition+'\nend\n'+checks);f.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
print('PASS PaintScopeAdapter: actual second-wall transition routes distant actors and opens nearby palette')
