shader_type spatial;
// Far concrete: no engine fog, a gentler haze of its own; see concrete_stand.gdshaderinc.
render_mode fog_disabled;

#define FAR_HAZE
#include "res://scenes/surface_detail.gdshaderinc"
#include "res://scenes/concrete_stand.gdshaderinc"
