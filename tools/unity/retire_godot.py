#!/usr/bin/env python3
"""U6's Godot retirement (D-484), as a plan only: which tracked files leave main, which kept files still read them
(the blockers to cut first), and the exact command sequence. It never deletes, tags or pushes anything: it prints.

    python tools/unity/retire_godot.py              # counts per top folder, the blockers, the commands
    python tools/unity/retire_godot.py --list       # every path that leaves main, one per line
    python tools/unity/retire_godot.py --blockers   # kept files that name a leaving path (exit 1 if any)

A file leaves when it is Godot's: a Godot file type anywhere outside unity/, a Godot-only folder, or a tool named in
GODOT_TOOLS. Everything else stays (data/, assets/ media, docs/, unity/, the Python asset pipelines).
"""
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ARCHIVE = "godot-final"  # the branch and the tag Godot's last main is kept under
# Godot's own file types; Unity has none of them.
GODOT_EXT = (".gd", ".uid", ".tscn", ".tres", ".import", ".gdshader", ".gdshaderinc", ".gdextension", ".godot")
# Folders only the Godot game uses (the GDExtension and its godot-cpp submodule, the scenes, the GDScript sim the
# C# was generated from, the GDScript suites, Godot's capture rig, the speed-run pacing).
GODOT_DIRS = ("autoload/", "native/", "scenes/", "sim/", "tests/", "tools/capture/", "tools/bench/")
# Root files and tools that only drive Godot (its tests, CI shards, export, pack and lints of GDScript).
GODOT_TOOLS = {
    "project.godot", "export_presets.cfg", ".gdlintrc", ".gitmodules",
    "tools/run_tests.sh", "tools/test_run_tests.sh", "tools/plan_ci_shards.sh", "tools/test_plan_ci_shards.sh",
    "tools/ci_timings.txt", "tools/ci_retime.py", "tools/ci_select_suites.py", "tools/ci_reuse_dispatch_run.sh",
    "tools/ci_reuse_pr_run.sh", "tools/check_scripts.sh", "tools/export_windows.sh", "tools/build_release.py",
    "tools/pck_check.py", "tools/native_dll.sh", "tools/speed_gate.sh", "tools/sim_leak_probe.gd",
    "tools/unity/gd2cs.py", "tools/unity/regen_sim.sh", "tools/prepush.sh", "tools/triage.py", "tools/wt_setup.sh",
    "tools/lint/prepush_picks.py", "tools/lint/selftest_prepush_picks.sh", "tools/lint/tests/test_prepush_picks.py",
    "tools/lint/tests/test_prepush_guard.py", "tools/lint/tests/test_plan_ci_shards.py",
    "tools/lint/tests/test_pck_check.py", "tools/lint/tests/test_complexity_ratchet.py",
    "tools/lint/check_uids.sh", "tools/lint/selftest_uids.sh", "tools/lint/log_smoke.sh",
    "tools/lint/selftest_log_smoke.sh", "tools/lint/complexity_ratchet.py", "tools/lint/complexity_baseline.txt",
    "tools/lint/check_thread_resources.sh", "tools/lint/selftest_thread_resources.sh",
    "tools/lint/thread_resources.py",
    ".github/workflows/tests.yml", ".github/workflows/build.yml", ".github/workflows/release.yml",
    ".github/workflows/capture.yml", ".github/workflows/pacing.yml", ".github/workflows/native-cache.yml",
}
GODOT_DIRS += (".github/actions/native-build/", ".github/actions/setup-godot/")
# A kept file that names a leaving path is a blocker, except prose: docs and READMEs may name history.
PROSE = re.compile(r"(^docs/|\.md$)")
TEXT = (".py", ".sh", ".cs", ".yml", ".yaml", ".json", ".txt", ".cfg", ".toml", ".bat", ".cpp", ".h", ".csproj",
        ".props", ".asmdef")
PATHLIKE = re.compile(r"(?:res://)?([A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)+/?|project\.godot)")
STRING = re.compile(r'"(?:[^"\\\n]|\\.)*"' + r"|'(?:[^'\\\n]|\\.)*'")
# Comments are provenance ("ported from scenes/x.gd"), not reads: only code counts. In C-like and Python files
# a path must sit in a string literal; in shell, YAML and the rest, on a line that is not a comment.
QUOTED = (".py", ".cs", ".cpp", ".h", ".json", ".csproj", ".props", ".asmdef")


def code_text(path: str, body: str) -> str:
    if path.endswith(QUOTED):
        if path.endswith(".py"):
            body = re.sub(r'"""[\s\S]*?"""', "", body)
        if path.endswith((".csproj", ".props")):
            body = re.sub(r"<!--[\s\S]*?-->", "", body)
        if path.endswith((".cs", ".cpp", ".h")):
            body = "\n".join(line.split("//", 1)[0] if '"' not in line else line for line in body.split("\n"))
        return "\n".join(STRING.findall(body))
    lines = [re.split(r"(?:^|\s)(?:#|rem\s|::)", line, maxsplit=1)[0] for line in body.split("\n")]
    return "\n".join(lines)


def tracked() -> list[str]:
    out = subprocess.run(["git", "ls-files", "-z"], capture_output=True, text=True, cwd=ROOT, check=True).stdout
    return [p for p in out.split("\0") if p]


def leaves(path: str) -> bool:
    if path.startswith("unity/"):
        return False
    return path in GODOT_TOOLS or path.startswith(GODOT_DIRS) or path.endswith(GODOT_EXT)


def blockers(paths: list[str], gone: set[str]) -> dict[str, list[str]]:
    """Kept code that names a leaving file or folder: each must be cut before the switch."""
    gone_dirs = {d.rstrip("/") for d in GODOT_DIRS}
    found: dict[str, list[str]] = {}
    for p in paths:
        if p in gone or PROSE.search(p) or not p.endswith(TEXT) or p.startswith("tools/lint/tests/fixtures"):
            continue
        try:
            with open(os.path.join(ROOT, p), encoding="utf-8", errors="replace") as fh:
                body = fh.read()
        except OSError:
            continue
        body = code_text(p, body)
        hits = sorted({m for m in PATHLIKE.findall(body) if m in gone or m.rstrip("/") in gone_dirs})
        if hits:
            found[p] = hits
    return found


COMMANDS = f"""\
# Run only after the director rules U6 passed (D-484). From a clean checkout of origin/main:
git fetch origin && git switch -c claude/retire-godot origin/main
git tag -a {ARCHIVE} -m "Godot's last main before the Unity switch (D-484)" origin/main
git push origin refs/tags/{ARCHIVE} && git push origin origin/main:refs/heads/archive/{ARCHIVE}
python tools/unity/retire_godot.py --blockers   # must print none (cut each one in this branch first)
python tools/unity/retire_godot.py --list | git rm -r --quiet --pathspec-from-file=-
git submodule deinit -f native/godot-cpp 2>/dev/null; rm -rf .git/modules/native/godot-cpp
# then: the Unity-only CLAUDE.md, run_touched.py, lint.yml and unity.yml from the rules branch; required checks
# test -> drop, sim-csharp stays (gh api -X PATCH repos/<owner>/<repo>/branches/main/protection/required_status_checks)
git commit -m "U6: Godot leaves main; its last main is tag {ARCHIVE} (D-484)" && git push -u origin claude/retire-godot
"""


def main(argv: list[str]) -> int:
    paths = tracked()
    gone = {p for p in paths if leaves(p)}
    if "--list" in argv:
        print("\n".join(sorted(gone)))
        return 0
    found = blockers(paths, gone)
    if "--blockers" in argv:
        for p, hits in sorted(found.items()):
            print(f"{p}: {' '.join(hits[:6])}{' ...' if len(hits) > 6 else ''}")
        return 1 if found else 0
    tops: dict[str, int] = {}
    for p in gone:
        top = p.split("/")[0] + ("/" if "/" in p else "")
        tops[top] = tops.get(top, 0) + 1
    print(f"{len(gone)} of {len(paths)} tracked files leave main:")
    for top, n in sorted(tops.items(), key=lambda t: -t[1]):
        print(f"  {n:5d}  {top}")
    print(f"{len(found)} kept files still name a leaving path (--blockers lists them)")
    print()
    print(COMMANDS)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
