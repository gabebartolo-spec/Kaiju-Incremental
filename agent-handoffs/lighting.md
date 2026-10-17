# Lighting handoff, 2026-10-18 05:40
## State: running a check (CI before/after breath clips, one run at a time)

## Who
Role: lighting, reporting to the lead (session "LEAD", local_106fc100-d2a4-4091-bc9a-4bda31df13ac).
Lead rules: look changes reach the director only via the lead (A/B at the game camera, 1080p+4K);
CI captures one run at a time or the lead's local GPU slot; PRs into claude/look-options;
reports <=8 lines.

## Closed: lighting looks (D-057)
Director picked A, keep concrete. claude/lighting (head d2f63dc) stays pushed, not merged, no
further work: golden/dusk/night looks, city_lighting.gd, optional look keys, look "base"
inheritance, game-camera A/B boards in docs/captures/2026-10-18-lighting/ on that branch.
Night lessons kept there: vol fog must stay <=0.003 at the game camera; window glow white = blown.

## Now: breath voxel jet (lead call, defect)
Branch claude/breath-beam-only off look-options d57ead1, same worktree dir
(../Kaiju-Incremental-wt/lighting). Commits: 8e10ae3 capture_powers --species/--signature-only;
8d238fe drop fx.gd breath() + rampage call, flow check (no 0.25 u box particles while the breath
plays; failed first "1 jets"), flow floor 92->93, capture.yml --fixed-fps for stills, README.
All 8 suites green locally.
claude/breath-before = 8e10ae3 (old code + capture flags) for the BEFORE clip; delete it
after the PR merges.
CI: before clip running (log scratchpad/breath_before.log), then the after clip on
claude/breath-beam-only:
  tools/capture/ci_capture.sh --movie --fps=30 --resolution=1280x720 --ref=<branch> \
    capture_powers.gd -- --species=reptilian --signature-only --out=<dir>
PR body draft: scratchpad/pr_body.md (fill in clip paths, crops, critic verdict).

## Next
1. After clip; 2x crops of reptilian_signature_06 and _14 before/after -> docs/captures/
   2026-10-18-breath/.
2. Fresh motion-critic: the clips + claim "the breath reads as a beam, no pale blocks".
3. Open the PR into claude/look-options, send the lead <=8 lines (clip paths + verdict).
