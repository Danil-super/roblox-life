"""Pure regressions for Wine desktop identification and resize geometry."""
from pathlib import Path
import sys
import unittest


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from desktop_window import desktop_id, fit_geometry, monitor_for_window, is_empty_helper


class DesktopTitleTests(unittest.TestCase):
    def test_only_known_empty_helper_is_hidden(self):
        cls = b"robloxstudiobeta.exe\0robloxstudiobeta.exe\0"
        self.assertTrue(is_empty_helper(b"RobloxStudio", cls, 100, 100))
        for title, class_name, width, height in (
            (b"Roblox Studio", cls, 100, 100),
            (b"RobloxStudio", b"another.exe", 100, 100),
            (b"RobloxStudio", cls, 648, 514),
            (b"scene - Roblox Studio", cls, 100, 100),
        ):
            self.assertFalse(is_empty_helper(title, class_name, width, height))

    def test_accepts_uuid_at_start_of_localized_desktop_title(self):
        identifier = "7a872c4e-1cc7-4aa4-aad6-a2490c2b6650"
        for suffix in ("Рабочий стол Wine", "Wine desktop"):
            with self.subTest(suffix=suffix):
                self.assertEqual(desktop_id(f"{identifier} - {suffix}"), identifier)

    def test_rejects_scene_titles_other_apps_and_malformed_identifiers(self):
        identifier = "7a872c4e-1cc7-4aa4-aad6-a2490c2b6650"
        titles = (
            "Roblox Life - Roblox Studio",
            "Roblox Life - Рабочий стол Wine",
            f"{identifier} - Roblox Studio",
            f"Editor {identifier} - Wine desktop",
            f" {identifier} - Wine desktop",
            f"{identifier} - Wine desktop - Editor",
            f"{identifier} - Wine desktop\n",
            "7a872c4e1cc74aa4aad6a2490c2b6650 - Wine desktop",
            "7a872c4e-1cc7-4aa4-aad6-a2490c2b665z - Wine desktop",
            "",
        )
        for title in titles:
            with self.subTest(title=title):
                self.assertIsNone(desktop_id(title))


class FitGeometryTests(unittest.TestCase):
    def test_recomputes_client_size_when_resolution_shrinks_and_grows(self):
        frame = (1, 1, 24, 1)
        monitors = ((0, 0, 1920, 1080), (0, 0, 1280, 720), (0, 0, 2560, 1440))
        expected = ((9, 32, 1902, 1039), (9, 32, 1262, 679), (9, 32, 2542, 1399))
        for monitor, geometry in zip(monitors, expected):
            with self.subTest(monitor=monitor):
                self.assertEqual(fit_geometry(monitor, frame), geometry)

    def test_current_frame_extents_change_geometry_at_same_resolution(self):
        monitor = (0, 0, 1920, 1080)
        self.assertEqual(fit_geometry(monitor, (1, 1, 24, 1)), (9, 32, 1902, 1039))
        self.assertEqual(fit_geometry(monitor, (6, 10, 36, 5)), (14, 44, 1888, 1023))
        self.assertEqual(fit_geometry(monitor, (0, 0, 0, 0)), (8, 8, 1904, 1064))

    def test_negative_monitor_origin_preserves_margin_around_entire_frame(self):
        self.assertEqual(
            fit_geometry((-1600, -200, 1600, 900), (6, 10, 36, 5)),
            (-1586, -156, 1568, 843),
        )

    def test_exact_minimum_client_area_fits(self):
        self.assertEqual(fit_geometry((10, 20, 352, 297), (6, 10, 36, 5)), (24, 64, 320, 240))

    def test_rejects_screens_or_frames_that_cannot_fit_minimum_client_area(self):
        cases = (
            ((0, 0, 351, 297), (6, 10, 36, 5)),
            ((0, 0, 352, 296), (6, 10, 36, 5)),
            ((0, 0, 320, 240), (0, 0, 0, 0)),
            ((0, 0, 1920, 1080), (1000, 1000, 24, 1)),
            ((0, 0, 1920, 1080), (1, 1, 600, 600)),
        )
        for monitor, frame in cases:
            with self.subTest(monitor=monitor, frame=frame):
                with self.assertRaises(ValueError):
                    fit_geometry(monitor, frame)


class MonitorSelectionTests(unittest.TestCase):
    def test_chooses_monitor_with_largest_window_intersection(self):
        left = (-1600, 0, 1600, 900)
        right = (0, 0, 1920, 1080)
        self.assertEqual(monitor_for_window([right, left], (-500, 100, 700, 500)), left)
        self.assertEqual(monitor_for_window([left, right], (-200, 100, 700, 500)), right)

    def test_equal_overlap_uses_nearest_monitor_center(self):
        left = (-1600, 0, 1600, 900)
        right = (0, 0, 1920, 1080)
        self.assertEqual(monitor_for_window([right, left], (-100, 0, 200, 100)), left)

    def test_offscreen_window_uses_nearest_monitor_center(self):
        left = (-1600, 0, 1600, 900)
        right = (0, 0, 1920, 1080)
        self.assertEqual(monitor_for_window([right, left], (-2000, 100, 200, 200)), left)
        self.assertEqual(monitor_for_window([left, right], (2500, 100, 200, 200)), right)

    def test_single_monitor_is_selected_for_offscreen_window(self):
        monitor = (0, 0, 1280, 720)
        self.assertEqual(monitor_for_window([monitor], (1900, 0, 600, 600)), monitor)

    def test_empty_monitor_list_is_rejected(self):
        with self.assertRaises(ValueError):
            monitor_for_window([], (0, 0, 800, 600))


if __name__ == "__main__":
    unittest.main()
