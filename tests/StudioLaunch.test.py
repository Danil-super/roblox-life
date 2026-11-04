"""The project launcher must reuse Studio, including concurrent startup requests."""
from pathlib import Path
import concurrent.futures
import importlib.util
import subprocess
import tempfile
import os
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("studio_open", ROOT / "scripts/studio_open.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class StudioLaunchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "Рабочий стол с пробелами"
        (self.root / "build").mkdir(parents=True)
        (self.root / "build/roblox-life.rbxlx").write_text("test place")
        self.proc = Path(self.temp.name) / "proc"
        self.proc.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def process(self, pid, command):
        folder = self.proc / str(pid)
        folder.mkdir()
        (folder / "cmdline").write_bytes(command + b"\0--ignored-private-argument\0")

    def test_recognizes_studio_but_not_mcp_or_webview(self):
        self.process(10, b"C:\\Roblox\\RobloxStudioBeta.exe")
        self.process(11, b"Z:\\Roblox\\StudioMCP.exe")
        self.process(12, b"C:\\WebView\\msedgewebview2.exe")
        self.process(13, b"/usr/bin/robloxstudiobeta.exe")
        self.assertEqual(module.studio_processes(self.proc), [10, 13])

    @patch.object(module.shutil, "which", return_value="/usr/bin/flatpak")
    @patch.object(module.subprocess, "Popen")
    def test_repeated_request_does_not_launch_another_studio(self, spawn, _which):
        self.process(10, b"C:\\Roblox\\RobloxStudioBeta.exe")
        self.assertEqual(module.open_once(self.root, self.proc), "existing")
        self.assertEqual(module.open_once(self.root, self.proc), "existing")
        spawn.assert_not_called()

    @patch.object(module.shutil, "which", return_value="/usr/bin/flatpak")
    @patch.object(module.subprocess, "Popen")
    def test_first_launch_preserves_cyrillic_spaces_and_detaches(self, spawn, _which):
        spawn.return_value.pid = 99
        self.assertEqual(module.open_once(self.root, self.proc), "started")
        args, kwargs = spawn.call_args
        self.assertEqual(args[0], ["flatpak", "run", "org.vinegarhq.Vinegar", "--task", "EditFile",
                                   "--localPlaceFile", "Z:" + str(self.root / "build/roblox-life.rbxlx").replace("/", "\\")])
        self.assertTrue(kwargs["start_new_session"])
        self.assertEqual(kwargs["stdin"], subprocess.DEVNULL)
        self.assertEqual(module.open_once(self.root, self.proc), "starting")
        self.assertEqual(spawn.call_count, 1)

    @patch.object(module.shutil, "which", return_value="/usr/bin/flatpak")
    @patch.object(module.subprocess, "Popen")
    def test_concurrent_requests_launch_once(self, spawn, _which):
        spawn.return_value.pid = 99
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: module.open_once(self.root, self.proc), range(2)))
        self.assertEqual(sorted(results), ["started", "starting"])
        self.assertEqual(spawn.call_count, 1)

    @patch.object(module.subprocess, "Popen")
    def test_missing_place_never_launches(self, spawn):
        (self.root / "build/roblox-life.rbxlx").unlink()
        with self.assertRaises(FileNotFoundError):
            module.open_once(self.root, self.proc)
        spawn.assert_not_called()

    @patch.object(module.shutil, "which", return_value=None)
    @patch.object(module.subprocess, "Popen")
    def test_missing_flatpak_never_installs_or_launches(self, spawn, _which):
        with self.assertRaises(RuntimeError):
            module.open_once(self.root, self.proc)
        spawn.assert_not_called()

    @patch.object(module.shutil, "which", return_value="/usr/bin/flatpak")
    @patch.object(module.subprocess, "Popen", side_effect=OSError("start failed"))
    def test_failed_spawn_does_not_reserve_startup(self, _spawn, _which):
        with self.assertRaises(OSError):
            module.open_once(self.root, self.proc)
        self.assertFalse((self.root / ".tools/studio-launch.json").exists())

    @patch.object(module.shutil, "which", return_value="/usr/bin/flatpak")
    @patch.object(module.subprocess, "Popen")
    def test_expired_failed_start_can_be_retried(self, spawn, _which):
        folder = self.root / ".tools"
        folder.mkdir()
        reservation = folder / "studio-launch.json"
        reservation.write_text('{"pid":99}')
        os.utime(reservation, (time.time() - 100, time.time() - 100))
        spawn.return_value.pid = 100
        self.assertEqual(module.open_once(self.root, self.proc), "started")
        self.assertEqual(spawn.call_count, 1)

    @patch.object(module.subprocess, "Popen")
    def test_slow_live_launcher_is_not_duplicated_after_timeout(self, spawn):
        folder = self.root / ".tools"
        folder.mkdir()
        reservation = folder / "studio-launch.json"
        reservation.write_text('{"pid":99}')
        os.utime(reservation, (time.time() - 100, time.time() - 100))
        (self.proc / "99").mkdir()
        self.assertEqual(module.open_once(self.root, self.proc), "starting")
        spawn.assert_not_called()

    @patch.object(module.subprocess, "Popen")
    def test_incomplete_reservation_still_protects_recent_start(self, spawn):
        folder = self.root / ".tools"
        folder.mkdir()
        (folder / "studio-launch.json").write_text('[]')
        self.assertEqual(module.open_once(self.root, self.proc), "starting")
        spawn.assert_not_called()


if __name__ == "__main__":
    unittest.main()
