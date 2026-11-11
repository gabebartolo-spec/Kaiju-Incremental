"""Smoke test for tools/lint/cs_complexity_ratchet.py (U6 C2; run_all via check_cs.sh, push_gate).

Green on small code; red, by rule, on a new long method, a new branchy method and a new long file (CR1),
on a baselined one that grew (CR2) and on a stale baseline row (CR3); --shrink drops fixed rows.
"""

import unittest

import helpers

TOOL = helpers.tool("tools", "lint", "cs_complexity_ratchet.py")
BASELINE = "tools/lint/cs_complexity_baseline.txt"
PATH = "unity/Assets/Scripts/Rampage/View.cs"


def method(name="Big", body_lines=45, branches=0):
    body = "".join("        x += 1;\n" for _ in range(body_lines))
    body += "".join("        if (x == %d) x = 0;\n" % i for i in range(branches))
    return "    void %s(int x)\n    {\n%s    }\n" % (name, body)


def cls(*methods):
    return "class C\n{\n" + "".join(methods) + "}\n"


class CsComplexityRatchetSmoke(unittest.TestCase):
    def run_tool(self, root, *extra):
        return helpers.run(TOOL, ["--root", str(root), *extra])

    def test_small_code_passes(self):
        with helpers.scratch() as root:
            helpers.write(root, PATH, cls(method(body_lines=3)))
            exit_code, out = self.run_tool(root)
        self.assertEqual(exit_code, 0, out)

    def test_new_long_method_fails_cr1(self):
        with helpers.scratch() as root:
            helpers.write(root, PATH, cls(method()))
            exit_code, out = self.run_tool(root)
        self.assertEqual(exit_code, 1, out)
        self.assertIn("View.cs:3: [error] CR1 Big", out)

    def test_new_branchy_method_fails_cr1(self):
        with helpers.scratch() as root:
            helpers.write(root, PATH, cls(method("Tangled", body_lines=1, branches=13)))
            exit_code, out = self.run_tool(root)
        self.assertEqual(exit_code, 1, out)
        self.assertIn("CR1 Tangled", out)
        self.assertIn("cc 14", out)

    def test_new_long_file_fails_cr1(self):
        small = [method("M%d" % i, body_lines=30) for i in range(14)]
        with helpers.scratch() as root:
            helpers.write(root, PATH, cls(*small))
            exit_code, out = self.run_tool(root)
        self.assertEqual(exit_code, 1, out)
        self.assertIn("CR1 <file>", out)

    def test_baselined_method_passes_until_it_grows(self):
        with helpers.scratch() as root:
            helpers.write(root, PATH, cls(method()))
            # signature + { + 45 body lines + } = 48 non-blank lines, cc 1
            helpers.write(root, BASELINE, "# header\n%s::Big 48 1\n" % PATH)
            ok_code, ok_out = self.run_tool(root)
            self.assertEqual(ok_code, 0, ok_out)
            helpers.write(root, PATH, cls(method(body_lines=50)))
            grew_code, grew_out = self.run_tool(root)
        self.assertEqual(grew_code, 1, grew_out)
        self.assertIn("CR2 Big", grew_out)

    def test_accessor_and_tuple_method_are_keyed_by_name(self):
        branches = "".join("            if (x == %d) x = 0;\n" % i for i in range(13))
        prop = "    public int Tangled\n    {\n        get\n        {\n%s            return x;\n        }\n    }\n" % branches
        tuple_method = method(body_lines=45).replace("void Big(", "static (int, int) Pair(")
        with helpers.scratch() as root:
            helpers.write(root, PATH, cls(prop, tuple_method))
            exit_code, out = self.run_tool(root)
        self.assertEqual(exit_code, 1, out)
        self.assertIn("CR1 Tangled.get", out)
        self.assertIn("CR1 Pair", out)
        self.assertNotIn("CR1 static", out)

    def test_overloads_are_keyed_in_order(self):
        with helpers.scratch() as root:
            helpers.write(root, PATH, cls(method(body_lines=3), method()))
            exit_code, out = self.run_tool(root)
        self.assertEqual(exit_code, 1, out)
        self.assertIn("CR1 Big~2", out)

    def test_stale_row_fails_cr3_and_shrink_drops_it(self):
        with helpers.scratch() as root:
            helpers.write(root, PATH, cls(method(body_lines=3)))
            helpers.write(root, BASELINE, "# header\n%s::Big 48 1\n" % PATH)
            exit_code, out = self.run_tool(root)
            self.assertEqual(exit_code, 1, out)
            self.assertIn("CR3", out)
            shrink_code, shrink_out = self.run_tool(root, "--shrink")
            self.assertEqual(shrink_code, 0, shrink_out)
            after_code, after_out = self.run_tool(root)
        self.assertEqual(after_code, 0, after_out)

    def test_text_in_strings_comments_and_generated_code_is_ignored(self):
        body = '    string Quiet()\n    {\n        // if (a && b || c ?? d)\n        return "if (x && y || z)";\n    }\n'
        with helpers.scratch() as root:
            helpers.write(root, PATH, cls(body))
            helpers.write(root, "unity/Assets/Scripts/Sim/Game/Gen.cs", cls(method()))
            exit_code, out = self.run_tool(root)
        self.assertEqual(exit_code, 0, out)


if __name__ == "__main__":
    unittest.main()
