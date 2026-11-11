"""Smoke test for tools/lint/cs_determinism.py (U6 C1; run_all via check_cs.sh, push_gate).

Green on seeded randomness and on a marked line; red, by rule, on unseeded randomness (D1), an unseeded
RandomNumberGenerator (D2) and a clock in GameLogic (D3); a clock in a view and code in Sim/Game pass.
"""

import unittest

import helpers

TOOL = helpers.tool("tools", "lint", "cs_determinism.py")
VIEW = "unity/Assets/Scripts/Rampage/View.cs"
LOGIC = "unity/Assets/Scripts/GameLogic/Logic.cs"


def cs(body):
    """A class whose one method holds the body lines; the first body line is line 5."""
    return "class C\n{\n    void M(int seed)\n    {\n" + "".join("        %s\n" % line for line in body) + "    }\n}\n"


class CsDeterminismSmoke(unittest.TestCase):
    def check(self, files):
        with helpers.scratch() as root:
            for path, text in files.items():
                helpers.write(root, path, text)
            return helpers.run(TOOL, ["--root", str(root)])

    def test_seeded_randomness_passes(self):
        code = cs([
            "var a = new System.Random(seed);",
            "S.RandomNumberGenerator r = new S.RandomNumberGenerator();",
            "r.seed = seed;",
            'var b = S.Seeds.Make("x", seed);',
            "float t = Time.deltaTime; // a view may read a clock",
            'string s = "Random.Range(0, 1) and DateTime.Now in text";',
        ])
        exit_code, out = self.check({VIEW: code})
        self.assertEqual(exit_code, 0, out)

    def test_unseeded_random_fails_d1(self):
        exit_code, out = self.check({VIEW: cs(["var a = new System.Random();", "var g = Guid.NewGuid();"])})
        self.assertEqual(exit_code, 1, out)
        self.assertIn("View.cs:5: [error] D1", out)
        self.assertIn("View.cs:6: [error] D1", out)

    def test_target_typed_and_clock_seeded_random_fail_d1(self):
        code = cs([
            "Random a = new();",
            "System.Random b = new( );",
            "var c = new Random(Environment.TickCount);",
            "var d = new System.Random(DateTime.Now.Millisecond);",
            "Random R2() => new(Environment.TickCount);",
            "Random e = new(seed);",
            "Vector2 v = new(Time.time, 0f);",
        ])
        exit_code, out = self.check({VIEW: code})
        self.assertEqual(exit_code, 1, out)
        for line in (5, 6, 7, 8, 9):
            self.assertIn("View.cs:%d: [error] D1" % line, out)
        self.assertNotIn("View.cs:10:", out)
        self.assertNotIn("View.cs:11:", out)

    def test_unity_random_fails_d1(self):
        exit_code, out = self.check({VIEW: cs(["float x = Random.Range(0f, 1f);"])})
        self.assertEqual(exit_code, 1, out)
        self.assertIn("D1 Random.Range", out)

    def test_unseeded_rng_fails_d2(self):
        code = cs(["var r = new S.RandomNumberGenerator();", "int a = 1;", "int b = 2;", "int c = 3;", "r.seed = 4;"])
        exit_code, out = self.check({VIEW: code})
        self.assertEqual(exit_code, 1, out)
        self.assertIn("View.cs:5: [error] D2", out)

    def test_clock_in_game_logic_fails_d3(self):
        exit_code, out = self.check({LOGIC: cs(["var now = DateTime.Now;"])})
        self.assertEqual(exit_code, 1, out)
        self.assertIn("Logic.cs:5: [error] D3 DateTime.Now", out)

    def test_marker_and_generated_code_pass(self):
        files = {
            LOGIC: cs(["var now = DateTime.Now; // seed-ok: report stamp only"]),
            "unity/Assets/Scripts/Sim/Game/Gen.cs": cs(["var a = new System.Random();"]),
        }
        exit_code, out = self.check(files)
        self.assertEqual(exit_code, 0, out)

    def test_marker_needs_a_reason(self):
        exit_code, out = self.check({LOGIC: cs(["var now = DateTime.Now; // seed-ok:"])})
        self.assertEqual(exit_code, 1, out)
        self.assertIn("D3", out)


if __name__ == "__main__":
    unittest.main()
