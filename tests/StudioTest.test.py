#!/usr/bin/env python3
"""Exercise project selection, observed mode transitions and official-tool failures."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from studio_test import operate, content


class Fake:
    def __init__(self):
        self.mode = "Edit"
        self.studios = [{"id": "one", "name": "NeighborhoodFixer"}]
        self.codes = []
        self.fail_launch = False

    def tool(self, name, args):
        import json
        if name == "list_roblox_studios":
            return json.dumps({"studios": self.studios})
        if name == "get_studio_state":
            return f"- Current Studio Mode: {self.mode}\n- Available DataModels: Edit, Client, Server"
        if name == "execute_luau":
            code = args["code"]
            self.codes.append(code)
            if "ExecutePlayModeAsync" in code:
                if not self.fail_launch:
                    self.mode = "Play"
                return "requested"
            if "EndTest" in code:
                self.mode = "Edit"
                return "ending"
            return "Launch blocked" if self.fail_launch else ""
        raise AssertionError(name)


class StudioTest(unittest.TestCase):
    def test_solo_start_and_stop_observe_mode(self):
        c = Fake()
        self.assertEqual(operate(c, "start"), "Play")
        self.assertIn("ExecutePlayModeAsync({", c.codes[0])
        self.assertEqual(operate(c, "stop"), "Edit")
        self.assertIn("EndTest", c.codes[-1])

    def test_idempotent_requests_do_not_restart(self):
        c = Fake()
        operate(c, "stop")
        c.mode = "Play"
        operate(c, "start")
        self.assertEqual(c.codes, [])

    def test_no_wrong_project_or_ambiguous_studio(self):
        for studios in [[], [{"id": "two", "name": "OtherGame"}],
                        [{"id": "one", "name": "NeighborhoodFixer"}, {"id": "two", "name": "NeighborhoodFixer"}]]:
            c = Fake()
            c.studios = studios
            with self.assertRaises(RuntimeError):
                operate(c, "start")
            self.assertEqual(c.codes, [])

    def test_explicit_instance(self):
        c = Fake()
        c.studios.append({"id": "two", "name": "OtherGame"})
        self.assertEqual(operate(c, "status", "one"), "Edit")

    def test_launch_failure_not_reported_as_play(self):
        c = Fake()
        c.fail_launch = True
        with self.assertRaisesRegex(RuntimeError, "Launch blocked"):
            operate(c, "start")

    def test_unknown_mode_fails_closed(self):
        c = Fake()
        c.mode = "Unexpected"
        with self.assertRaises(RuntimeError):
            operate(c, "start")

    def test_mode_change_between_poll_and_probe(self):
        class Racing(Fake):
            def tool(self, name, args):
                if name == "execute_luau":
                    if "ExecutePlayModeAsync" in args["code"]:
                        return "requested"
                    self.mode = "Play"
                    raise RuntimeError("Edit datamodel is not available in Play mode")
                return super().tool(name, args)
        self.assertEqual(operate(Racing(), "start"), "Play")

    def test_official_tool_error_is_not_success(self):
        for result in [{"error": {"message": "RPC failed"}},
                       {"result": {"isError": True, "content": [{"type": "text", "text": "Tool failed"}]}}]:
            with self.assertRaises(RuntimeError):
                content(result)


if __name__ == "__main__":
    unittest.main()
