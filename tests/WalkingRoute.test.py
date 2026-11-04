#!/usr/bin/env python3
"""Run the real async walking adapter against deterministic engine boundaries."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'src/client/WalkingRoute.luau').read_text()
body = source[source.index('local Route = {}'):source.index('\nreturn Route')]
header = r'''
local Progress=require("../src/shared/PathProgress")
local Enum={PathStatus={Success=1},PathWaypointAction={Walk=1}}
local Vector3={}
local mt={}
mt.__index=function(v,k)if k=="Magnitude"then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end end
mt.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
Vector3.new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},mt)end
local queue={}
local task={spawn=function(f)table.insert(queue,coroutine.create(f))end}
local function tick()
 local co=table.remove(queue,1);assert(co,"No queued computation")
 local ok,err=coroutine.resume(co);assert(ok,err)
 if coroutine.status(co)~="dead"then table.insert(queue,co)end
end
local paths,configs={},{}
local fail,oversized,jump=false,false,false
local function room(id)
 local modifier={Label="RoomOwner_"..id}
 return {GetAttribute=function()return id end,FindFirstChild=function()return{FindFirstChildOfClass=function()return modifier end}end}
end
local workspace={FindFirstChild=function()return{GetChildren=function()return{room(7),room(9)}end}end}
local Service={CreatePath=function(_,config)
 table.insert(configs,config)
 local event={}
 function event:Connect(callback)
  self.callback=callback;local connection={connected=true}
  function connection:Disconnect()self.connected=false end
  self.connection=connection;return connection
 end
 function event:fire(i)if self.connection.connected then self.callback(i)end end
 local p={Status=1,Blocked=event,destroyed=0}
 function p:ComputeAsync(a,b)
  coroutine.yield()
  if fail then error("NoPath test")end
  self.raw={
   {Position=a,Action=1},
   {Position=Vector3.new(a.X,0,b.Z),Action=1},
   {Position=b,Action=if jump then 2 else 1}}
  if oversized then for i=1,513 do self.raw[i]={Position=a,Action=1}end end
 end
 function p:GetWaypoints()return self.raw end
 function p:Destroy()self.destroyed+=1 end
 table.insert(paths,p);return p
end}
'''
checks = r'''
local start,goal=Vector3.new(0,0,0),Vector3.new(10,0,10)
local route=Route.start(7)
local p,d,status=route.update(start,goal,"a",10)
assert(p==nil and status=="Finding" and #queue==1,"Compute did not stay asynchronous")
for i=1,100 do route.update(start,goal,"a",10)end
assert(#queue==1 and #paths==0,"Parallel compute was queued")
tick();assert(#paths==1,"Compute did not start")
assert(configs[1].Costs.RoomOwner_7==1 and configs[1].Costs.RoomOwner_9==math.huge,"Private rooms not excluded")
assert(configs[1].AgentCanJump==false and configs[1].AgentRadius==1,"Wrong walking agent")
route.update(start,goal,"b",11);tick()
assert(paths[1].destroyed==1 and #route.points()==0,"Old goal result was adopted")
route.update(start,goal,"b",11);tick();tick()
p,d,status=route.update(start,goal,"b",11)
assert(status=="Ready" and p.Z==10 and d==20,"Path/length not adopted")
local points,index=route.points();assert(table.isfrozen(points) and index==2,"Exposed mutable path")
paths[2].Blocked:fire(1);assert(#route.points()==3,"Block behind player discarded path")
paths[2].Blocked:fire(2);assert(#route.points()==0 and paths[2].destroyed==1,"Forward block did not invalidate")
route.update(start,goal,"b",11.1);assert(#queue==0,"Recompute cooldown ignored")
route.update(start,goal,"b",12);tick();tick()
route.update(Vector3.new(8,0,0),goal,"b",13)
assert(paths[3].destroyed==1,"Off-route path retained")
-- Cancellation while yielding cannot revive an abandoned route.
tick();route.clear();tick()
assert(#route.points()==0 and paths[4].destroyed==1,"Cleared route revived")
route.update(start,goal,"c",20);tick();tick();route.destroy();route.destroy()
assert(paths[5].destroyed==1,"Destroy not idempotent")
p,d,status=route.update(start,goal,"c",21);assert(status=="Unavailable" and #queue==0,"Destroyed guide revived")
-- A real failure backs off; changed goal still has no parallel task.
local other=Route.start(9);fail=true
other.update(start,goal,"x",os.clock());tick();tick()
p,d,status=other.update(start,goal,"x",os.clock())
assert(status=="Unavailable" and #queue==0 and paths[6].destroyed==1,"Failure not bounded/backed off")
fail=false;other.update(start,goal,"x",os.clock()+3);tick();tick()
assert(#other.points()==3,"Failure did not recover")
other.clear();oversized=true;other.update(start,goal,"y",os.clock()+10);tick();tick()
assert(#other.points()==0 and paths[8].destroyed==1,"Oversized route accepted")
oversized=false;jump=true;other.update(start,goal,"y",os.clock()+20);tick();tick()
assert(#other.points()==0 and paths[9].destroyed==1,"Jump path accepted by walking guide")
jump=false
for _,bad in{Vector3.new(0/0,0,0),Vector3.new(math.huge,0,0),Vector3.new(3000,0,0)}do
 p,d,status=other.update(start,bad,"bad",os.clock()+30);assert(status=="Unavailable" and #queue==0,"Invalid goal computed")
end
other.update(start,goal,"end",os.clock()+1000001);tick();other.destroy();tick()
assert(paths[10].destroyed==1,"Late result survived destruction or long uptime rejected")
local refreshed=Route.start(7)
local stamp=os.clock()+1000010
refreshed.update(start,goal,"timer",stamp);tick();tick()
local prior=paths[#paths]
local lateBlocked=prior.Blocked.callback
p,d,status=refreshed.update(start,goal,"timer",stamp+2.9)
assert(#queue==0 and status=="Ready","Refresh too frequent")
p,d,status=refreshed.update(start,goal,"timer",stamp+3)
assert(#queue==1 and status=="Ready" and #refreshed.points()>0,"Refresh hid valid guidance")
tick();tick()
assert(prior.destroyed==1 and #refreshed.points()==3,"Refresh leaked/reused stale path")
lateBlocked(100);assert(#refreshed.points()==3,"Queued old Blocked invalidated replacement")
refreshed.destroy()
print("WalkingRoute: async/cancellation/throttle/recovery/costs/bounds/cleanup passed")
'''
with tempfile.NamedTemporaryFile('w', suffix='.luau', dir=ROOT / '.tools') as handle:
    handle.write(header + body + '\n' + checks)
    handle.flush()
    subprocess.run([str(ROOT / '.tools/bin/luau'), handle.name], cwd=ROOT, check=True)
