#!/usr/bin/env python3
"""Runs, locally, the checks a change touches before a push (D-403), not instead of CI. Unity only (U6, D-484).

A change to the sim side (UNITY_SIM: the C# sim and its checks, the native DLL, the slice bake, data/) runs
unity/SimTests under dotnet, as sim-csharp does (SIM_NATIVE=off when the DLL is not built). A change to the view
code is typechecked by tools/lint/push_gate.sh (tools/unity/typecheck.sh); anything else is reported and left to CI.

    python tools/run_touched.py                 # vs origin/main
    python tools/run_touched.py --list          # say what would run, run nothing
    python tools/run_touched.py --base <ref>    # vs another base
"""
import os
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
UNITY_SIM = ("unity/SimTests/", "unity/Assets/Scripts/Sim/", "unity/Assets/Scripts/GameLogic/", "unity/native/",
             "tools/unity/slicebake/", "data/")
DLL = "unity/Assets/Plugins/x86_64/kaiju_core.dll"


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, cwd=ROOT, check=True).stdout


def changed(base: str) -> list[str]:
    merge_base = git("merge-base", base, "HEAD").strip()
    paths = set(git("diff", "--name-only", merge_base).split())
    return sorted(p for p in paths if not p.startswith("docs/") and not p.endswith(".md"))


def main(argv: list[str]) -> int:
    base = argv[argv.index("--base") + 1] if "--base" in argv else "origin/main"
    paths = changed(base)
    sim = [p for p in paths if p.startswith(UNITY_SIM)]
    rest = [p for p in paths if p not in sim]
    print(f"{len(paths)} changed files; sim side: {len(sim)}")
    if rest:
        print(f"Not run here ({len(rest)}; push_gate and CI cover these): {' '.join(rest[:8])}{' ...' if len(rest) > 8 else ''}")
    if "--list" in argv or not sim:
        return 0
    sys.stdout.flush()
    native = "on" if os.path.exists(os.path.join(ROOT, DLL)) else "off"
    cmd = ["dotnet", "run", "--project", "unity/SimTests", "-c", "Release"]
    return subprocess.run(cmd, cwd=ROOT, env={**os.environ, "SIM_NATIVE": native}, check=False).returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
