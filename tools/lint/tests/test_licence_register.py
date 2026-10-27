"""Smoke test for tools/lint/licence_register.py (lint.yml licence-register job and tools/prepush.sh step 2).

CLAUDE.md hard rule 5: every file under assets/ is covered by a CLEARED row of docs/LICENSING_REGISTER.md.
The tool finds its project root from its own location and lists files with `git ls-files`, so each test
copies it into a scratch git repo that holds a register and some asset files. Green when every file has a
CLEARED row; red, naming the file, on an uncovered file, a PENDING row, an orphan .import, a CLEARED row with
no source, and (with --release) on a DEV ONLY file even when a CLEARED glob also matches it.
"""

import subprocess
import unittest

import helpers

HEAD = "| Item | Path | Source | Licence | Status |\n|---|---|---|---|---|\n"
FONTS = "| Fonts | `assets/fonts/kaiju_*.ttf` | drawn by us in tools/fonts | Ours | CLEARED |\n"


def project(root, rows, files):
    """A scratch git repo with the tool, a register of `rows` and an empty file for each path in `files`."""
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    helpers.copy_tool(root, "tools", "lint", "licence_register.py")
    helpers.write(root, "docs/LICENSING_REGISTER.md", "# Register\n\n" + HEAD + rows)
    for rel in files:
        helpers.write(root, rel, "x")
    return str(root / "tools" / "lint" / "licence_register.py")


def check(rows, files, *args):
    with helpers.scratch() as root:
        tool = project(root, rows, files)
        return helpers.run(tool, args, cwd=root, env={"GITHUB_ACTIONS": ""})


class LicenceRegisterSmoke(unittest.TestCase):
    def test_every_file_covered_passes(self):
        exit_code, out = check(FONTS, ["assets/fonts/kaiju_a.ttf", "assets/fonts/kaiju_a.ttf.import"])
        self.assertEqual(exit_code, 0, out)
        self.assertIn("ok: 2 asset files", out)

    def test_uncovered_file_fails_by_name(self):
        exit_code, out = check(FONTS, ["assets/fonts/kaiju_a.ttf", "assets/sfx/planted.ogg"])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("assets/sfx/planted.ogg: no CLEARED row", out)
        self.assertIn("1 uncovered files", out)

    def test_pending_row_covers_nothing(self):
        rows = "| Music | `assets/music/**` | not yet licensed | n/a | PENDING |\n"
        exit_code, out = check(rows, ["assets/music/track.ogg"])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("assets/music/track.ogg", out)

    def test_import_file_without_its_source_fails(self):
        exit_code, out = check(FONTS, ["assets/fonts/kaiju_a.ttf.import"])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("its source file assets/fonts/kaiju_a.ttf is not in the tree", out)

    def test_cleared_row_without_source_or_licence_fails(self):
        rows = "| Fonts | `assets/fonts/*.ttf` | - | - | CLEARED |\n"
        exit_code, out = check(rows, ["assets/fonts/a.ttf"])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("has no Source or Licence", out)

    def test_dev_only_file_passes_but_fails_a_release(self):
        rows = "| Trial | `assets/trial/*.kclip` | Cascadeur Pro trial | trial, no commercial use | DEV ONLY |\n"
        files = ["assets/trial/roar.kclip"]
        exit_code, out = check(rows, files)
        self.assertEqual(exit_code, 0, out)
        self.assertIn("1 files are DEV ONLY", out)
        exit_code, out = check(rows, files, "--release")
        self.assertEqual(exit_code, 1, out)
        self.assertIn("DEV ONLY files in a release tree", out)

    def test_dev_only_row_beats_a_cleared_glob(self):
        rows = (
            "| Clips | `assets/clips/*.kclip` | our own keyed clips | Ours | CLEARED |\n"
            "| Trial clips | `assets/clips/trial_*.kclip` | Cascadeur Pro trial | trial, no commercial use | DEV ONLY |\n"
        )
        exit_code, out = check(rows, ["assets/clips/a.kclip", "assets/clips/trial_roar.kclip"], "--release")
        self.assertEqual(exit_code, 1, out)
        self.assertIn("1 files are DEV ONLY", out)
        self.assertIn("trial_roar.kclip", out)
        self.assertIn("DEV ONLY files in a release tree", out)

    def test_own_self_test_passes(self):
        exit_code, out = check(FONTS, [], "--self-test")
        self.assertEqual(exit_code, 0, out)
        self.assertIn("ok: a planted uncovered file", out)


if __name__ == "__main__":
    unittest.main()
