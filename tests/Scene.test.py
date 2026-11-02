"""Regression: Studio loads serialized CFrame, not BasePart.Position from XML."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


class BuiltSceneTests(unittest.TestCase):
    def test_parts_have_loadable_transforms(self):
        scene = Path(__file__).resolve().parents[1] / "build/roblox-life.rbxlx"
        root = ET.parse(scene).getroot()
        expected = {
            "Floor": (0, -0.5, 0),
            "BackWall": (0, 5, -12),
            "SideWall": (-16, 5, 0),
            "Sink": (0, 1.5, -8),
            "Basin": (0, 3.1, -8),
            "Faucet": (0, 3.6, -8.8),
            "Spawn": (0, 0.15, 4),
        }
        parts = {}
        for item in root.iter("Item"):
            if item.get("class") in ("Part", "SpawnLocation"):
                props = item.find("Properties")
                parts[props.findtext("string[@name='Name']")] = props
        self.assertEqual(set(parts), set(expected))
        for name, position in expected.items():
            with self.subTest(part=name):
                frame = parts[name].find("CoordinateFrame[@name='CFrame']")
                self.assertIsNotNone(frame, f"{name}: missing loadable CFrame")
                for axis, value in zip(("X", "Y", "Z"), position):
                    self.assertAlmostEqual(float(frame.findtext(axis)), value, places=5)


if __name__ == "__main__":
    unittest.main()
