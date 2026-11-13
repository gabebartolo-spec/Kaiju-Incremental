#!/usr/bin/env python3
"""Builds the Unity demo zip (U5; the Unity port of tools/build_release.py): build, stage into dist/, zip.

The steps of tools/export_windows.sh --release, for the Unity player: the licence register with no DEV ONLY
files, git lfs pull (the fonts the build copies are LFS), the slice bake (tools/unity/bake_slice.sh with the croc
from --croc or KAIJU_CROC, so the git-ignored StreamingAssets/slice/ the rampage reads matches this checkout's
data), then the Unity batch build the lead runs
(SliceBuild.BuildRampage), whose log must say "rampage: build Succeeded" and hold no "error CS". The player in
unity/Build (KaijuRampage.exe, its _Data folder and the Unity runtime beside it; the U4 slice player and the
Burst DoNotShip folders are left out) is copied into dist/KaijuEvolution-<version>-windows-unity/ and zipped to
dist/KaijuEvolution-<version>-windows-unity.zip. The version is config/version in project.godot, where
tools/build_release.py reads it; the build gets it as -kaijuVersion and writes it to res/version.txt, which the
player's feedback report reads (stage checks the two match). dist/ is git-ignored.

    KAIJU_CROC=<dir>/reptilian_adult python tools/unity/build_release.py   # bake, build, stage, zip
    python tools/unity/build_release.py --skip-build    # stage and zip an existing unity/Build
    UNITY=/path/to/Unity.exe python tools/unity/build_release.py

No upload: this script never pushes to itch.io (an upload needs the director's yes).
Exit 0 on success, nonzero on any failure.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UNITY = os.environ.get("UNITY", r"C:\Program Files\Unity\Hub\Editor\6000.3.23f1\Editor\Unity.exe")
EXE = "KaijuRampage.exe"
DATA = "KaijuRampage_Data"
# The Unity runtime every Windows player needs beside its exe.
RUNTIME = "UnityPlayer.dll"
# The data the build bundles (SliceBuild.BuildRampage); without it the game cannot boot.
BUNDLED = os.path.join(DATA, "StreamingAssets", "res", "data")
# The version the build writes for the player's feedback report (SliceBuild.BuildRampage, FeedbackReport.BuildVersion).
VERSION_TXT = os.path.join(DATA, "StreamingAssets", "res", "version.txt")
VERSION_ARG = "-kaijuVersion"
# The slice the rampage loads (RampageGame, Croc, CreationLabView); git-ignored, written by bake_slice.sh.
SLICE = os.path.join(DATA, "StreamingAssets", "slice")
SLICE_FILES = ("slice.json", "croc_adult.rig.json", "croc_adult.vskin", "croc_adult.kclip", "buildings.bin",
               "far_beast.rig.json", "far_beast.vskin")
# Other exes in unity/Build that are not the game's: only the crash handler ships.
SHIPPED_EXES = (EXE, "UnityCrashHandler64.exe")
LOG = os.path.join("unity", "Logs-release.txt")
SUCCEEDED = "rampage: build Succeeded"
COMPILE_ERROR = "error CS"


def project_version(root: str) -> str:
    """config/version from project.godot (e.g. 0.1-demo), as tools/build_release.py reads it."""
    with open(os.path.join(root, "project.godot"), encoding="utf-8") as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.MULTILINE)
    if not m:
        sys.exit("FAIL: no config/version in project.godot")
    return m.group(1)


def run(cmd: list, root: str, what: str) -> None:
    print("== " + what)
    code = subprocess.call(cmd, cwd=root)
    if code != 0:
        sys.exit(f"FAIL: {what} exited {code}")


def check_log(path: str) -> None:
    """The build log says the player was built and no script failed to compile."""
    if not os.path.isfile(path):
        sys.exit(f"FAIL: no build log at {path}")
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().splitlines()
    errors = [line for line in lines if COMPILE_ERROR in line]
    if errors:
        sys.exit(f"FAIL: {len(errors)} compile errors in {path}, first: {errors[0].strip()}")
    if not any(SUCCEEDED in line for line in lines):
        sys.exit(f"FAIL: {path} never says '{SUCCEEDED}'")
    print(f"{path}: {SUCCEEDED}, no compile errors")


def build(root: str, croc: str, version: str) -> None:
    """The release checks, the slice bake, then the Unity batch build (needs bash, git lfs, dotnet and Unity)."""
    if not croc:
        sys.exit("FAIL: no croc for the slice bake (pass --croc=<dir>/reptilian_adult or set KAIJU_CROC)")
    run([sys.executable, "tools/lint/licence_register.py", "--release"], root, "licence register (release: no DEV ONLY files)")
    run(["git", "lfs", "pull"], root, "git lfs pull")
    run(["bash", "tools/unity/bake_slice.sh", os.path.abspath(croc)], root, "slice bake (tools/unity/bake_slice.sh)")
    if not os.path.isfile(UNITY):
        sys.exit(f"FAIL: no Unity at {UNITY} (set UNITY)")
    log = os.path.join(root, LOG)
    if os.path.exists(log):
        os.remove(log)
    cmd = [UNITY, "-batchmode", "-quit", "-projectPath", "unity", "-executeMethod", "SliceBuild.BuildRampage", "-logFile", log, VERSION_ARG, version]
    print("== " + " ".join(cmd))
    code = subprocess.call(cmd, cwd=root)
    check_log(log)
    if code != 0:
        sys.exit(f"FAIL: the Unity build exited {code}")


def shipped(name: str) -> bool:
    """True for an entry of unity/Build that goes into the release."""
    if "DoNotShip" in name:
        return False
    if name.lower().endswith(".exe"):
        return name in SHIPPED_EXES
    if name.endswith("_Data"):
        return name == DATA
    return True


def stage(root: str, version: str) -> str:
    """Copies the player into dist/<name>/ and zips it; returns the zip path."""
    src = os.path.join(root, "unity", "Build")
    needs = [EXE, RUNTIME, BUNDLED, VERSION_TXT] + [os.path.join(SLICE, f) for f in SLICE_FILES]
    for need in needs:
        path = os.path.join(src, need)
        if not os.path.exists(path) or (os.path.isfile(path) and os.path.getsize(path) == 0):
            hint = "run tools/unity/bake_slice.sh <croc>, then build" if SLICE in need else "run without --skip-build"
            sys.exit(f"FAIL: no {path} ({hint})")
    with open(os.path.join(src, VERSION_TXT), encoding="utf-8") as f:
        bundled = f.read().strip()
    if bundled != version:
        sys.exit(f"FAIL: {VERSION_TXT} says {bundled!r}, project_version() says {version!r} (run without --skip-build)")
    name = f"KaijuEvolution-{version}-windows-unity"
    dist = os.path.join(root, "dist")
    folder = os.path.join(dist, name)
    shutil.rmtree(folder, ignore_errors=True)
    os.makedirs(folder)
    entries = sorted(e for e in os.listdir(src) if shipped(e))
    for e in entries:
        path = os.path.join(src, e)
        if os.path.isdir(path):
            shutil.copytree(path, os.path.join(folder, e))
        else:
            shutil.copy2(path, folder)
    zpath = folder + ".zip"
    if os.path.exists(zpath):
        os.remove(zpath)
    count = 0
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for here, dirs, files in os.walk(folder):
            dirs.sort()
            for f in sorted(files):
                full = os.path.join(here, f)
                z.write(full, f"{name}/" + os.path.relpath(full, folder).replace(os.sep, "/"))
                count += 1
    print(f"{zpath}: {os.path.getsize(zpath)} bytes, {count} files ({', '.join(entries)})")
    return zpath


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--skip-build", action="store_true", help="stage an existing unity/Build")
    ap.add_argument("--croc", default=os.environ.get("KAIJU_CROC", ""), help="<dir>/reptilian_adult for the slice bake (default KAIJU_CROC)")
    args = ap.parse_args()
    version = project_version(ROOT)
    if not args.skip_build:
        build(ROOT, args.croc, version)
    stage(ROOT, version)
    return 0


if __name__ == "__main__":
    sys.exit(main())
