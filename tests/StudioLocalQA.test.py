#!/usr/bin/env python3
"""Check that local acceptance refuses existing progress and false console evidence."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from studio_local_qa import validate_start, validate_events, diagnostic_batches
import studio_local_qa


class LocalQA(unittest.TestCase):
    def test_only_fresh_preview_is_allowed(self):
        valid = dict(ready=True, preview=True, dollars=0, xp=0, step="INTRO", building=False)
        validate_start(valid)
        for key, value in dict(ready=False, preview=False, dollars=70, xp=50, step="DONE", building=True).items():
            with self.subTest(key=key):
                changed = valid | {key: value}
                with self.assertRaises(RuntimeError):validate_start(changed)
        with self.assertRaises(RuntimeError):validate_start({})
        for key in ("dollars", "xp"):
            with self.assertRaises(RuntimeError):validate_start(valid | {key: False})

    def batches(self):
        names = ["job_accepted", "job_completed", "furniture_purchased", "furniture_placed", "furniture_moved", "furniture_stored", "furniture_placed", "job_accepted", "job_abandoned"]
        result = []
        for revision, name in enumerate(names, 1):
            changes = [{"event": name}]
            if revision == 4:changes.append({"event": "onboarding_completed"})
            result.append(dict(schema=1, event="profile_change", trace="current", revision=revision, entry="confirmed", omitted=0, dollarsDelta=250 if revision==2 else -180 if revision==3 else 0, xpDelta=50 if revision==2 else 0, changes=changes))
        return result

    def test_wrapped_and_plain_output(self):
        batches = self.batches()
        raw = json.dumps({"messages": [{"message": "[Server] " + json.dumps(batch)} for batch in batches]})
        self.assertEqual(diagnostic_batches(raw), batches)
        self.assertEqual(validate_events(raw)["batches"], 9)
        self.assertEqual(validate_events("\n".join(json.dumps(batch) for batch in batches))["xpDelta"], 50)

    def test_older_context_does_not_count_as_current_actions(self):
        old = copy.deepcopy(self.batches())
        for batch in old:batch["trace"] = "old"
        current = self.batches()
        self.assertEqual(validate_events(json.dumps(old+current))["batches"], 9)
        with self.assertRaises(RuntimeError):validate_events(json.dumps(old+current[:2]))

    def test_wrong_or_duplicated_evidence_is_rejected(self):
        cases = [[], self.batches()[:-1], self.batches()+[self.batches()[-1]]]
        for key, value in dict(entry="pending", omitted=1, dollarsDelta=999, xpDelta=999).items():
            batches=self.batches();batches[-1][key]=value;cases.append(batches)
        for batches in cases:
            with self.subTest(batches=len(batches)):
                with self.assertRaises(RuntimeError):validate_events(json.dumps(batches))

    def test_failed_connection_writes_failed_report_instead_of_leaving_old_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            output=root/".tools/local-qa/latest.json";output.parent.mkdir(parents=True)
            output.write_text('{"status":"passed"}')
            with patch.object(studio_local_qa,"ROOT",root), patch.object(sys,"argv",["qa","--studio-id","one"]), patch.object(studio_local_qa,"StudioRpc",side_effect=RuntimeError("private transport detail")):
                with self.assertRaises(RuntimeError):studio_local_qa.main()
            report=json.loads(output.read_text())
            self.assertEqual(report["status"],"failed")
            self.assertEqual(report["failure"],"RuntimeError")
            self.assertNotIn("private",output.read_text())
            self.assertIn("startedAt",report)

    def test_wrong_studio_and_existing_progress_send_no_input(self):
        class Fake:
            def __init__(self,studios):self.studios,self.calls=studios,[]
            def tool(self,name,args):
                self.calls.append(name)
                if name=="list_roblox_studios":return json.dumps({"studios":self.studios})
                if name=="execute_luau"and args["datamodel_type"]=="Server":return ""
                return json.dumps(dict(ready=True,preview=True,dollars=70,xp=50,step="DONE",building=False))
        for studios in ([],[{"id":"one","name":"OtherGame"}],[{"id":"one","name":"roblox-life.rbxlx"},{"id":"two","name":"roblox-life.rbxlx"}]):
            client=Fake(studios);qa=studio_local_qa.LocalQA(client,"one")
            with self.assertRaises(RuntimeError):qa.begin()
            self.assertEqual(client.calls,["list_roblox_studios"])
        client=Fake([{"id":"one","name":"roblox-life.rbxlx"}]);qa=studio_local_qa.LocalQA(client,"one")
        with self.assertRaises(RuntimeError):qa.begin()
        self.assertNotIn("user_mouse_input",client.calls)
        self.assertFalse(qa.observing)


if __name__ == "__main__":unittest.main()
