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
    return nextValue
end}
local DataStoreService = {GetDataStore=function(_self,name)
    calls += 1
    local expected = if studio then "NeighborhoodFixer_P0_StudioQA_v1" else "NeighborhoodFixer_P0_v1"
    assert(name==expected,"Wrong DataStore namespace")
    return backend
end}
local RunService = {IsStudio=function() return studio end}
local values = {
    StudioDataStoreTest={Value=cloud,IsA=function(_self,name) return name=="BoolValue" end},
    TestUniverseId={Value=123,IsA=function(_self,name) return name=="IntValue" end},
    TestPlaceId={Value=456,IsA=function(_self,name) return name=="IntValue" end},
}
local settings = {WaitForChild=function(_self,name) return values[name] end}
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
    "production": r'''
assert(not Storage.preview and Storage.name=="NeighborhoodFixer_P0_v1","Studio settings changed production")
local adapter=Storage.create()
assert(adapter.update("player:123",function()return {value=3} end),"Production adapter failed")
assert(calls==1 and writes==1,"Production did not use cloud adapter")
''',
}
(ROOT / ".tools").mkdir(exist_ok=True)
for name, assertions in scenarios.items():
    script = "--!strict\n" + header.replace("SCENARIO", '"' + name + '"')
    script += "\nlocal Storage=(function()\n" + body + "\nend)()\n" + assertions
    script += '\nprint("PASS StorageAdapter", "' + name + '")\n'
    with tempfile.NamedTemporaryFile("w", dir=ROOT / ".tools", suffix=".luau") as temporary:
        temporary.write(script)
        temporary.flush()
        subprocess.run(["luau", temporary.name], cwd=ROOT, timeout=30, check=True)
