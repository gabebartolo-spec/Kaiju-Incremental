"""Smoke test for the C# part of tools/i18n/strings.py (U6 C5; run_all via check_i18n.sh, push_gate).

strings.py finds its project from its own location, so each test copies it into a scratch project with
empty data files. Green when every Tr.T / Tr.F literal has a row; red, naming the text, when one has none.
Tr.Format, comments and gd2cs output (Sim/Game) are not asked for.
"""

import unittest

import helpers

HEADER = "keys,en,es,fr,it,de,ru,zh_CN\n"
VIEW = "unity/Assets/Scripts/Game/Ui/Card.cs"
DATA = ["species.json", "continents.json", "upgrades.json", "looks.json", "tuning.json"]


def project(root, rows, code, extra=None):
    tool = helpers.copy_tool(root, "tools", "i18n", "strings.py")
    for name in DATA:
        helpers.write(root, "data/" + name, "{}")
    helpers.write(root, "data/i18n/strings.csv", HEADER + "".join("%s,%s,,,,,,\n" % (r, r) for r in rows))
    helpers.write(root, VIEW, code)
    for path, text in (extra or {}).items():
        helpers.write(root, path, text)
    return str(tool)


CODE = (
    "class Card\n{\n"
    '    string A() => Tr.T("PREVIEW");\n'
    '    string B(int n) => Tr.F("%d STOREYS", n);\n'
    '    string C(int n) => Tr.Format("not a key %d", n);\n'
    '    // Tr.T("ONLY IN A COMMENT")\n'
    "}\n"
)


class CsStringsSmoke(unittest.TestCase):
    def test_every_literal_has_a_row(self):
        with helpers.scratch() as root:
            tool = project(root, ["PREVIEW", "%d STOREYS"], CODE,
                           {"unity/Assets/Scripts/Sim/Game/Gen.cs": 'class G { string S() => Tr.T("GENERATED"); }\n'})
            exit_code, out = helpers.run(tool)
        self.assertEqual(exit_code, 0, out)

    def test_missing_row_fails_by_text(self):
        with helpers.scratch() as root:
            tool = project(root, ["%d STOREYS"], CODE)
            exit_code, out = helpers.run(tool)
        self.assertEqual(exit_code, 1, out)
        self.assertIn("missing row: 'PREVIEW'", out)
        self.assertNotIn("ONLY IN A COMMENT", out)
        self.assertNotIn("not a key", out)


if __name__ == "__main__":
    unittest.main()
