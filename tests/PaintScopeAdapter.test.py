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
work=Painting.new("job","checked",0,Config,{primary="mint",secondary="rose"})
job.checkpoint={columns=12,rows=8,masks={string.rep("1",84)..string.rep("0",12)}}
assert(Painting.restore(work,job.checkpoint))
near=false;request("touchUp",{jobId="job",workId="checked"})
assert(work.phase=="Ready","Distant actor reopened the wall")
near=true;request("touchUp",{jobId="foreign",workId="checked"})
assert(work.phase=="Ready","Different job reopened the wall")
request("touchUp",{jobId="job",workId="checked"})
assert(work.phase=="Painting" and work.workId=="second" and work.count==84,"Touch-up lost checked progress")
request("touchUp",{jobId="job",workId="checked"})
request("stroke",{jobId="job",workId="checked",wallId="wall-a",sequence=1,points={{u=.5,v=.5}},starts=true})
assert(work.seq==0 and work.count==84,"Old work accepted commands after touch-up")
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT / '.tools') as f:
    f.write(header + identity + routing + '\nend\n' + checks)
    f.flush()
    subprocess.run([str(ROOT / '.tools/bin/luau'), f.name], cwd=ROOT, check=True)
print('PASS PaintScopeAdapter: actual stale/phase/distance guards, next dedup and per-wall stroke identity')

# Execute the review command's validation, state transition and acknowledgement.
a = source.index('\t\tif action == "review" then', source.index('\t\tif action == "cancel"'))
b = source.index('\n\tend)\nend\nreturn Service', a)
review_handler = source[a:b]
a = source.index('\tlocal function commitGuard(')
b = source.index('\n\tlocal function ensure(', a)
guard = source[a:b]
header = '''
local Painting=require("../src/server/Domain/Painting")
local Profile=require("../src/server/Domain/Profile")
local Jobs=require("../src/server/Domain/Jobs")
local Config=require("../src/shared/PaintConfig")
local work=Painting.new("job","wall-work",0,Config,{primary="mint",secondary="rose"})
work.phase="Painting"
local p=Profile.new(1);p.progression.paintingXP=210
assert(Jobs.accept(p,"job","paint-duo-v1"))
local job=p.jobs.active
local actor={}
local player,ctx={Character=actor},{work=work}
local contexts={[player]=ctx}
local near,now=true,30
local denyCommit=false
local changes=0
local function eligible()return near end
local function ensure()
    if job.checkpoint and work.phase=="Painting" then Painting.restore(work,job.checkpoint) end
end
local profiles={change=function(_,mutate,guard)
    assert(ctx.reviewing and ctx.saving)
    changes+=1
    if denyCommit then player.Character={};assert(not guard());player.Character=actor;return false end
    assert(guard())
    return mutate(p)
end}
local replies={}
local function send(_,_,reason,_,_,reviewAck)
    table.insert(replies,{reason=reason,id=reviewAck,phase=work.phase})
end
'''
checks = '''
local function review(id,workId)
    request({jobId="job",workId=workId or "wall-work",requestId=id})
end
review("old","old-work")
assert(replies[1].reason=="Stale" and replies[1].id==nil and work.phase=="Painting")
review("");review(123);review(string.rep("a",81))
assert(#replies==1,"Malformed review was processed")
review("coverage")
assert(replies[2].id=="coverage" and replies[2].reason=="Coverage")
work.count=84
for i=1,84 do work.cells[i]=true end
near=false;review("distance")
assert(replies[3].id=="distance" and replies[3].reason=="TooFar" and work.phase=="Painting")
near=true;denyCommit=true;review("interrupted")
assert(replies[4].id=="interrupted" and replies[4].reason=="ReviewSave" and work.phase=="Painting" and not job.checkpoint)
denyCommit=false;review("accepted")
assert(replies[5].id=="accepted" and replies[5].reason==nil and work.phase=="Ready" and job.checkpoint)
near=false;review("retry-after-success")
assert(replies[6].id=="retry-after-success" and replies[6].reason==nil and work.phase=="Ready")
assert(Painting.surface(work)==1 and work.count==84 and work.seq==0 and changes==2 and p.wallet.dollars==0 and not ctx.reviewing,"Review replay changed the work")
near=true
assert(Painting.touchUp(work,job.checkpoint,"refine",30))
review("stale-during-touch-up")
assert(replies[7].reason=="Stale" and work.phase=="Painting")
review("unchanged","refine")
assert(replies[8].id=="unchanged" and replies[8].reason==nil and work.phase=="Ready" and work.count==84)
assert(changes==2 and work.touchUpBase==nil,"Rechecking unchanged touch-up wrote progress")
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT / '.tools') as f:
    f.write(header + guard + '\nlocal function request(data)\n local action="review"\n'
            + identity + review_handler + '\nend\n' + checks)
    f.flush()
    subprocess.run([str(ROOT / '.tools/bin/luau'), f.name], cwd=ROOT, check=True)
print('PASS PaintScopeAdapter: actual review validation, correlated refusals and idempotent replay')

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
local active,inflight,sequence,sentAt,inspectPending,syncSent=true,nil,0,0,false,false
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

# Respawning restores saved walls and discards unreviewed paint.
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
local contract={colorId="mint",secondaryColorId="rose",minXP=210}
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
assert(ctx.work.preparationRequired==3 and Painting.preparedCount(ctx.work)==0,"Advanced respawn skipped clearing")
assert(ctx.character==newCharacter and ctx.wall==walls[1],"Respawn retained second active surface")
assert(ctx.work.workId=="respawn" and ctx.work.phase=="Inspect" and ctx.work.count==0 and #ctx.work.completedMasks==0,"Respawn inherited first wall or partial paint")
assert(walls[1].Color=="grey" and walls[2].Color=="grey" and cloth.Transparency==1,"Respawn retained misleading accepted wall")
assert(ctx.work.sizes[1].width==16 and ctx.work.sizes[2].width==8,"Recovery lost actual surface geometry")
local work=ctx.work;ensure();assert(ctx.work==work,"Sync reset live work")
local checked=string.rep("1",84)..string.rep("0",12)
job.checkpoint={columns=12,rows=8,masks={checked}}
player.Character={}
ensure()
assert(ctx.work.phase=="Ready" and ctx.work.count==84 and Painting.mask(ctx.work)==checked and cloth.Transparency==.35)
assert(Painting.preparedCount(ctx.work)==3 and ctx.wall==walls[1],"Saved wall restored at the wrong step")
assert(Painting.touchUp(ctx.work,job.checkpoint,"refine",101))
ctx.work.cells[85]=true;ctx.work.count=85
ensure();ensure()
assert(ctx.work.phase=="Painting" and ctx.work.count==85 and ctx.work.workId=="refine","Ordinary sync closed a touch-up")
job.checkpoint.masks[1]=Painting.mask(ctx.work)
ensure()
assert(ctx.work.phase=="Ready" and ctx.work.touchUpBase==nil and ctx.work.count==85,"New confirmed mask was ignored")
assert(Painting.nextSurface(ctx.work,"second-after-rejoin",102))
assert(Painting.step(ctx.work,"choose","rose",103,true))
local second=ctx.work
ensure()
assert(ctx.work==second and second.phase=="Painting" and second.count==0 and ctx.wall==walls[2],"Sync rewound unchecked wall")
job.checkpoint.masks[2]=string.rep("1",96)
ensure()
assert(ctx.work==second and Painting.allReady(second) and second.count==96 and second.config.colorId=="rose","Confirmed delayed checkpoint did not reconcile onto the active wall")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
    f.write(header+recovery+'\nend\n'+checks);f.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
print('PASS PaintScopeAdapter: actual ensure resets unchecked work, restores saved walls and reconciles a delayed confirmation')

# Opening a new wall or a touch-up follows the matching server state.
a=client.index('\t\tif s.phase == "ChooseMaterial" and old and old.phase == "SurfaceReady" then')
b=client.index('\n\t\tlocal result = s.result',a)
transition=client[a:b]
header='''
local jobs,homePanel={Visible=false},{Visible=true}
local mapVisible=false
local map={show=function()mapVisible=true end}
local function hidePanels()jobs.Visible=false;mapVisible=false end
local wall={}
local function currentWall()return wall end
local opened=0
local painter={enter=function(w,s)assert(w==wall);opened+=1 end}
local function advance(s,old)
'''
checks='''
advance({phase="ChooseMaterial",near=false},{phase="SurfaceReady"})
assert(mapVisible and not jobs.Visible and not homePanel.Visible,"Distant second wall opened unusable palette")
advance({phase="ChooseMaterial",near=true},{phase="SurfaceReady"})
assert(not mapVisible and jobs.Visible,"Nearby second wall did not open palette")
local ready={phase="Ready",canTouchUp=true,workId="previous"}
local editing={phase="Painting",touchingUp=true,near=true,workId="latest"}
advance(editing,ready)
assert(opened==1 and not jobs.Visible,"Confirmed touch-up did not reopen roller")
advance(editing,ready)
assert(opened==1,"Closed Jobs panel opened a late touch-up")
jobs.Visible=true;editing.workId="previous"
advance(editing,ready)
assert(opened==1 and jobs.Visible,"Unchanged working session reopened roller")
editing.workId="latest";editing.near=false
advance(editing,ready)
assert(opened==1,"Distant player entered touch-up camera")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
    f.write(header+transition+'\nend\n'+checks);f.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
print('PASS PaintScopeAdapter: actual second-wall routing and confirmed touch-up camera transition')

a = client.index('\tlocal function stepHint(')
b = client.index('\n\tlocal function render()', a)
hint = client[a:b]
header = '''
local Strings=require("../src/shared/Strings")
local language="en"
local function t(key)return Strings.text(language,key)end
local nearWall,lastError,errorUntil=false,nil,0
local state={checkpointSaved=true}
local function preparationPending()return false end
'''
checks = '''
for _,locale in {"en","ru"} do
    language=locale;nearWall=false;state.checkpointSaved=true
    assert(stepHint("SurfaceReady")==t("jobCheckpointRoute"))
    assert(stepHint("Ready")==t("jobCheckpointRoute"))
    nearWall=true
    assert(stepHint("SurfaceReady")==t("nextSurfaceHint"))
    assert(stepHint("Ready")==t("handoverClientHint"))
    state.canTouchUp,state.near=true,true
    assert(stepHint("Ready")==t("handoverTouchUpHint"))
    assert(stepHint("SurfaceReady")==t("nextSurfaceTouchUpHint"))
    state.canTouchUp,state.near=false,false
    nearWall=false;state.checkpointSaved=false
    assert(stepHint("Inspect")==t("jobRouteHint"))
end
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT / '.tools') as f:
    f.write(header + hint + '\n' + checks);f.flush()
    subprocess.run([str(ROOT / '.tools/bin/luau'), f.name], cwd=ROOT, check=True)
print('PASS PaintScopeAdapter: saved-wall routing and stage guidance in EN/RU')

a = client.index('\tlocal action = button(jobBody, "Action"')
b = client.index('\n\tlocal cancel =', a)
widgets = client[a:b]
a = client.index('\t\ttouchUp.Visible = s ~= nil')
b = client.index('\n\t\tfor index, b in swatches', a)
layout = client[a:b]
a = client.index('\ttouchUp.Activated:Connect(')
b = client.index('\n\tresultContinue.Activated', a)
click = client[a:b]
header = '''
local Strings=require("../src/shared/Strings")
local language="en"
local function t(key)return Strings.text(language,key)end
local function pair(a,b)return {Scale=a,Offset=b}end
local UDim2={new=function(xs,xo,ys,yo)return {X=pair(xs,xo),Y=pair(ys,yo)}end}
local Color3={fromRGB=function()return {}end}
local buttons={}
local function button(_,name,y)
    local b={Position=UDim2.new(0,16,0,y),Size=UDim2.new(1,-32,0,44)}
    b.Activated={Connect=function(_,fn)b.click=fn end}
    buttons[name]=b
    return b
end
local jobBody,cancel,jobs={Visible=true},{Active=true},{Visible=true}
local requests={}
local function send(command)table.insert(requests,command)end
'''
checks = '''
local function pixel(size,width)return size.Scale*width+size.Offset end
for _,locale in {"en","ru"} do
    language=locale
    render({canTouchUp=true,near=true})
    assert(touchUp.Visible and touchUp.Active and touchUp.Text==t("jobTouchUp"))
    for _,width in {256,350,556} do
        local mainWidth=pixel(action.Size.X,width)
        assert(pixel(touchUp.Size.X,width)>=44 and mainWidth>=44 and touchUp.Size.Y.Offset==44)
        assert(pixel(action.Position.X,width)+mainWidth<pixel(touchUp.Position.X,width))
    end
end
jobBody.Visible=false;touchUp.click();assert(#requests==0,"Hidden Jobs body submitted touch-up")
jobBody.Visible=true
render({canTouchUp=true,near=false});touchUp.click()
cancel.Active=false;render({canTouchUp=true,near=true});touchUp.click()
assert(#requests==0,"Distant or preoccupied player emitted touch-up")
cancel.Active=true;render({canTouchUp=true,near=true});touchUp.click()
assert(#requests==1 and requests[1]=="touchUp")
render({canTouchUp=false,near=true});touchUp.click()
assert(not touchUp.Visible and not touchUp.Active and #requests==1 and action.Size.X.Scale==1)
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT / '.tools') as f:
    f.write(header + widgets + '\nlocal function render(s)\n' + layout + '\nend\n' + click + checks)
    f.flush()
    subprocess.run([str(ROOT / '.tools/bin/luau'), f.name], cwd=ROOT, check=True)
print('PASS PaintScopeAdapter: responsive optional Jobs action, labels and guarded input')
