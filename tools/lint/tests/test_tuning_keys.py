"""Smoke test for tools/lint/tuning_keys.py (tests.yml preflight and tools/prepush.sh step 2).

Green on a scratch project whose code reads only keys the data holds; red, with rule TK1 and the
key's name, on a misspelt key and on a section that does not exist.
"""

import json
import unittest

import helpers

TOOL = helpers.tool("tools", "lint", "tuning_keys.py")


def project(root, code):
    helpers.write(root, "data/tuning.json", json.dumps({"stomp": {"damage": 5, "radius": 2}, "fire": {"spread": 1}}))
    helpers.write(root, "data/species.json", json.dumps({"reptilian": {"hp": 100}}))
    helpers.write(root, "sim/reader.gd", code)


class TuningKeysSmoke(unittest.TestCase):
    def test_known_keys_pass(self):
        code = (
            "func read() -> float:\n"
            '\tvar cfg: Dictionary = Content.section("stomp")\n'
            '\tvar spread: float = Content.tuning()["fire"]["spread"]\n'
            '\treturn float(cfg["damage"]) + float(cfg.get("radius", 0.0)) + spread\n'
        )
        with helpers.scratch() as root:
            project(root, code)
            exit_code, out = helpers.run(TOOL, ["--root", str(root)])
        self.assertEqual(exit_code, 0, out)
        self.assertIn("ok:", out)

    def test_key_written_by_code_or_in_other_data_counts(self):
        code = (
            "func read(cfg: Dictionary) -> int:\n"
            '\tcfg["added_by_code"] = 3\n'
            '\treturn int(cfg["added_by_code"]) + int(cfg["reptilian"]["hp"])\n'
        )
        with helpers.scratch() as root:
            project(root, code)
            exit_code, out = helpers.run(TOOL, ["--root", str(root)])
        self.assertEqual(exit_code, 0, out)

    def test_misspelt_key_fails_by_name(self):
        code = (
            "func read() -> float:\n"
            '\tvar cfg: Dictionary = Content.section("stomp")\n'
            '\treturn float(cfg["dmage"])\n'
        )
        with helpers.scratch() as root:
            project(root, code)
            exit_code, out = helpers.run(TOOL, ["--root", str(root)])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("TK1", out)
        self.assertIn("dmage", out)
        self.assertIn("reader.gd:3", out.replace("\\", "/"))

    def test_missing_section_fails(self):
        code = 'func read() -> Dictionary:\n\treturn Content.section("nonesuch")\n'
        with helpers.scratch() as root:
            project(root, code)
            exit_code, out = helpers.run(TOOL, ["--root", str(root)])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("nonesuch", out)

    def test_comment_is_not_a_read(self):
        code = '# tuning["not_a_key"] is discussed here only\nfunc read() -> void:\n\tpass\n'
        with helpers.scratch() as root:
            project(root, code)
            exit_code, out = helpers.run(TOOL, ["--root", str(root)])
        self.assertEqual(exit_code, 0, out)


if __name__ == "__main__":
    unittest.main()
