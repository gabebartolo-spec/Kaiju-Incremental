shader_type spatial;
// The far shore's quay in the same air as the bay (FarHaze, on by default: tuning city far_fog):
// concrete_stand_far's own haze and height fog, and the engine's depth fog on top.

#define FAR_HAZE
#include "res://scenes/surface_detail.gdshaderinc"
#include "res://scenes/concrete_stand.gdshaderinc"
