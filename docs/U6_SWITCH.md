# U6: the switch to a Unity-only repo

Cap: 120 lines. The plan for U6 (ROADMAP "Unity port") apart from the director's playtest, which waits until U4 and
U5 are done (D-485). Nothing here deletes or tags anything: Godot stays the working game until the director rules
U6 passed; then Godot's last main goes to an archive tag and branch and its code leaves main (D-484).

## CI (done in #615)
The required `sim-csharp` job (unity.yml, windows-latest) gates the Unity side with no Unity licence: the C# sim
against Godot's golden logs with the DLL and with `SIM_NATIVE=off`, the DLL build (`unity/native/build.bat`), the
slice bake with no Godot (`tools/unity/bake_slice.sh`) and `check_core.py` on the bake's digests. The repo is public,
so standard runners cost nothing: no spend asked for.

| Step | Time on CI (#615) |
|---|---|
| setup (checkout, LFS, dotnet) | about 50 s |
| gd2cs `--check` | 15 s (leaves at the switch) |
| DLL build | 11 s |
| sim with the DLL / without | 56 s / 108 s |
| slice bake / check_core | 10 s / 5 s |
| whole job | 4 min 19 s (3 min 28 s before) |

Not in CI, and staying so: the Unity editor (view code, rendering). A Personal licence in Actions needs a Unity
login stored as secrets, which is the director's call; `tools/lint/push_gate.sh` typechecks the view code against the
local editor before every push (`tools/unity/typecheck.sh`). After the switch, `test` (tests.yml) leaves the
required checks; `sim-csharp`, `doc-caps` and `gitleaks` stay.

## What leaves main
`python tools/unity/retire_godot.py` gives the exact list from the tree as it is when run (`--list`); on 2026-11-13
it was 2,089 of 3,578 tracked files: scenes/ 777, tests/ 568, tools/ 354 (the .gd tools, tools/capture, tools/bench
and the Godot test, shard, export and pack scripts), sim/ 222 (the GDScript the C# sim was generated from), assets/
105 (`.import` files only; the media stay), autoload/ 26, native/ 24 (the GDExtension and godot-cpp), six Godot
workflows and two composite actions, project.godot, export_presets.cfg, .gdlintrc, .gitmodules and
`data/i18n/strings.csv.import`. data/, docs/, unity/ and the Python asset pipelines stay.

## Blockers to cut first
`python tools/unity/retire_godot.py --blockers` lists kept code that still reads a leaving file (exit 1 while any
remain). On 2026-11-13, 17 files; the U6 blocker PR cut all but these 7, which go in the switch PR itself:

| Kept file | Reads | Cut at the switch |
|---|---|---|
| .github/workflows/unity.yml | gd2cs `--check` | drop the step (on `claude/u6-unity-only-rules`) |
| tools/run_touched.py, tools/lint/push_gate.sh | run_tests.sh, GDScript lints | the Unity-only versions (on that branch) |
| unity/Assets/Scripts/GameLogic/FeedbackReport.cs, unity/SimTests/FeedbackCheck.cs (VersionSources) | project.godot, the version fallback after version.txt | drop the fallback and its checks together |
| unity/Assets/Editor/SliceBuild.cs | deletes an old build's stale res/project.godot | drop the two lines |
| unity/Assets/Scripts/Game/GraphicsView.cs | far_depth.gd in a warning | reword |

Cut by that PR: the version is a root `version.txt` (build_release.py, SliceBuild.cs, FeedbackCheck.Version;
`tools/lint/tests/test_godot_mirror.py` holds it equal to project.godot until then); slicebake finds the repo by
`unity/ProjectSettings` and reads the model height and relaxed arm directions from `data/tuning.json` `kaiju_body`
(the same test holds them equal to the Godot consts); `tools/kaiju_skin/bake_all.sh` gets the rest poses from
`slicebake --rest` (RestDump.cs) instead of Godot's dump_rest.gd; the data files' "_note" keys no longer count.

## The rules rewrite
Landed now (safe while Godot runs): `tools/run_touched.py` also runs `unity/SimTests` under dotnet when the Unity sim
side changes. Kept on branch `claude/u6-unity-only-rules`, to land in the switch PR:
- `CLAUDE.md`: Unity 6 HDRP only; the machine rules keep gpu_slot for windowed Unity player runs (D-376); tests
  are `python tools/run_touched.py` (SimTests) and the editor typecheck; `.meta` churn replaces `.import` churn;
  `regen_sim.sh` goes (the C# sim is edited directly; its golden logs are frozen).
- `tools/run_touched.py`: SimTests only (no suite graph over .gd files, no ci_timings).
- `tools/ci_timings.txt`, `plan_ci_shards.sh`, `ci_retime.py`, `ci_select_suites.py`: leave with tests.yml.
- `tools/lint/push_gate.sh`: no gdlint, gdformat, check_uids, thread_resources or GDScript complexity ratchet; the
  C# lints, data schemas, licence register, LFS and doc caps stay.
- `lint.yml`: the gdlint job goes; `unity.yml`: the gd2cs step goes.
- Outside the repo (the director's, not this branch): the focus and tool-gate hooks and `C:/kt/gpu_slot.sh` name
  the Godot exe; they need the Unity player's name.

## The command sequence
`python tools/unity/retire_godot.py` prints it; in short, after the ruling and with `--blockers` clean:
1. `git tag -a godot-final origin/main` and push it with `archive/godot-final` (the branch the director asked for).
2. On a branch from origin/main: `retire_godot.py --list | git rm -r --pathspec-from-file=-`, deinit godot-cpp.
3. Merge in `claude/u6-unity-only-rules`; drop `test` from main's required checks.
4. PR with the evidence: sim-csharp green, a Unity build from a fresh clone (`unity/README.md`), blockers none.
