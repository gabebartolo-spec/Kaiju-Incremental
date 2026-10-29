"""Smoke test for tools/pck_check.py (tools/export_windows.sh and build.yml run it on the exported game).

Writes a tiny Godot pack (format version 2, the layout read_pack parses) around a scratch checkout and
checks the tool passes a pack that holds the real fonts and kaiju models, and fails, by message, when
a font is a Git LFS pointer, when a model is missing from the pack, and when a dev tool ships in it.
"""

import contextlib
import hashlib
import io
import os
import struct
import sys
import unittest
from pathlib import Path

import helpers

def load_tool():
    import importlib.util

    spec = importlib.util.spec_from_file_location("pck_check", helpers.tool("tools", "pck_check.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


TTF = b"\x00\x01\x00\x00" + b"FONTDATA" * 600
KVOX = b"KVOX-bytes-" * 20
KCLIP = b"KCLIP-bytes-" * 20
LFS = b"version https://git-lfs.github.com/spec/v1\noid sha256:00\nsize 1\n"


def make_pack(files):
    """The bytes of a version-2 Godot pack holding {res path: bytes}: header, directory, then the data."""
    header = struct.pack("<4sIIIIIQ", b"GDPC", 2, 4, 7, 2, 0, 0) + b"\x00" * 64
    paths = {name: ("res://" + name).encode() for name in files}
    directory_size = 4 + sum(4 + len(raw) + 8 + 8 + 16 + 4 for raw in paths.values())
    directory = struct.pack("<I", len(files))
    body = b""
    for name, blob in files.items():
        offset = len(header) + directory_size + len(body)
        directory += struct.pack("<I", len(paths[name])) + paths[name]
        directory += struct.pack("<QQ", offset, len(blob)) + hashlib.md5(blob).digest() + struct.pack("<I", 0)
        body += blob
    return header + directory + body


def checkout(root, font=TTF):
    (Path(root) / "assets/fonts").mkdir(parents=True, exist_ok=True)
    (Path(root) / "assets/fonts/kaiju_test.ttf").write_bytes(font)
    (Path(root) / "assets/kaiju").mkdir(parents=True, exist_ok=True)
    (Path(root) / "assets/kaiju/reptilian_adult.kvox").write_bytes(KVOX)
    (Path(root) / "assets/kaiju/reptilian_adult.kclip").write_bytes(KCLIP)


def good_pack_files():
    return {
        ".godot/imported/kaiju_test.ttf-abc.fontdata": TTF,
        "assets/kaiju/reptilian_adult.kvox": KVOX,
        "assets/kaiju/reptilian_adult.kclip": KCLIP,
    }


def run_check(root, pack_files):
    tool = load_tool()
    pack = Path(root) / "game.pck"
    pack.write_bytes(make_pack(pack_files))
    out = io.StringIO()
    old_cwd, old_argv = os.getcwd(), sys.argv
    os.chdir(root)
    sys.argv = ["pck_check.py", str(pack)]
    try:
        with contextlib.redirect_stdout(out):
            try:
                tool.main()
                code = 0
            except SystemExit as e:
                code = e.code if isinstance(e.code, int) else 1
    finally:
        os.chdir(old_cwd)
        sys.argv = old_argv
    return code, out.getvalue()


class PckCheckSmoke(unittest.TestCase):
    def test_read_pack_round_trips(self):
        tool = load_tool()
        with helpers.scratch() as root:
            pack = Path(root) / "p.pck"
            pack.write_bytes(make_pack({"a/b.txt": b"hello", "c.bin": b"\x00\x01"}))
            files = tool.read_pack(pack)
        self.assertEqual(files, {"a/b.txt": b"hello", "c.bin": b"\x00\x01"})

    def test_good_pack_passes(self):
        with helpers.scratch() as root:
            checkout(root)
            code, out = run_check(root, good_pack_files())
        self.assertEqual(code, 0, out)
        self.assertIn("pack check passed", out)

    def test_lfs_pointer_font_fails(self):
        with helpers.scratch() as root:
            checkout(root, font=LFS)
            code, out = run_check(root, good_pack_files())
        self.assertEqual(code, 1, out)
        self.assertIn("not a real font", out)

    def test_lfs_pointer_model_fails(self):
        with helpers.scratch() as root:
            checkout(root)
            (Path(root) / "assets/kaiju/reptilian_adult.kvox").write_bytes(LFS)
            files = good_pack_files()
            files["assets/kaiju/reptilian_adult.kvox"] = LFS
            code, out = run_check(root, files)
        self.assertEqual(code, 1, out)
        self.assertIn("Git LFS pointer", out)

    def test_model_missing_from_pack_fails(self):
        with helpers.scratch() as root:
            checkout(root)
            files = good_pack_files()
            del files["assets/kaiju/reptilian_adult.kvox"]
            code, out = run_check(root, files)
        self.assertEqual(code, 1, out)
        self.assertIn("not in the pack", out)

    def test_dev_tool_in_pack_fails(self):
        with helpers.scratch() as root:
            checkout(root)
            files = good_pack_files()
            files["tools/capture/capture_kit.gd"] = b"extends Node"
            code, out = run_check(root, files)
        self.assertEqual(code, 1, out)
        self.assertIn("dev tool files in the pack", out)

    def test_not_a_pack_fails(self):
        tool = load_tool()
        with helpers.scratch() as root:
            junk = Path(root) / "junk.exe"
            junk.write_bytes(b"MZ" + b"\x00" * 64)
            with self.assertRaises(SystemExit) as caught:
                tool.read_pack(junk)
        self.assertIn("no Godot pack", str(caught.exception))


if __name__ == "__main__":
    unittest.main()
