# Behemoth rise_bay r2 (WIP, keyer croc-claw, 2026-10-28): not for merge

Port of the adult's approved rise_p (rig11/roar_intro/rise_keys.py) to the adolescent y7 rig via dk (DK_STAGE=adolescent, lengths x K 0.777).
Take: C:/kt/casc_drafts_1028/adolescent/rise_bay_rise_r2.casc (180 f; frames/cfg/jaw json here regenerate it via grun.sh).
Generate: `NFR=180 python ado_rise.py r2 Y0=-18 KN0=105 FL0=15 AN0=-60 H0=0 TP0=-25`; tables: `bash run_r.sh r2` (r2.log).
Tables r2: U1 FAIL (belly gap 8 f < 12), U2 FAIL (belly +2.59 at start; legs -3.60 at f65), U3 FAIL (slide 1.09 > 0.78),
U4 PASS, U5 PASS; ntable FAIL (neck tris 12 @f31, 17 frames over); rall PASS (6/6/5); kcd FAIL (thigh twist 7.0 deg/f).
U2 open: belly 2.59 cm; next step is to check whether f0 is under the bay water line in game (if the belly is hidden,
U2 is fitted to the fiction; if visible, try ABD 55-70 sprawl, as real crocs splay). Start-pose sweeps: pc_a..e.log.
