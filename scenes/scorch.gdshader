shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// A mark burnt or cracked into the street, on a flat quad (PlaneMesh) centred on the hit.
// shape 0: a disc (Leap Slam crater, heavy-stomp cracks); shape 1: a wedge of half_angle
// pointing along local -Z (Atomic Breath scorch). Char darkens the ground; cracks glow in
// `tint` and cool over `age` 0..1, then the mark fades away.

uniform float age = 0.0;
uniform int shape = 0;
uniform float half_angle = 0.5;
uniform float char_strength = 0.85;
uniform float crack_count = 9.0;
uniform float glow = 3.0;
uniform vec4 tint : source_color = vec4(1.0, 0.35, 0.08, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	// PlaneMesh UV.y grows toward local +Z; the wedge points along local -Z (Basis.looking_at).
	float ang = atan(p.x, p.y);
	float edge = noise(p * 6.0) * 0.25;
	float mask;
	if (shape == 1) {
		float side = 1.0 - smoothstep(half_angle * 0.8, half_angle * 1.1, abs(ang) + edge * 0.3);
		mask = side * (1.0 - smoothstep(0.75, 1.0, r + edge)) * smoothstep(0.02, 0.12, r);
	} else {
		mask = 1.0 - smoothstep(0.55, 1.0, r + edge);
	}
	// Jagged radial cracks: the angle wanders with distance so no crack is a straight line.
	float wander = (noise(vec2(r * 7.0, floor(ang * crack_count / 6.2832))) - 0.5) * 0.9;
	float lane = fract(ang * crack_count / 6.2832 + wander * r);
	float to_crack = 0.5 - abs(lane - 0.5);
	float crack = 1.0 - smoothstep(0.0, 0.012 + 0.02 * r, to_crack);
	crack *= smoothstep(0.08, 0.2, r) * (1.0 - smoothstep(0.7, 0.95, r + edge));
	float hot = pow(1.0 - age, 3.0);
	float fade = 1.0 - smoothstep(0.7, 1.0, age);
	vec3 soot = vec3(0.025, 0.022, 0.02) * (0.6 + 0.8 * noise(p * 14.0));
	ALBEDO = soot;
	ROUGHNESS = 1.0;
	EMISSION = tint.rgb * glow * crack * hot;
	ALPHA = clamp(mask * (char_strength * (0.55 + 0.45 * noise(p * 4.0)) + crack) * fade, 0.0, 1.0);
}
