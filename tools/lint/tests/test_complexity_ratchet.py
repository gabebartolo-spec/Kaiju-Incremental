"""Smoke test for tools/lint/complexity_ratchet.py (tests.yml preflight and tools/prepush.sh step 2).

Green on short functions; red, by rule, on a new function over 40 lines or complexity 12 (CR1), on a
baselined one that grew (CR2) and on a baseline row that is stale (CR3); --shrink drops fixed rows.
"""

import unittest

import helpers

TOOL = helpers.tool("tools", "lint", "complexity_ratchet.py")
BASELINE = "tools/lint/complexity_baseline.txt"


def long_func(name="big", body_lines=45):
    return f"func {name}() -> void:\n" + "".join("\tprint(1)\n" for _ in range(body_lines))


def branchy_func(name="tangled", branches=14):
    return f"func {name}(x: int) -> void:\n" + "".join(f"\tif x == {i}:\n\t\tprint({i})\n" for i in range(branches))


class ComplexityRatchetSmoke(unittest.TestCase):
    def test_short_function_passes(self):
        with helpers.scratch() as root:
            helpers.write(root, "sim/a.gd", "func small() -> void:\n\tprint(1)\n")
            exit_code, out = helpers.run(TOOL, ["--root", str(root)])
        self.assertEqual(exit_code, 0, out)

    def test_new_long_function_fails_cr1(self):
        with helpers.scratch() as root:
            helpers.write(root, "sim/a.gd", long_func())
            exit_code, out = helpers.run(TOOL, ["--root", str(root)])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("CR1", out)
        self.assertIn("big", out)

    def test_new_branchy_function_fails_cr1(self):
        with helpers.scratch() as root:
            helpers.write(root, "scenes/a.gd", branchy_func())
            exit_code, out = helpers.run(TOOL, ["--root", str(root)])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("CR1", out)
        self.assertIn("tangled", out)

    def test_baselined_function_passes_until_it_grows(self):
        with helpers.scratch() as root:
            helpers.write(root, "sim/a.gd", long_func())
            found_code, found = helpers.run(TOOL, ["--root", str(root)])
            self.assertEqual(found_code, 1, found)
            # 45 body lines + the func line = 46 lines, cc 1
            helpers.write(root, BASELINE, "# header\nsim/a.gd::big 46 1\n")
            ok_code, ok_out = helpers.run(TOOL, ["--root", str(root)])
            self.assertEqual(ok_code, 0, ok_out)
            helpers.write(root, "sim/a.gd", long_func(body_lines=50))
            grew_code, grew_out = helpers.run(TOOL, ["--root", str(root)])
        self.assertEqual(grew_code, 1, grew_out)
        self.assertIn("CR2", grew_out)

    def test_stale_baseline_row_fails_cr3_and_shrink_drops_it(self):
        with helpers.scratch() as root:
            helpers.write(root, "sim/a.gd", "func small() -> void:\n\tprint(1)\n")
            helpers.write(root, BASELINE, "# header\nsim/a.gd::small 46 1\n")
            exit_code, out = helpers.run(TOOL, ["--root", str(root)])
            self.assertEqual(exit_code, 1, out)
            self.assertIn("CR3", out)
            shrink_code, shrink_out = helpers.run(TOOL, ["--root", str(root), "--shrink"])
            self.assertEqual(shrink_code, 0, shrink_out)
            after_code, after_out = helpers.run(TOOL, ["--root", str(root)])
        self.assertEqual(after_code, 0, after_out)

    def test_text_in_strings_and_comments_is_not_code(self):
        body = 'func quiet() -> String:\n\t# if a and b or c: this is a comment\n\treturn "if x and y or z"\n'
        with helpers.scratch() as root:
            helpers.write(root, "autoload/a.gd", body)
            exit_code, out = helpers.run(TOOL, ["--root", str(root)])
        self.assertEqual(exit_code, 0, out)


if __name__ == "__main__":
    unittest.main()
