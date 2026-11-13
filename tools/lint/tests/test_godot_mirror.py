"""What U6 moved off Godot's files still equals Godot's copy, while Godot is still on main.

data/tuning.json kaiju_body holds the body's measures the Unity bakes read (from scenes/kaiju_model.gd and
scenes/biped_swing.gd consts), and version.txt the release version (project.godot's config/version). Godot keeps
its own until it leaves main (D-484); this keeps the two equal until then and leaves main with Godot
(tools/unity/retire_godot.py).
"""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
CONST = r"^const {}\s*:?=\s*(.+?)\s*$"


def const(script: str, name: str) -> list[float]:
    text = (ROOT / script).read_text(encoding="utf-8")
    m = re.search(CONST.format(name), text, re.MULTILINE)
    assert m, f"no const {name} in {script}"
    return [float(x) for x in re.findall(r"[-0-9.eE+]+", m.group(1).replace("Vector3", ""))]


@unittest.skipUnless((ROOT / "scenes").is_dir(), "Godot has left main")
class GodotMirror(unittest.TestCase):
    def test_data_matches_godot(self):
        body = json.loads((ROOT / "data/tuning.json").read_text(encoding="utf-8"))["kaiju_body"]
        self.assertEqual([body["model_height"]], const("scenes/kaiju_model.gd", "MODEL_HEIGHT"))
        for part in ("upper", "fore", "hand"):
            self.assertEqual(body["arm_rest"][part], const("scenes/biped_swing.gd", "ARM_" + part.upper()), part)

    def test_version_matches_godot(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        m = re.search(r'^config/version="([^"]+)"', project, re.MULTILINE)
        self.assertIsNotNone(m)
        self.assertEqual((ROOT / "version.txt").read_text(encoding="utf-8").strip(), m.group(1))


if __name__ == "__main__":
    unittest.main()
