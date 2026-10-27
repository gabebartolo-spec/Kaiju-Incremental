shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
// The far rampage's smoke in the same air as the far towers (FarHaze, on by default: tuning city
// far_fog): horizon_smoke's puffs and own haze, and the engine's depth fog on top.

#include "res://scenes/horizon_smoke.gdshaderinc"
