shader_type spatial;
// The far skyline in the same air as the bay (FarHaze, on by default: tuning city far_fog):
// facade_far's own haze and height fog, and the engine's depth fog on top, as the bay takes it.

#define FAR_HAZE
#include "res://scenes/facade.gdshaderinc"
