"""tools/unity/retire_godot.py: what leaves main at the switch (D-484) and what counts as a kept file reading it."""
import importlib.util
import pathlib
import unittest

SPEC = importlib.util.spec_from_file_location(
    "retire_godot", pathlib.Path(__file__).resolve().parents[2] / "unity" / "retire_godot.py"
)
rg = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(rg)


class Leaves(unittest.TestCase):
    def test_godot_files_leave(self):
        for p in ("project.godot", "sim/rampage_sim.gd", "scenes/croc.tscn", "assets/fonts/a.ttf.import",
                  "native/src/kaiju_settle.cpp", "tests/run_sim_tests.gd", "tools/run_tests.sh",
                  ".github/workflows/tests.yml", "tools/pacing.gd"):
            self.assertTrue(rg.leaves(p), p)

    def test_unity_data_and_assets_stay(self):
        for p in ("unity/Assets/Scripts/Croc.cs", "unity/native/kaiju_core.cpp", "data/tuning.json",
                  "assets/kaiju/reptilian_adult.kvox", "docs/DESIGN.md", "tools/unity/bake_slice.sh",
                  ".github/workflows/unity.yml", "unity/Assets/Foo.tres"):
            self.assertFalse(rg.leaves(p), p)


class CodeText(unittest.TestCase):
    def test_comments_are_not_reads(self):
        cs = '// ported from scenes/a.gd\nvar x = Read("scenes/b.gd");\n'
        self.assertNotIn("scenes/a.gd", rg.code_text("x.cs", cs))
        self.assertIn("scenes/b.gd", rg.code_text("x.cs", cs))
        sh = "# needs tools/run_tests.sh\nbash tools/capture/x.sh\n"
        self.assertNotIn("run_tests", rg.code_text("x.sh", sh))
        self.assertIn("tools/capture/x.sh", rg.code_text("x.sh", sh))
        xml = "<!-- export_slice.gd's output -->\n<Compile Include=\"a.cs\" />"
        self.assertNotIn("export_slice", rg.code_text("x.csproj", xml))

    def test_blockers_name_the_kept_reader(self):
        found = rg.blockers(["tools/unity/slicebake/GdConst.cs"], {"scenes/kaiju_model.gd"})
        self.assertEqual(found, {"tools/unity/slicebake/GdConst.cs": ["scenes/kaiju_model.gd"]})


if __name__ == "__main__":
    unittest.main()
