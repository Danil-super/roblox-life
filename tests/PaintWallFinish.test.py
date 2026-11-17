#!/usr/bin/env python3
"""Execute actual authoritative world finish projection with bounded engine objects."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
header=r'''
local Painting=require("../src/server/Domain/Painting")
local Profile=require("../src/server/Domain/Profile")
local Config=require("../src/shared/PaintConfig")
local Contracts=require("../src/server/Domain/EconomyConfig")
local Finish=require("../src/shared/PaintFinish")
local pool={};local Instance={new=function(kind)
 local o={ClassName=kind};table.insert(pool,o)
 function o:IsA(k)return self.ClassName==k or(k=="BasePart"and self.ClassName=="Part")end
 function o:GetChildren()local r={};for _,p in pool do if p.Parent==self and not p.dead then table.insert(r,p)end end;return r end
 function o:FindFirstChild(name)for _,p in self:GetChildren()do if p.Name==name then return p end end end
 function o:Destroy()for _,p in self:GetChildren()do p:Destroy()end;self.Parent=nil;self.dead=true end
 return o
end}
local Color3={new=function(r,g,b)return r..":"..g..":"..b end,fromRGB=function(r,g,b)return(r/255)..":"..(g/255)..":"..(b/255)end}
local Vector2={new=function(x,y)return{X=x,Y=y}end}
local UDim2={fromScale=function(x,y)return{X={Scale=x},Y={Scale=y}}end}
local Enum={NormalId={Back=1},SurfaceGuiSizingMode={FixedSize=1}}
local function room()
 local m=Instance.new("Model");m.Parent={}
 for _,name in {"PaintableWall","PaintableWallB"}do local p=Instance.new("Part");p.Name,p.Parent=name,m end
 return m
end
local function decoded(wall,color)
 local gray=Color3.fromRGB(145,148,140);local bit=if wall.Color==color then "1"else "0"
 assert(wall.Color==color or wall.Color==gray,"Unknown base colour")
 local mask={};for i=1,96 do mask[i]=bit end
 local gui=wall:FindFirstChild("ConfirmedPaint")
 if gui then
  assert(gui.Face==Enum.NormalId.Back and gui.SizingMode==Enum.SurfaceGuiSizingMode.FixedSize and gui.ClipsDescendants and not gui.AlwaysOnTop and gui.ZOffset==0,"World layer geometry/settings drift")
  local count=0
  for _,f in gui:GetChildren()do
   assert(f:IsA("Frame"),"World overlay allocated physical/non-frame object")
   if f.Visible then
    count+=1;local x,y=math.floor(f.Position.X.Scale*12+.5),math.floor(f.Position.Y.Scale*8+.5)
    assert(f.Size.X.Scale==1/12 and f.Size.Y.Scale==1/8 and f.BorderSizePixel==0,"Cell geometry changed")
    mask[y*12+x+1]=if f.BackgroundColor3==color then "1"else "0"
   end
  end
  assert(count<=48 and #gui:GetChildren()<=48,"World overlay budget unbounded")
 end
 return table.concat(mask)
end
local m=room();local first=m:FindFirstChild("PaintableWall");local second=m:FindFirstChild("PaintableWallB")
local work=Painting.new("job","a",0,Config,{primary="mint",secondary="rose"})
local job={id="job",templateId="paint-duo-v1",status="Accepted"}
local View={}
'''
source=(ROOT/'src/server/PaintWallFinish.luau').read_text();source=source[source.index('local View = {}'):source.rindex('\nreturn ')]
checks=r'''
local view=View.attach(m);view.update(work,job,true)
local mint,rose=Color3.new(table.unpack(Config.palette.mint)),Color3.new(table.unpack(Config.palette.rose))
assert(decoded(first,mint)==string.rep("0",96)and not first:FindFirstChild("ConfirmedPaint"),"Inspect invented coverage")
work.phase="Ready";work.count=84;for i=1,84 do work.cells[i]=true end
local partial=string.rep("1",84)..string.rep("0",12)
view.update(work,job,true);assert(decoded(first,mint)==partial and decoded(second,rose)==string.rep("0",96),"Reviewed world wall hides holes or paints future wall")
local gui=first:FindFirstChild("ConfirmedPaint");local n=#pool
for _=1,30 do view.update(work,job,true)end
assert(#pool==n and first:FindFirstChild("ConfirmedPaint")==gui,"Sync rebuilt world finish")
assert(Painting.touchUp(work,{columns=12,rows=8,masks={partial}},"refine",1))
work.cells[85]=true;work.count=85
view.update(work,job,true)
assert(decoded(first,mint)==partial and first:FindFirstChild("ConfirmedPaint")==gui,"Touch-up leaked an unreviewed addition or removed saved paint")
assert(Painting.restore(work,{columns=12,rows=8,masks={partial}}))
assert(Painting.nextSurface(work,"b",1),"Next surface fixture failed")
view.update(work,job,true);assert(decoded(first,mint)==partial,"Next surface erased inspected first wall")
work.phase="Ready";work.count=96;for i=1,96 do work.cells[i]=true end
view.update(work,job,true);assert(decoded(second,rose)==string.rep("1",96)and not second:FindFirstChild("ConfirmedPaint"),"Perfect wall allocated holes")
job.status="Completed";job.receipt={operationId="job:job",kind="Reward",subjectId="job",dollarsDelta=550,xpDelta=120,at=1}
job.finish={columns=12,rows=8,masks={partial,string.rep("1",96)}}
work.cells={};work.count=0
view.update(work,job,true);assert(decoded(first,mint)==partial and decoded(second,rose)==string.rep("1",96),"Completed rescored mutable runtime")
local p=Profile.new(7);p.jobs.issuedSequence,p.jobs.settledSequence,p.jobs.completedCount=1,1,1;job.sequence=1;p.jobs.active=job;p.wallet.dollars=550
local loaded=Profile.decode(p,7);assert(loaded and loaded.jobs.active,"Persisted finish fixture failed")
view.update(nil,loaded.jobs.active,true);assert(decoded(first,mint)==partial,"Reload lost real holes")
view.update(nil,job,false);assert(not first:FindFirstChild("ConfirmedPaint")and decoded(first,mint)==string.rep("0",96),"Unavailable finish remained visible")
view.update(nil,job,true);assert(decoded(first,mint)==partial,"Availability lost saved finish")
local saved=job.finish;job.finish=nil;view.update(nil,job,true);assert(not first:FindFirstChild("ConfirmedPaint")and first.Color==mint,"Legacy receipt lost existing palette or invented mask")
job.finish=saved;job.receipt=nil;view.update(nil,job,true);assert(decoded(first,mint)==string.rep("0",96),"Unconfirmed Completed painted world")
job.status="Abandoned";view.update(work,job,true);assert(not first:FindFirstChild("ConfirmedPaint"),"Abandoned work retained finish")
job.status="Completed";job.receipt={operationId="job:job",kind="Reward",subjectId="job",dollarsDelta=550,xpDelta=120,at=1}
job.finish={columns=12,rows=8,masks={string.rep("10",48),string.rep("01",48)}};view.update(nil,job,true)
assert(decoded(first,mint)==job.finish.masks[1]and decoded(second,rose)==job.finish.masks[2],"Alternating masks changed coverage")
assert(#first:FindFirstChild("ConfirmedPaint"):GetChildren()==48,"Worst-case minority budget incorrect")
job.finish={columns=12,rows=8,masks={"bad"}};view.update(nil,job,true);assert(not first:FindFirstChild("ConfirmedPaint"),"Malformed mask displayed")
m:Destroy();view.update(nil,job,true);assert(not first:FindFirstChild("ConfirmedPaint"),"Destroyed room revived overlay")
assert(work.count==0 and saved.masks[1]==partial and p.wallet.dollars==550,"Renderer changed authoritative work/payment")
print("PASS PaintWallFinish: actual inspected/saved masks, two walls, reload/replay, minority/caching budget, legacy/invalid/unavailable/abandon/cleanup and no writes")
'''
client=(ROOT/'src/client/PaintController.luau').read_text()
a=client.index('\t\tlocal gui = Instance.new("SurfaceGui")')
b=client.index('\n\t\tsurface = gui',a)
checks+='local player={PlayerGui={}};local target=Instance.new("Part")\ndo\n'+client[a:b]+'\nassert(gui.Name=="LocalPaint" and gui.ZOffset>0 and gui.Face==Enum.NormalId.Back,"Local paint no longer layers above inspected world finish")\nend\n'
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(header+source+checks);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
