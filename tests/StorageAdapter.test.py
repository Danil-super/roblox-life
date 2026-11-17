#!/usr/bin/env python3
"""Run the real Storage module with deterministic Roblox API boundaries.

This proves adapter calls/metadata/failure behavior, not Roblox cloud access.
StoragePolicy is the actual Luau module, not a duplicate policy implementation.
"""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/server/Storage.luau").read_text()
body = source[source.index("local Storage = {}") :]
header = r'''
local Policy = require("../src/server/Domain/StoragePolicy")
local studio = SCENARIO ~= "production"
local cloud = SCENARIO ~= "preview"
local universeId = if SCENARIO == "blocked" then 999 else 123
local calls, writes, transforms = 0, 0, 0
local fail = SCENARIO == "transport"
local failLookup = SCENARIO == "lookup"
local loseReply = false
local saved = nil
local capturedIds, capturedMetadata = nil, nil
local current = {value=1}
local info = {GetMetadata=function() return {marker="preserved"} end}
local backend = {UpdateAsync=function(_self,key,transform)
    writes += 1
    if fail then error("Network failure") end
    local nextValue, ids, metadata = transform(current,info)
    capturedIds, capturedMetadata = ids, metadata
    saved = nextValue
    if nextValue~=nil then current=nextValue end
    if loseReply then loseReply=false;error("Reply lost after commit") end
    return nextValue
end}
local DataStoreService = {GetDataStore=function(_self,name,scope)
    calls += 1
    local expected = if studio then "NeighborhoodFixer_P0_StudioQA_v1" else "NeighborhoodFixer_P0_v1"
    assert(name==expected,"Wrong DataStore namespace")
    assert(scope==(if SCENARIO=="named" then "qa-roundtrip-1" else "global"),"Wrong DataStore scope")
    if failLookup then error("Initial DataStore lookup failed") end
    return backend
end}
local RunService = {IsStudio=function() return studio end}
local values = {
    StudioDataStoreTest={Value=cloud,IsA=function(_self,name) return name=="BoolValue" end},
    TestUniverseId={Value=123,IsA=function(_self,name) return name=="IntValue" end},
    TestPlaceId={Value=456,IsA=function(_self,name) return name=="IntValue" end},
}
local settings = {WaitForChild=function(_self,name) return values[name] end,
    FindFirstChild=function(_self,name)
        assert(name=="TestRunId")
        if SCENARIO=="named" or SCENARIO=="production" then
            return {Value="roundtrip-1",IsA=function(_,class) return class=="StringValue" end}
        end
        return nil
    end}
local ServerStorage = {WaitForChild=function(_self,name)
    assert(name=="DevelopmentSettings","Unexpected settings lookup")
    return settings
end}
local game = {GameId=universeId,PlaceId=456}
'''
scenarios = {
    "preview": r'''
assert(Storage.preview and calls==0,"Preview accessed cloud")
local adapter=Storage.create()
assert(adapter.update("player:123",function(old) assert(old==nil,"Fresh preview not empty");return {value=2} end),"Preview write")
local ok,value=adapter.update("player:123",function(old) assert(old.value==2,"Preview lost data");return old end)
assert(ok and value.value==2 and calls==0,"Preview used cloud or lost data")
''',
    "blocked": r'''
assert(Storage.blocked=="CloudTestWrongExperience" and not Storage.preview,"Wrong experience did not block")
local adapter=Storage.create()
local ok,reason=adapter.update("player:123",function() transforms+=1;return {} end)
assert(not ok and reason=="CloudTestWrongExperience" and calls==0 and transforms==0,"Blocked mode accessed data")
''',
    "cloud": r'''
assert(not Storage.preview and Storage.blocked==nil,"Cloud mode not ready")
local adapter=Storage.create()
local ok,value=adapter.update("player:123",function(old) assert(old.value==1,"Stored value not passed");return {value=2} end)
assert(ok and value.value==2 and saved.value==2 and calls==1 and writes==1,"Cloud adapter did not call UpdateAsync")
assert(capturedIds[1]==123 and #capturedIds==1,"Owner UserId not associated")
assert(capturedMetadata.marker=="preserved","Metadata lost")
local cancelled,result=adapter.update("player:123",function() return nil end)
assert(cancelled and result==nil and capturedIds==nil,"Cancelled transform unexpectedly rewrote metadata")
''',
    "transport": r'''
local adapter=Storage.create()
for _=1,2 do
    local ok=adapter.update("player:123",function() transforms+=1;return {} end)
    assert(not ok,"Transport error became success")
end
assert(calls==1 and writes==2 and transforms==0 and not Storage.preview,"Cloud failure fell back to preview")
''',
    "named": r'''
assert(not Storage.preview and Storage.scope=="qa-roundtrip-1","Named run picked the default scope")
assert(Storage.create().update("player:123",function()return {value=3} end),"Named run did not reach the scoped store")
assert(calls==1 and writes==1,"Unexpected named run lookup or write count")
''',
    "lookup": r'''
local adapter=Storage.create()
assert(calls==0,"Constructing a storage adapter performed an unprotected lookup")
local session=Store.new(adapter,123,"lookup-retry",function() return 100 end,60)
current=nil
assert(not session.load() and session.status()=="Uncertain" and session.read()==nil,"Lookup error exposed a profile")
assert(calls==1 and writes==0,"Failed lookup attempted a write")
failLookup=false
assert(session.retry() and session.read().wallet.dollars==0,"Exact retry did not recover a fresh cloud profile")
assert(session.close() and calls==2 and writes==2,"Successful lookup was not cached across writes")
''',
    "roundtrip": r'''
local Jobs=require("../src/server/Domain/Jobs")
local Painting=require("../src/server/Domain/Painting")
local PaintConfig=require("../src/shared/PaintConfig")
local Economy=require("../src/server/Domain/Economy")
local Furniture=require("../src/server/Domain/Furniture")
local function start(token)
    local session=Store.new(Storage.create(),123,token,function() return 100 end,120)
    assert(session.load(),"New session could not acquire the released profile")
    return session
end
local function makeWork(id)
    return Painting.new("first-job",id,0,PaintConfig)
end
current=nil
local first=start("before-wall")
assert(first.transact(function(p)return Jobs.accept(p,"first-job")end),"Accept was not committed")
local w=makeWork("first-work")
assert(Painting.step(w,"inspect",nil,0,true) and Painting.step(w,"prepare",nil,0,true),"Preparation failed")
assert(Painting.step(w,"choose","warm-white",0,true),"Required paint rejected")
for row=1,7 do
    local points={}
    for col=1,12 do table.insert(points,{u=(col-.5)/12,v=(row-.5)/8}) end
    assert(Painting.batch(w,w.seq+1,points,true,row*2,true),"Paint row rejected")
end
assert(w.count==84 and first.transact(function(p)return Jobs.checkpoint(p,w,14)end),"Partial wall did not checkpoint")
assert(first.close(),"First leave did not release the lease")
local second=start("after-wall")
local resumed=makeWork("second-work")
assert(second.read().wallet.dollars==0 and Painting.restore(resumed,second.read().jobs.active.checkpoint),"Replay lost checkpoint or added money")
assert(resumed.phase=="Ready" and resumed.count==84 and Painting.mask(resumed)==Painting.mask(w),"Resume replaced actual coverage")
loseReply=true
local submitCalls=0
local function submit(p)
    submitCalls+=1
    return Jobs.submit(p,resumed,111,true)
end
assert(not second.transact(submit) and second.read()==nil,"Unknown payout exposed a profile")
assert(second.retry() and submitCalls==1 and second.read().wallet.dollars==250,"Retry reran the payout mutation")
assert(second.transact(function(p)return Economy.purchase(p,"plant-buy","floor-plant-coral-v1","plant",112)~=nil end),"Purchase failed")
assert(second.transact(function(p)
    local placed=Furniture.place(p,"plant",{x=8,z=6,rotationY=45,mode="Free"},0)
    return placed
end),"Placement failed")
assert(second.close(),"Second leave did not release the lease")
local third=start("after-furniture")
local profile=third.read()
assert(profile.wallet.dollars==70 and profile.progression.paintingXP==50,"Reload lost balance or XP")
assert(profile.jobs.completedCount==1 and profile.onboarding.step=="DONE","Reload lost job or onboarding")
assert(profile.inventory.plant.catalogItemId=="floor-plant-coral-v1" and profile.inventory.plant.purchaseOperationId=="purchase:plant-buy","Reload lost owned variant or purchase proof")
local pose=profile.housing.placements.plant
assert(profile.housing.revision==1 and pose.x==8 and pose.y==0 and pose.z==6 and pose.rotationY==45 and pose.roomTemplateVersion==1,"Reload lost the room-relative pose")
assert(capturedIds[1]==123 and capturedMetadata.marker=="preserved","Reload lost cloud metadata")
assert(third.transact(function(p)
    return Jobs.submit(p,resumed,113,true) and Economy.purchase(p,"plant-buy","floor-plant-coral-v1","different-id",114)~=nil
end),"Original handover or purchase receipt did not survive rejoin")
local replayed=third.read()
assert(replayed.wallet.dollars==70 and replayed.jobs.completedCount==1 and replayed.inventory["different-id"]==nil,"Replay duplicated a payout or purchase")
assert(third.close(),"Final leave did not release the lease")
''',
    "production": r'''
assert(not Storage.preview and Storage.name=="NeighborhoodFixer_P0_v1" and Storage.scope=="global","Studio settings changed production")
local adapter=Storage.create()
assert(adapter.update("player:123",function()return {value=3} end),"Production adapter failed")
assert(calls==1 and writes==1,"Production did not use cloud adapter")
''',
}
(ROOT / ".tools").mkdir(exist_ok=True)
for name, assertions in scenarios.items():
    script = '--!strict\nlocal Store = require("../src/server/Domain/ProfileStore")\n' + header.replace("SCENARIO", '"' + name + '"')
    script += "\nlocal Storage=(function()\n" + body + "\nend)()\n" + assertions
    script += '\nprint("PASS StorageAdapter", "' + name + '")\n'
    with tempfile.NamedTemporaryFile("w", dir=ROOT / ".tools", suffix=".luau") as temporary:
        temporary.write(script)
        temporary.flush()
        subprocess.run(["luau", temporary.name], cwd=ROOT, timeout=30, check=True)
