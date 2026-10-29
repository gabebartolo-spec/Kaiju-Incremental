# helper_fit: D-374 corrective helper joints (Colossus hip and knee)

Build-time only (nothing here ships). Fits 5 helper joints per leg (hip, knee, web, ankle, belly) with torch autograd
so every Colossus clip keeps at most 6 flipped tris per leg in every frame, scored as the game skins (game_proxy:
merged lumbar/neck chains, bake.py top-3 u8 weights).

- `opt3.py`: the fit (env-configured; see its docstring). Writes `opt3_<OUT>_<side>.json` with the top-3 support
  mask it was scored with (`top`), which `helpers2.weights` applies.
- `heval3.py`: the bar table (run `CLEAN=0 GAME=1 TOP3=1 SPECS=l.json,r.json python heval3.py <clips>`).
- `runM.sh` -> `runP.sh` -> `runQ.sh`: the shipped fit in order (M from the G specs, P1 every frame, X1 left leg);
  the game uses `opt3_X1_l.json` + `opt3_P1_r.json` (`mk_helpers.py out.json l.json r.json` writes `tools/blender/croc_adult3_helpers.json`).
- `runTab.sh <l> <r> <out.md>`: the 13-clip bar table. Data (Cascadeur dumps `cd/cdump_*.npz`, starting specs) lives outside git in
  `$KAIJU_FIT_DATA` (default: the rigger's scratch folder).
- Needs numpy, scipy, torch 2.14.1 CPU (all BSD-3; see docs/LICENSING_REGISTER.md).
