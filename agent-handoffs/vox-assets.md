# vox-assets (asset session for LEAD 8, b2-19 voxel density) - 2026-10-20
State: running a check (bakes running in background).
Task: re-bake reptilian x3, tank, heli, stadium, wheel at HALF and DOUBLE density; BuildingVoxels.RES,
bake.py RES and tuning destruction.res set to 4 / 16. Branches claude/vox-half (this worktree),
claude/vox-double (../Kaiju-Incremental-wt/vox-double), both from claude/camera-options f924428. No PR.
Pipeline: scratchpad pipe.sh (rig_voxel + rig_from_skin with rescaled test/*.skin.json matrix; kclip and
skinf kept; voxelize_parts; voxelize + landmarks bake --connect, re-add "inside"; bake_all.sh vskin).
Sources verified byte-identical at old density: baby rep_croctitan_baby.glb; adolescent = croctitan_adolescent
rotated +90 Z; adult = rep_croctitan_adult_v2.glb with snarl 0.35. Mouths: baby -87,81,-46,87.4;
adol -79,86.8,-61,89.6; adult -79,84,-52.5,87.3. Heights half 50/65/80, double 200/260/320;
tank 7/28, heli 12/46; landmark raw stadium 49/195, wheel 106/422.
Next: commit assets on each branch, capture_framing --seconds=15 per branch, push, report to lead, archive.
Open decisions: none.
