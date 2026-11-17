#!/usr/bin/env python3
"""Check the real QA-project builder; this never contacts Roblox."""
from pathlib import Path
import importlib.util
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("build_cloud_test", ROOT / "scripts/build_cloud_test.py")
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CloudBuildTests(unittest.TestCase):
    def test_explicit_ids_and_isolated_project(self):
        before = (ROOT / "default.project.json").read_text()
        result = module.make_project(ROOT, 123, 456)
        settings = result["tree"]["ServerStorage"]["DevelopmentSettings"]
        self.assertTrue(settings["StudioDataStoreTest"]["$properties"]["Value"])
        self.assertEqual(settings["TestUniverseId"]["$properties"]["Value"], 123)
        self.assertEqual(settings["TestPlaceId"]["$properties"]["Value"], 456)
        self.assertEqual(result["serveAddress"], "127.0.0.1")
        self.assertEqual(result["servePort"], 34873)
        self.assertEqual((ROOT / "default.project.json").read_text(), before)
        original = json.loads(before)["tree"]["ServerStorage"]["DevelopmentSettings"]
        self.assertFalse(original["StudioDataStoreTest"]["$properties"]["Value"])
        self.assertNotIn("TestRunId", original)
        self.assertNotIn("TestRunId", settings)
        self.assertNotIn("CloudQASnapshot", result["tree"]["ServerStorage"])

    def test_named_run_adds_only_server_evidence(self):
        result = module.make_project(ROOT, 123, 456, "save-01-try-2")
        server_storage = result["tree"]["ServerStorage"]
        self.assertEqual(server_storage["DevelopmentSettings"]["TestRunId"]["$properties"]["Value"], "save-01-try-2")
        self.assertEqual(Path(server_storage["CloudQASnapshot"]["$path"]), ROOT / "scripts/cloud_qa_snapshot.luau")
        original = json.loads((ROOT / "default.project.json").read_text())
        self.assertNotIn("CloudQASnapshot", original["tree"]["ServerStorage"])
        for run_id in ("", "-first", "With-Spaces", "two words", "a" * 21, "qa/other", "test\n", True):
            with self.subTest(run_id=run_id):
                with self.assertRaises(ValueError):
                    module.make_project(ROOT, 123, 456, run_id)

    def test_paths_still_resolve_when_project_is_generated_under_build(self):
        result = module.make_project(ROOT, 123, 456)
        found = []
        def visit(node):
            if isinstance(node, dict):
                for key, value in node.items():
                    if key == "$path":
                        self.assertTrue(Path(value).is_absolute())
                        self.assertTrue(Path(value).exists())
                        found.append(value)
                    else:
                        visit(value)
            elif isinstance(node, list):
                for value in node:
                    visit(value)
        visit(result)
        self.assertGreaterEqual(len(found), 3)

    def test_invalid_ids_rejected_before_build(self):
        for value in (0, -1, True, 1.5, float("nan"), 9007199254740992):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    module.make_project(ROOT, value, 456)
                with self.assertRaises(ValueError):
                    module.make_project(ROOT, 123, value)


if __name__ == "__main__":
    unittest.main()
