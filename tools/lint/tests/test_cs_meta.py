"""Smoke test for tools/lint/cs_meta.py (U6 C3; run_all via check_cs.sh, push_gate).

Builds a scratch git repo with a tiny unity/Assets: green when every tracked file and folder has its tracked
.meta; red, by rule, on a file without one (META-MISSING), a .meta left by an untracked folder (META-ORPHAN)
and two .meta files sharing a guid (META-DUP-GUID). The allowlisted kaiju_core.dll.meta passes alone.
"""

import subprocess
import unittest

import helpers

TOOL = helpers.tool("tools", "lint", "cs_meta.py")


def meta(guid):
    return "fileFormatVersion: 2\nguid: %s\n" % guid


def repo(root, files):
    """A git repo at root holding files, all added to the index."""
    for path, text in files.items():
        helpers.write(root, path, text)
    subprocess.run(["git", "init", "-q", str(root)], check=True)
    subprocess.run(["git", "-C", str(root), "-c", "core.autocrlf=false", "add", "-A"], check=True, capture_output=True)


def clean():
    return {
        "unity/Assets/Scripts.meta": meta("a1"),
        "unity/Assets/Scripts/Croc.cs": "class Croc {}\n",
        "unity/Assets/Scripts/Croc.cs.meta": meta("a2"),
        "unity/Assets/Plugins.meta": meta("a3"),
        "unity/Assets/Plugins/x86_64.meta": meta("a4"),
        "unity/Assets/Plugins/x86_64/kaiju_core.dll.meta": meta("a5"),
    }


class CsMetaSmoke(unittest.TestCase):
    def check(self, files):
        with helpers.scratch() as root:
            repo(root, files)
            return helpers.run(TOOL, ["--root", str(root)])

    def test_clean_tree_passes(self):
        exit_code, out = self.check(clean())
        self.assertEqual(exit_code, 0, out)

    def test_file_without_meta_fails(self):
        files = clean()
        files["unity/Assets/Scripts/Tail.cs"] = "class Tail {}\n"
        exit_code, out = self.check(files)
        self.assertEqual(exit_code, 1, out)
        self.assertIn("unity/Assets/Scripts/Tail.cs:0: [error] META-MISSING", out)

    def test_folder_without_meta_fails(self):
        files = clean()
        files["unity/Assets/Ui/Hud.cs"] = "class Hud {}\n"
        files["unity/Assets/Ui/Hud.cs.meta"] = meta("b1")
        exit_code, out = self.check(files)
        self.assertEqual(exit_code, 1, out)
        self.assertIn("unity/Assets/Ui:0: [error] META-MISSING", out)

    def test_meta_of_empty_folder_fails_orphan(self):
        files = clean()
        files["unity/Assets/Shaders.meta"] = meta("b2")
        exit_code, out = self.check(files)
        self.assertEqual(exit_code, 1, out)
        self.assertIn("unity/Assets/Shaders.meta:0: [error] META-ORPHAN", out)

    def test_shared_guid_fails(self):
        files = clean()
        files["unity/Assets/Scripts/Croc.cs.meta"] = meta("a1")
        exit_code, out = self.check(files)
        self.assertEqual(exit_code, 1, out)
        self.assertIn("META-DUP-GUID", out)


if __name__ == "__main__":
    unittest.main()
