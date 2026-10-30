shader_type spatial;
render_mode cull_disabled;
// A creature of WildlifeView (gull, pigeon, the whale). Its wings beat in the vertex stage: COLOR.r is
// a vertex's share of the way out along a wing (0 at the body), INSTANCE_CUSTOM.x the bird's beat
// phase (0..1) and INSTANCE_CUSTOM.y its beat on/off (0: perched or gliding, the wings held; always 0
// on the whale, which is no MultiMesh). The city's surface grain (surface_detail.gdshaderinc) sits on
// it in model space, so it rides with the animal instead of swimming over it.

#include "res://scenes/surface_detail.gdshaderinc"

uniform vec3 color : source_color = vec3(0.9);
uniform float roughness_value = 1.0;
uniform float flap_rate = 9.0;  // radians per second
uniform float flap_lift = 0.6;  // wingtip lift, as a share of the half span

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	float beat = sin(TIME * flap_rate + INSTANCE_CUSTOM.x * 6.2832) * INSTANCE_CUSTOM.y;
	VERTEX.y += beat * flap_lift * COLOR.r * abs(VERTEX.x);
}

void fragment() {
	ALBEDO = color * sd_grain(local_pos + 0.001, -VERTEX.z);
	ROUGHNESS = roughness_value;
}
