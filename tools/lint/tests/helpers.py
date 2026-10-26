"""Shared helpers for the smoke tests of the Python tools CI and prepush run (debt row 12, D-295).

Every test builds a tiny scratch project in a temp folder, runs the real tool on it as a subprocess
(the way CI and prepush do) and checks the exit code and the rule names it prints. No Godot, no git
history of this repo: the tools run on the scratch tree.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def tool(*parts):
    return str(REPO.joinpath(*parts))


def write(root, rel, text):
    """Writes text (LF endings) to root/rel, creating folders."""
    path = Path(root) / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.encode("utf-8"))
    return path


def run(script, args=(), cwd=None, stdin=None, env=None, isolated=True):
    """Runs a python tool; returns (exit code, stdout + stderr). isolated=False lets it import installed packages."""
    full_env = dict(os.environ)
    full_env.update(env or {})
    done = subprocess.run(
        [sys.executable, *(["-I"] if isolated else []), script, *args],
        cwd=cwd,
        input=stdin,
        capture_output=True,
        text=True,
        env=full_env,
    )
    return done.returncode, done.stdout + done.stderr


def copy_tool(root, *parts):
    """Copies a tool of this repo into root at the same relative path (LF endings); returns the new path.

    Some tools find their project root from their own location, so a scratch project needs its own copy.
    """
    dest = Path(root).joinpath(*parts)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(REPO.joinpath(*parts).read_bytes().replace(b"\r\n", b"\n"))
    return dest


def run_bash(script, args=(), cwd=None, env=None):
    """Runs a bash script (a path relative to cwd); returns (exit code, stdout + stderr). Needs bash on PATH."""
    full_env = dict(os.environ)
    full_env.update(env or {})
    done = subprocess.run(
        [shutil.which("bash"), script, *args], cwd=cwd, capture_output=True, text=True, env=full_env
    )
    return done.returncode, done.stdout + done.stderr


def scratch():
    """A temp folder object: use as `with scratch() as root:` (root is a Path)."""

    class _Scratch:
        def __enter__(self):
            self._dir = tempfile.TemporaryDirectory()
            return Path(self._dir.name)

        def __exit__(self, *exc):
            self._dir.cleanup()

    return _Scratch()
