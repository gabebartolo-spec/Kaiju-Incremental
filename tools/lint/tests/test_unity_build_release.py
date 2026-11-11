"""Smoke test for tools/unity/build_release.py (the Unity demo zip; no Unity needed).

Builds a fake unity/Build in a scratch checkout and checks the staging: the game's exe, data and the Unity
runtime ship, the U4 slice player and the Burst DoNotShip folder do not, the zip holds the folder under its
versioned name; a build without its bundled data or its baked slice fails; the build refuses to start without a croc; the build log check passes a good log and fails one
with a compile error or no success line.
"""

import contextlib
import io
import unittest
import zipfile

import helpers


def load_tool():
    import importlib.util

    spec = importlib.util.spec_from_file_location("unity_build_release", helpers.tool("tools", "unity", "build_release.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


TOOL = load_tool()


SLICE_FILES = ("slice.json", "rig.json", "croc.vskin", "croc.kclip", "buildings.bin")


def fake_build(root, data=True, slice_files=SLICE_FILES):
    helpers.write(root, "project.godot", 'config/name="Kaiju"\nconfig/version="9.9-test"\n')
    b = "unity/Build/"
    helpers.write(root, b + "KaijuRampage.exe", "exe")
    helpers.write(root, b + "UnityPlayer.dll", "dll")
    helpers.write(root, b + "UnityCrashHandler64.exe", "crash")
    helpers.write(root, b + "D3D12/D3D12Core.dll", "d3d")
    helpers.write(root, b + "MonoBleedingEdge/EmbedRuntime/mono-2.0-bdwgc.dll", "mono")
    helpers.write(root, b + "KaijuRampage_Data/globalgamemanagers", "ggm")
    if data:
        helpers.write(root, b + "KaijuRampage_Data/StreamingAssets/res/data/tuning.json", "{}")
    for f in slice_files:
        helpers.write(root, b + "KaijuRampage_Data/StreamingAssets/slice/" + f, "x")
    helpers.write(root, b + "KaijuSlice.exe", "slice")
    helpers.write(root, b + "KaijuSlice_Data/level0", "slice data")
    helpers.write(root, b + "Kaiju Unity Slice_BurstDebugInformation_DoNotShip/x.txt", "debug")


def quiet(fn, *args):
    with contextlib.redirect_stdout(io.StringIO()):
        return fn(*args)


class UnityBuildReleaseSmoke(unittest.TestCase):
    def test_stage_ships_the_game_only(self):
        with helpers.scratch() as root:
            fake_build(root)
            version = TOOL.project_version(str(root))
            self.assertEqual(version, "9.9-test")
            zpath = quiet(TOOL.stage, str(root), version)
            self.assertTrue(zpath.endswith("KaijuEvolution-9.9-test-windows-unity.zip"))
            with zipfile.ZipFile(zpath) as z:
                names = set(z.namelist())
            top = "KaijuEvolution-9.9-test-windows-unity/"
            for want in (
                "KaijuRampage.exe",
                "UnityPlayer.dll",
                "UnityCrashHandler64.exe",
                "D3D12/D3D12Core.dll",
                "MonoBleedingEdge/EmbedRuntime/mono-2.0-bdwgc.dll",
                "KaijuRampage_Data/StreamingAssets/res/data/tuning.json",
                "KaijuRampage_Data/StreamingAssets/slice/croc.vskin",
            ):
                self.assertIn(top + want, names)
            self.assertFalse([n for n in names if "Slice" in n], names)
            self.assertTrue(all(n.startswith(top) for n in names), names)
            self.assertTrue((root / "dist" / "KaijuEvolution-9.9-test-windows-unity" / "KaijuRampage.exe").is_file())

    def test_stage_fails_without_bundled_data(self):
        with helpers.scratch() as root:
            fake_build(root, data=False)
            with self.assertRaises(SystemExit) as e:
                quiet(TOOL.stage, str(root), "9.9-test")
            self.assertIn("StreamingAssets", str(e.exception.code))

    def test_stage_fails_without_slice(self):
        with helpers.scratch() as root:
            fake_build(root, slice_files=("slice.json", "buildings.bin"))
            with self.assertRaises(SystemExit) as e:
                quiet(TOOL.stage, str(root), "9.9-test")
            self.assertIn("rig.json", str(e.exception.code))
            self.assertIn("bake_slice.sh", str(e.exception.code))

    def test_build_needs_a_croc(self):
        with helpers.scratch() as root:
            with self.assertRaises(SystemExit) as e:
                quiet(TOOL.build, str(root), "")
            self.assertIn("KAIJU_CROC", str(e.exception.code))

    def test_log_check(self):
        with helpers.scratch() as root:
            good = helpers.write(root, "good.txt", "slice: postfx registered\nrampage: build Succeeded, 0 errors, 900 MB\n")
            quiet(TOOL.check_log, str(good))
            bad = helpers.write(root, "bad.txt", "Assets/X.cs(1,1): error CS0103: nope\nrampage: build Succeeded\n")
            with self.assertRaises(SystemExit) as e:
                quiet(TOOL.check_log, str(bad))
            self.assertIn("compile errors", str(e.exception.code))
            failed = helpers.write(root, "failed.txt", "rampage: build Failed, 3 errors, 0 MB\n")
            with self.assertRaises(SystemExit) as e:
                quiet(TOOL.check_log, str(failed))
            self.assertIn("never says", str(e.exception.code))


if __name__ == "__main__":
    unittest.main()
