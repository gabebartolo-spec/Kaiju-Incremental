"""Smoke test for the C# part of tools/lint/tuning_keys.py (U6 C6; tests.yml preflight, push_gate).

Green when hand-written C# reads only keys the data holds; red, with rule TK1 and the key's name, on a
misspelt key in a Content.Section chain or a *Cfg read and on a missing section. Comments and gd2cs output
(Sim/Game) are not read.
"""

import json
import unittest

import helpers

TOOL = helpers.tool("tools", "lint", "tuning_keys.py")
VIEW = "unity/Assets/Scripts/Rampage/Reader.cs"


def project(root, code, extra=None):
    helpers.write(root, "data/tuning.json", json.dumps({"stomp": {"damage": 5, "fx": {"sound": "a"}}, "fire": {"spread": 1}}))
    helpers.write(root, VIEW, code)
    for path, text in (extra or {}).items():
        helpers.write(root, path, text)


def reader(*lines):
    return "class Reader\n{\n    void Read()\n    {\n" + "".join("        %s\n" % x for x in lines) + "    }\n}\n"


class CsTuningKeysSmoke(unittest.TestCase):
    def check(self, code, extra=None):
        with helpers.scratch() as root:
            project(root, code, extra)
            return helpers.run(TOOL, ["--root", str(root)])

    def test_known_keys_pass(self):
        code = reader(
            'S.GDict fx = S.Content.Section("stomp")["fx"];',
            'S.GDict stompCfg = S.Content.Section("stomp");',
            'double d = S.Num.F(stompCfg["damage"]) + S.Num.F(S.Content.Tuning()["fire"]["spread"]);',
            '// cfg["not_a_key"] is only discussed here',
        )
        exit_code, out = self.check(code, {"unity/Assets/Scripts/Sim/Game/Gen.cs": reader('var x = cfg["gen_only"];')})
        self.assertEqual(exit_code, 0, out)
        self.assertIn("ok:", out)

    def test_misspelt_section_chain_key_fails(self):
        exit_code, out = self.check(reader('S.GDict fx = S.Content.Section("stomp")["fxx"];'))
        self.assertEqual(exit_code, 1, out)
        self.assertIn("TK1", out)
        self.assertIn("fxx", out)
        self.assertIn("Reader.cs:5", out.replace("\\", "/"))

    def test_misspelt_cfg_key_fails(self):
        exit_code, out = self.check(reader('double d = S.Num.F(stompCfg["dmage"]);'))
        self.assertEqual(exit_code, 1, out)
        self.assertIn("dmage", out)

    def test_missing_section_fails(self):
        exit_code, out = self.check(reader('S.GDict x = S.Content.Section("nonesuch");'))
        self.assertEqual(exit_code, 1, out)
        self.assertIn("nonesuch", out)


if __name__ == "__main__":
    unittest.main()
