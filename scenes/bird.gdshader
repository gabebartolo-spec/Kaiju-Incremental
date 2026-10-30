shader_type spatial;
render_mode cull_disabled;
// A bird of WildlifeView (gull or pigeon). Its wings beat in the vertex stage: COLOR.r is a
// vertex's share of the way out along a wing (0 at the body), INSTANCE_CUSTOM.x the bird's beat
// phase (0..1) and INSTANCE_CUSTOM.y its beat on/off (0: perched or gliding, the wings held).

uniform vec3 color : source_color = vec3(0.9);
uniform float flap_rate = 9.0;  // radians per second
uniform float flap_lift = 0.6;  // wingtip lift, as a share of the half span

void vertex() {
	float beat = sin(TIME * flap_rate + INSTANCE_CUSTOM.x * 6.2832) * INSTANCE_CUSTOM.y;
	VERTEX.y += beat * flap_lift * COLOR.r * abs(VERTEX.x);
}

void fragment() {
	ALBEDO = color;
	ROUGHNESS = 1.0;
}
