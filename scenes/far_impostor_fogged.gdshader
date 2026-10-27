shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_prepass_alpha;
// The far beast in the same air as the far towers (FarHaze, on by default: tuning city far_fog):
// far_impostor's picture, own haze and height fog, and the engine's depth fog on top.

#include "res://scenes/far_impostor.gdshaderinc"
