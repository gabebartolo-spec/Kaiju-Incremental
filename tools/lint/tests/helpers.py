"""Shared helpers for the smoke tests of the Python tools CI and prepush run (debt row 12, D-295).

Every test builds a tiny scratch project in a temp folder, runs the real tool on it as a subprocess
(the way CI and prepush do) and checks the exit code and the rule names it prints. No Godot, no git
history of this repo: the tools run on the scratch tree.
"""

import os
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


def run(script, args=(), cwd=None, stdin=None, env=None):
    """Runs a python tool; returns (exit code, stdout + stderr)."""
    full_env = dict(os.environ)
    full_env.update(env or {})
    done = subprocess.run(
        [sys.executable, "-I", script, *args],
        cwd=cwd,
        input=stdin,
        capture_output=True,
        text=True,
        env=full_env,
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
