"""Smoke test for tools/lint/cs_magic_numbers.py (U6 C7, D-480; run_all via check_cs.sh, push_gate).

Green on allowed literals and on exempt lines (const, static readonly, attribute, case, enum), comments and
strings, and counting resumes right after each exempt part; red (MN1) on 1.5f, a hex or binary number, a range
bound or a collection expression in a new file and on a file over its baseline; red (MN2) on a file under its
baseline; Sim/ is not scanned; --update only lowers rows, --write-baseline seeds them.
"""

import unittest

import helpers

TOOL = helpers.tool("tools", "lint", "cs_magic_numbers.py")
BASELINE = "tools/lint/cs_magic_baseline.txt"
PATH = "unity/Assets/Scripts/Rampage/View.cs"


def cls(*lines):
    return "class C\n{\n" + "".join("    %s\n" % s for s in lines) + "}\n"


class CsMagicNumbersSmoke(unittest.TestCase):
    def run_tool(self, root, *extra):
        return helpers.run(TOOL, ["--root", str(root), *extra])

    def check(self, text, baseline=None):
        with helpers.scratch() as root:
            helpers.write(root, PATH, text)
            if baseline is not None:
                helpers.write(root, BASELINE, "# header\n%s %d\n" % (PATH, baseline))
            return self.run_tool(root)

    def test_allowed_literals_pass(self):
        code, out = self.check(cls("float a = 0 + 1f + 1.0 + 1.0f + 2d + 10u + 0.5f + 0.25f + 100 + 1000L + 0x0A;",
                                   "int b = x[1..^2]; var t = p.Item3; Vector3 v;"))
        self.assertEqual(code, 0, out)

    def test_exempt_lines_pass(self):
        code, out = self.check(
            "enum E\n{\n    A = 11,\n    B = 0x40,\n}\n"
            + cls("const float K = 1.5f;",
                  "static readonly float[] T = {",
                  "    12.5f, 13f,",
                  "};",
                  "[Range(0.1f, 99f)] public float f;",
                  "void M(int x) { switch (x) { case 42: break; } }"))
        self.assertEqual(code, 0, out)

    def test_counting_resumes_after_exempt_parts(self):
        code, out = self.check(
            "enum E\n{\n    A = 11,\n}\n"
            "float e = 21.5f;\n"
            + cls("static readonly float[] T = {",
                  "    12.5f, 13f,",
                  "}; float t = 22.5f;",
                  "const int N = 33; float c = 23.5f;",
                  "void M(int x) { switch (x) { case 42: y = 24.5f; break; } }"))
        self.assertEqual(code, 1, out)
        self.assertIn("MN1 4 bare numbers", out)
        for lit in ("View.cs:5: 21.5f", "View.cs:10: 22.5f", "View.cs:11: 23.5f", "View.cs:12: 24.5f"):
            self.assertIn(lit, out)

    def test_binary_range_and_collection_counted(self):
        code, out = self.check(cls("int a = 0b101101; int b = 0B1111_0000;", "var r = arr[1..12];",
                                   "    [12.5f, 13.5f]"))
        self.assertEqual(code, 1, out)
        self.assertIn("MN1 5 bare numbers", out)
        for lit in ("0b101101", "0B1111_0000", "View.cs:4: 12", "12.5f", "13.5f"):
            self.assertIn(lit, out)

    def test_comments_and_strings_ignored(self):
        code, out = self.check(cls("// 3.75f in a comment", "/* 99 */ string s = \"77.5\"; char c = '9';"))
        self.assertEqual(code, 0, out)

    def test_real_literal_counted(self):
        code, out = self.check(cls("float a = 1.5f;"))
        self.assertEqual(code, 1, out)
        self.assertIn("View.cs:3: [error] MN1 1 bare numbers, baseline 0", out)
        self.assertIn("View.cs:3: 1.5f", out)

    def test_hex_counted(self):
        code, out = self.check(cls("uint h = x * 0x9E3779B1u;"))
        self.assertEqual(code, 1, out)
        self.assertIn("0x9E3779B1u", out)

    def test_file_over_baseline_fails(self):
        code, out = self.check(cls("float a = 1.5f, b = 2.5f;"), baseline=1)
        self.assertEqual(code, 1, out)
        self.assertIn("MN1 2 bare numbers, baseline 1", out)

    def test_file_at_baseline_passes_under_fails(self):
        code, out = self.check(cls("float a = 1.5f;"), baseline=1)
        self.assertEqual(code, 0, out)
        code, out = self.check(cls("float a = 1.5f;"), baseline=3)
        self.assertEqual(code, 1, out)
        self.assertIn("MN2 1 bare numbers, baseline 3", out)
        self.assertIn("--update", out)

    def test_sim_and_editor_excluded(self):
        with helpers.scratch() as root:
            helpers.write(root, "unity/Assets/Scripts/Sim/Runtime/X.cs", cls("float a = 1.5f;"))
            helpers.write(root, "unity/Assets/Editor/Build.cs", cls("float a = 1.5f;"))
            code, out = self.run_tool(root)
        self.assertEqual(code, 0, out)

    def test_update_only_lowers(self):
        grown = "unity/Assets/Scripts/Rampage/Grown.cs"
        new = "unity/Assets/Scripts/Rampage/New.cs"
        with helpers.scratch() as root:
            helpers.write(root, PATH, cls("float a = 1.5f;"))
            helpers.write(root, grown, cls("float a = 1.5f, b = 2.5f;"))
            helpers.write(root, new, cls("float a = 1.5f;"))
            helpers.write(root, BASELINE, "# header\n%s 3\n%s 1\n" % (PATH, grown))
            self.run_tool(root, "--update")
            code, out = self.run_tool(root)
            text = (root / BASELINE).read_text(encoding="utf-8")
        self.assertIn("%s 1\n" % PATH, text)
        self.assertIn("%s 1\n" % grown, text)
        self.assertNotIn(new, text)
        self.assertEqual(code, 1, out)
        self.assertIn("Grown.cs:3: [error] MN1 2 bare numbers, baseline 1", out)
        self.assertIn("New.cs:3: [error] MN1 1 bare numbers, baseline 0", out)

    def test_write_baseline_seeds_counts(self):
        with helpers.scratch() as root:
            helpers.write(root, PATH, cls("float a = 1.5f, b = 2.5f;"))
            self.run_tool(root, "--write-baseline")
            code, out = self.run_tool(root)
            text = (root / BASELINE).read_text(encoding="utf-8")
        self.assertEqual(code, 0, out)
        self.assertIn("%s 2\n" % PATH, text)


if __name__ == "__main__":
    unittest.main()
