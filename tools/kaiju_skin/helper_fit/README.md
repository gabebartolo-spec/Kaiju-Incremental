# helper_fit: D-374 corrective helper joints (Colossus hip and knee)

Build-time only (nothing here ships). Fits 5 helper joints per leg (hip, knee, web, ankle, belly) with torch autograd
so every Colossus clip keeps at most 6 flipped tris per leg in every frame, scored as the game skins (game_proxy:
merged lumbar/neck chains, bake.py top-3 u8 weights).

- `opt3.py`: the fit (env-configured; see its docstring). Writes `opt3_<OUT>_<side>.json` with the top-3 support
  mask it was scored with (`top`), which `helpers2.weights` applies.
- `heval3.py`: the bar table (run `CLEAN=0 GAME=1 TOP3=1 SPECS=l.json,r.json python heval3.py <clips>`).
- `runM.sh`: the current refit. Data (Cascadeur dumps `cd/cdump_*.npz`, starting specs) lives outside git in
  `$KAIJU_FIT_DATA` (default: the rigger's scratch folder).
- Needs numpy, scipy, torch 2.14.1 CPU (all BSD-3; see docs/LICENSING_REGISTER.md).
