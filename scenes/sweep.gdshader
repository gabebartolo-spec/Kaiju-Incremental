shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Tentacle Lash: two smeared streaks whipping once round the kaiju where its tentacle tips run
// (a flat PlaneMesh at shin height). `progress` 0..1 drives the heads through a full turn; each
// streak is a thin hot lip with a short smear behind it. No filled area: nothing reads as a
// hitbox, and nothing covers the kaiju (D-025).

uniform float progress = 0.0;
uniform float power = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.25, 1.0);

float streak(float r, float a, float radius, float lag) {
	float behind = progress * 1.12 - lag - a;
	if (behind < 0.0 || behind > 0.45) {
		return 0.0;
	}
	float width = 0.045 + behind * 0.08;
	float band = exp(-pow((r - radius) / width, 2.0));
	return band * (exp(-behind * 6.0) + exp(-behind * 60.0) * 2.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = (atan(p.y, p.x) + 3.14159) / 6.28318;
	float s = streak(r, a, 0.8, 0.0) + streak(r, a, 0.93, 0.05) * 0.8;
	float fade = 1.0 - smoothstep(0.8, 1.0, progress);
	ALBEDO = mix(tint.rgb, vec3(1.0), clamp(s - 0.6, 0.0, 1.0)) * (2.0 + power);
	ALPHA = clamp(s * fade, 0.0, 1.0);
}
