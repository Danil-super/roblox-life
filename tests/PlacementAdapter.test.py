#!/usr/bin/env python3
"""Run the real HomeCommand adapter with real furniture rules, isolated storage."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/server/HomeService.luau").read_text()
a = source.index("\tcommand.OnServerEvent:Connect")
b = source.index("\nend\nreturn Service", a)
body = source[a:b]
header = r'''
local Profile=require("../src/server/Domain/Profile")
local Furniture=require("../src/server/Domain/Furniture")
local Economy=require("../src/server/Domain/Economy")
local p=Profile.new(1)
p.wallet.dollars=250
assert(Economy.purchase(p,"buy-one","floor-plant-v1","plant",0))
local Players={}
local player={Parent=Players,Character={}}
local c={tokens=24,lastAt=0,saving=false,editorId="editor"}
local contexts={[player]=c}
local function context()return c end
local now=0
local os={clock=function() now+=1;return now end,time=function()return 0 end}
local home=true
local function atHome()return home end
local function atShop()return false end
local writes,reconciles=0,0
local available=true
local profiles={read=function() return if available then p else nil end,change=function(_,mutate,guard)
    assert(guard());local candidate=Profile.copy(p)
    if not mutate(candidate)then return false,"Rejected"end
    writes+=1;p=candidate;return true,nil
end}
local function reconcile()reconciles+=1 end
local replies={}
local function send(_,reason,ack,_,placementAck)
    table.insert(replies,{error=reason,ack=ack,placementAck=placementAck})
end
local handler
local command={OnServerEvent={Connect=function(_,fn)handler=fn end}}
local preview={FireClient=function()end}
local function packet(id,rev,x)
    return {action="place",requestId=id,editorId="editor",itemId="plant",revision=rev,
        pose={x=x,z=3,rotationY=0,mode="Grid"}}
end
'''
cases={
    "duplicate_no_write_and_stale_replay": r'''
local first=packet("place-one",0,5)
handler(player,first)
assert(writes==1 and reconciles==1 and p.housing.revision==1)
assert(replies[#replies].placementAck=="place-one" and not replies[#replies].error)
for _=1,5 do handler(player,first)end
assert(writes==1 and reconciles==1,"Retry wrote/recreated confirmed furniture")
handler(player,packet("place-two",1,8))
assert(writes==2 and p.housing.placements.plant.x==8 and p.housing.revision==2)
handler(player,first)
assert(writes==2 and p.housing.placements.plant.x==8,"Late old operation moved furniture backwards")
assert(replies[#replies].placementAck=="place-one" and replies[#replies].error=="StaleRevision")
assert(p.wallet.dollars==70)
''',
    "malformed_foreign_and_blocked_requests": r'''
local d=packet("place-one",0,5);d.requestId=nil;handler(player,d)
d=packet("place-one",0,5);d.pose.x=0/0;handler(player,d)
assert(replies[#replies].placementAck=="place-one" and replies[#replies].error=="InvalidPose")
d=packet("place-two",0,0);handler(player,d)
assert(replies[#replies].placementAck=="place-two" and replies[#replies].error=="Blocked")
d=packet("place-three",0,5);d.editorId="foreign";handler(player,d)
assert(replies[#replies].error=="StaleRevision")
assert(writes==0 and next(p.housing.placements)==nil and p.wallet.dollars==70)
''',
    "busy_unknown_and_location_refusals": r'''
c.saving=true;handler(player,packet("place-one",0,5));assert(#replies==0)
c.saving=false;available=false;handler(player,packet("place-one",0,5))
assert(replies[#replies].placementAck=="place-one" and replies[#replies].error=="Unavailable")
available=true;home=false;handler(player,packet("place-one",0,5))
assert(replies[#replies].placementAck=="place-one" and replies[#replies].error=="GoHome")
assert(writes==0)
''',
}
for name,checks in cases.items():
    with tempfile.NamedTemporaryFile("w",suffix=".luau",dir=ROOT/".tools")as f:
        f.write(header+body+checks);f.flush()
        subprocess.run([str(ROOT/".tools/bin/luau"),f.name],cwd=ROOT,check=True)
    print("PASS PlacementAdapter:",name)
