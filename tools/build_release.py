#!/usr/bin/env python3
"""Builds the Itch demo zip (roadmap M4): export, stage into dist/, zip, optional butler push.

The export itself is tools/export_windows.sh --release: licence register with no DEV ONLY files,
git lfs pull, headless import, `godot --headless --export-release "Windows Desktop"`, then
tools/pck_check.py. This script reuses it (one export path for agents, CI and releases), then
copies the exe and the native DLL into dist/KaijuEvolution-<version>-windows/ and zips that to
dist/KaijuEvolution-<version>-windows.zip. dist/ is git-ignored.

    GODOT=/path/to/godot_console.exe python tools/build_release.py
    python tools/build_release.py --skip-export   # stage and zip an existing out/windows build

Butler push (itch.io upload) is OFF by default and is never run by agents: an upload needs the
director's yes. It runs only with --push <user/game> and BUTLER_API_KEY set in the environment
(butler reads it itself; never pass the key on the command line):

    python tools/build_release.py --skip-export --push <itch-user>/<game>   # channel windows

Exit 0 on success, nonzero on any failure.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "out", "windows")
DIST = os.path.join(ROOT, "dist")
EXE = "KaijuEvolution.exe"


def project_version() -> str:
    """config/version from project.godot (e.g. 0.1-demo)."""
    with open(os.path.join(ROOT, "project.godot"), encoding="utf-8") as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.MULTILINE)
    if not m:
        sys.exit("FAIL: no config/version in project.godot")
    return m.group(1)


def export() -> None:
    """Runs the release export through tools/export_windows.sh (needs bash on PATH)."""
    code = subprocess.call(["bash", "tools/export_windows.sh", "--release"], cwd=ROOT)
    if code != 0:
        sys.exit(f"FAIL: tools/export_windows.sh --release exited {code}")


def stage(version: str) -> str:
    """Copies the exe and its DLLs into dist/<name>/ and zips it; returns the zip path."""
    exe = os.path.join(OUT, EXE)
    if not os.path.isfile(exe) or os.path.getsize(exe) == 0:
        sys.exit(f"FAIL: no {exe} (run without --skip-export)")
    name = f"KaijuEvolution-{version}-windows"
    folder = os.path.join(DIST, name)
    shutil.rmtree(folder, ignore_errors=True)
    os.makedirs(folder)
    files = [EXE] + sorted(f for f in os.listdir(OUT) if f.lower().endswith(".dll"))
    if len(files) == 1:
        sys.exit(f"FAIL: no native DLL next to {exe}; the exe logs an error without it")
    for f in files:
        shutil.copy2(os.path.join(OUT, f), folder)
    zpath = folder + ".zip"
    if os.path.exists(zpath):
        os.remove(zpath)
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            z.write(os.path.join(folder, f), f"{name}/{f}")
    print(f"{zpath}: {os.path.getsize(zpath)} bytes ({', '.join(files)})")
    return folder


def push(folder: str, target: str, version: str) -> None:
    """butler push <folder> <target>:windows. Only with --push; needs BUTLER_API_KEY."""
    if not os.environ.get("BUTLER_API_KEY"):
        sys.exit("FAIL: --push needs BUTLER_API_KEY in the environment")
    if shutil.which("butler") is None:
        sys.exit("FAIL: butler is not on PATH")
    cmd = ["butler", "push", folder, f"{target}:windows", "--userversion", version]
    print("== " + " ".join(cmd))
    code = subprocess.call(cmd)
    if code != 0:
        sys.exit(f"FAIL: butler push exited {code}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument(
        "--skip-export", action="store_true", help="stage an existing out/windows build"
    )
    ap.add_argument(
        "--push",
        metavar="USER/GAME",
        default="",
        help="butler push target (off by default)",
    )
    args = ap.parse_args()
    version = project_version()
    if not args.skip_export:
        export()
    folder = stage(version)
    if args.push:
        push(folder, args.push, version)
    return 0


if __name__ == "__main__":
    sys.exit(main())
