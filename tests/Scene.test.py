"""Regression: Studio loads serialized CFrame, not BasePart.Position from XML."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


class BuiltSceneTests(unittest.TestCase):
    def test_parts_have_loadable_transforms(self):
        scene = Path(__file__).resolve().parents[1] / "build/sink-prototype.rbxlx"
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

    def test_new_world_has_a_walkable_private_room_template(self):
        root = ET.parse(Path(__file__).resolve().parents[1] / "build/roblox-life.rbxlx").getroot()
        def child(parent, name):
            matches = [i for i in parent.findall("Item")
                       if i.findtext("Properties/string[@name='Name']") == name]
            self.assertEqual(len(matches), 1, f"Expected one {name}")
            return matches[0]
        storage = child(root, "ServerStorage")
        room = child(storage, "StarterDormTemplate_v1")
        def position(name, axis):
            return float(child(room, name).findtext(f"Properties/CoordinateFrame[@name='CFrame']/{axis}"))
        def size(name, axis):
            return float(child(room, name).findtext(f"Properties/Vector3[@name='size']/{axis}"))
        self.assertGreater(position("RightWall", "X"), position("LeftWall", "X"))
        self.assertLess(position("BackWall", "Z"), position("HomeSpawn", "Z"))
        self.assertLess(position("HomeSpawn", "Z"), position("FrontLeft", "Z"))
        left_edge = position("FrontLeft", "X") + size("FrontLeft", "X") / 2
        right_edge = position("FrontRight", "X") - size("FrontRight", "X") / 2
        self.assertGreaterEqual(right_edge - left_edge, 4, "Avatar needs a usable doorway")
        self.assertGreaterEqual(position("DoorLintel", "Y") - size("DoorLintel", "Y") / 2, 7)
        self.assertAlmostEqual(position("Floor", "Y") + size("Floor", "Y") / 2, 0)
        self.assertGreater(position("Lamp", "Y"), 8, "Room light must be above the avatar")
        camera = child(root, "StarterPlayer").find("Properties/*[@name='CameraMaxZoomDistance']")
        clearance = min(
            position("RightWall", "X") - position("HomeSpawn", "X"),
            position("HomeSpawn", "X") - position("LeftWall", "X"),
            position("FrontLeft", "Z") - position("HomeSpawn", "Z"),
            position("HomeSpawn", "Z") - position("BackWall", "Z"),
        ) - 0.5
        self.assertLessEqual(float(camera.text), clearance,
                             "Initial camera must fit inside the room instead of looking through the doorway")

    def test_current_place_has_only_one_server_and_one_client_bootstrap(self):
        root = ET.parse(Path(__file__).resolve().parents[1] / "build/roblox-life.rbxlx").getroot()
        self.assertEqual(len([i for i in root.iter("Item") if i.get("class") == "Script"]), 1)
        self.assertEqual(len([i for i in root.iter("Item") if i.get("class") == "LocalScript"]), 1)


if __name__ == "__main__":
    unittest.main()
