shader_type spatial;
render_mode unshaded, fog_disabled;
// FIRE BOARD treatment A/B (capture only, not the game's look): a flame plate's colour is graded by
// where the pixel is on the flame, not by the plate's age: a white-yellow core low on the axis,
// then orange, then red, then a deep red-brown at the tips, thinning into smoke at the top.
// `base_y` the fire's floor, `flame_h` its height (m), `axis` its centre (world xz), `half_w` its
// half width (m). The particle's own colour only carries alpha.

uniform float base_y = 0.0;
uniform float flame_h = 3.0;
uniform vec2 axis = vec2(0.0);
uniform float half_w = 0.6;
uniform float heat = 1.0;

varying vec3 world_at;

vec3 ramp(float h) {
	vec3 orange = vec3(1.0, 0.40, 0.06);
	vec3 red = vec3(0.86, 0.20, 0.04);
	vec3 deep = vec3(0.34, 0.08, 0.05);
	vec3 base = vec3(0.60, 0.13, 0.05);
	vec3 c = mix(base, orange, smoothstep(0.0, 0.14, h));  // a dark red-brown foot
	c = mix(c, red, smoothstep(0.25, 0.5, h));
	c = mix(c, deep, smoothstep(0.5, 0.85, h));
	return c;
}

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp((world_at.y - base_y) / flame_h, 0.0, 1.0);
	float radial = length(world_at.xz - axis) / half_w;
	// the hot core: low on the axis only
	float core = (1.0 - smoothstep(0.08, 0.28, h)) * (1.0 - smoothstep(0.35, 0.95, radial));
	vec3 hot = mix(vec3(1.0, 0.80, 0.38), vec3(1.0, 0.94, 0.72), smoothstep(0.3, 1.0, core));
	vec3 c = mix(ramp(h), hot, core);
	ALBEDO = c * heat;
	ALPHA = COLOR.a * (1.0 - 0.5 * smoothstep(0.7, 1.0, h));
}
