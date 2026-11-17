#!/usr/bin/env python3
"""Exercise the SAVE-01 capture boundary and the local evidence comparison."""

from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("verify_cloud_test", ROOT / "scripts/verify_cloud_test.py")
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CloudEvidenceTests(unittest.TestCase):
    def setUp(self):
        cells = {"columns": 12, "rows": 8, "masks": ["1" * 84 + "0" * 12]}
        first = dict(schema=1, universe=123, place=456, scope="qa-test-1", stage="wall-before",
                     fence=1, revision=2, dollars=0, xp=0, step="NAVIGATE", completed=0,
                     housingRevision=0, job={"id": "job-1", "status": "Accepted", "cells": cells}, items={})
        placed = dict(first, stage="furniture-before", fence=2, revision=5, dollars=70, xp=50,
                      step="DONE", completed=1, housingRevision=1,
                      job={"id": "job-1", "status": "Completed", "cells": cells, "reward": 250},
                      items=[{"id": "item-1", "catalog": "floor-plant-coral-v1", "price": 180,
                              "pose": {"x": 8, "y": 0, "z": 6, "rotationY": 45, "roomTemplateVersion": 1}}])
        self.snapshots = [deepcopy(s) for s in (
            first, dict(first, stage="wall-after", fence=2),
            placed, dict(placed, stage="furniture-after", fence=3)
        )]

    def output(self):
        return "\n".join("13:01:01 SAVE01 " + json.dumps(s) + "  -  Server" for s in self.snapshots)

    def test_three_sessions_match(self):
        result = module.verify("13:00:00 Server ready\n" + self.output())
        self.assertEqual(result, {"scope": "qa-test-1", "covered": 84, "dollars": 70, "xp": 50, "acquisitions": 3})

    def test_rejects_mixed_sessions_and_mutated_rejoin(self):
        original = deepcopy(self.snapshots)
        for index, key, value in (
            (1, "scope", "qa-other"), (1, "place", 455), (3, "fence", 2),
            (1, "revision", 3), (3, "dollars", 250), (3, "items", []), (0, "dollars", False),
        ):
            with self.subTest(index=index, key=key):
                self.snapshots = deepcopy(original)
                self.snapshots[index][key] = value
                with self.assertRaises(ValueError):
                    module.verify(self.output())
        self.snapshots = original
        self.snapshots[1]["job"]["cells"]["masks"][0] = "0" * 12 + "1" * 84
        with self.assertRaisesRegex(ValueError, "checkpoint"):
            module.verify(self.output())

    def test_rejects_incomplete_output_and_changed_furniture(self):
        with self.assertRaisesRegex(ValueError, "one snapshot"):
            module.verify("SAVE01 {}")
        self.snapshots[3]["items"][0]["pose"]["rotationY"] = 0
        with self.assertRaisesRegex(ValueError, "pose changed"):
            module.verify(self.output())

    def test_real_capture_selects_uncached_read_and_checks_context(self):
        source = (ROOT / "scripts/cloud_qa_snapshot.luau").read_text()
        body = source[source.index("local stages = "):]
        header = r'''
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local now = os.time()
local storeName = "NeighborhoodFixer_P0_StudioQA_v1"
local Storage = {name=storeName, scope="qa-test-1", preview=false}
local game = {GameId=123,PlaceId=456}
local studio, running, server = true, true, true
local RunService = {
    IsStudio=function() return studio end,
    IsRunning=function() return running end,
    IsServer=function() return server end,
}
local profile=Profile.new(314)
assert(Jobs.accept(profile,"tutorial-qa"),"Game fixture could not accept tutorial")
profile.jobs.active.checkpoint={columns=12,rows=8,masks={string.rep("1",84)..string.rep("0",12)}}
local player={UserId=314}
local attrs={ProfileStatus="Ready",StorageMode="Persistent",PaintingXP=0,OnboardingStep="NAVIGATE"}
local stats={FindFirstChild=function(_,name)
    assert(name=="Dollars")
    return {Value=0,IsA=function(_,kind) return kind=="IntValue" end}
end}
function player:GetAttribute(key) return attrs[key] end
function player:FindFirstChild(name) return if name=="leaderstats" then stats else nil end
local members={player}
local Players={GetPlayers=function() return members end}
player.Parent=Players
local lookups,reads,output = 0,0,nil
local expiry=now+120
local DataStoreService={GetDataStore=function(_,name,scope)
    lookups+=1
    assert(name==storeName and scope=="qa-test-1","Snapshot accessed another store")
    return {GetAsync=function(_,key,options)
        reads+=1
        assert(key=="player:314" and options.UseCache==false,"Read used cache or another key")
        return {recordVersion=1,fence=1,leaseOwner="session-token",leaseUntil=expiry,profile=profile}
    end}
end}
local Instance={new=function(kind) assert(kind=="DataStoreGetOptions");return {UseCache=true} end}
local HttpService={JSONEncode=function(_,value) output=value;return "serialized" end}
'''
        footer = r'''
assert(capture("wall-before")=="SAVE01 serialized","No capture marker")
assert(output.scope=="qa-test-1" and output.fence==1 and output.job.cells.masks[1]==profile.jobs.active.checkpoint.masks[1])
assert(output.job.id=="tutorial-qa" and output.dollars==0 and output.xp==0 and #output.items==0)
assert(output.userId==nil and output.leaseOwner==nil and lookups==1 and reads==1,"Unexpected sensitive output or storage call")
server=false;assert(not pcall(capture,"wall-before"));server=true
studio=false;assert(not pcall(capture,"wall-before"));studio=true
running=false;assert(not pcall(capture,"wall-before"));running=true
Storage.blocked="CloudTestWrongExperience";assert(not pcall(capture,"wall-before"));Storage.blocked=nil
Storage.scope="global";assert(not pcall(capture,"wall-before"));Storage.scope="qa-test-1"
table.insert(members,{});assert(not pcall(capture,"wall-before"));table.remove(members)
attrs.ProfileStatus="Saving";assert(not pcall(capture,"wall-before"));attrs.ProfileStatus="Ready"
assert(not pcall(capture,"unknown"))
assert(lookups==1 and reads==1,"Refused preflight still reached DataStore")
attrs.PaintingXP=1;assert(not pcall(capture,"wall-after"));attrs.PaintingXP=0
expiry=now-1;assert(not pcall(capture,"wall-after"))
assert(lookups==3 and reads==3,"Fixture did not exercise persisted mismatches")
'''
        (ROOT / ".tools").mkdir(exist_ok=True)
        with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
            script.write(header + "\nlocal capture=(function()\n" + body + "\nend)()\n" + footer)
            script.flush()
            subprocess.run(["luau", script.name], cwd=ROOT, check=True, timeout=30)


if __name__ == "__main__":
    unittest.main()
