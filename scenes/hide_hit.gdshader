shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// A shot's flash on the hide (HideHit): a tiny ragged disc lying on the surface, not a billboard.
// Depth-tested (never no_depth_test), alpha-blended, its colour held under the 0.9 bloom
// threshold, so it never glows. `fade` runs 1 -> 0 over its life.

uniform vec3 tint : source_color = vec3(0.85, 0.44, 0.16);
uniform float peak = 0.85;
uniform float fade = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ragged = (hash(floor(UV * 6.0)) - 0.5) * 0.45;
	float mask = 1.0 - smoothstep(0.35, 1.0, length(p) + ragged);
	ALBEDO = tint;
	ALPHA = mask * peak * fade;
}
