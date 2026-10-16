shader_type spatial;
// Stand-ins far away: no engine fog, a gentler haze of their own.
render_mode fog_disabled;

#define FAR_HAZE
#include "res://scenes/facade.gdshaderinc"
