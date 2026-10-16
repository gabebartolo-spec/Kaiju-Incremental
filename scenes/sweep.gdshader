shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Tentacle Lash: a bright arc whipping once round the kaiju on a flat annulus (PlaneMesh).
// `progress` 0..1 drives the head of the arc through a full turn plus a little; the trail
// behind it fades fast, with faint streaks across it like a tentacle's ridges.

uniform float progress = 0.0;
uniform float inner = 0.35;
uniform float power = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.25, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = (atan(p.y, p.x) + 3.14159) / 6.28318;
	float head = progress * 1.15;
	float behind = head - a;
	behind = behind < 0.0 ? 9.0 : behind;
	float trail = exp(-behind * 5.0) * step(behind, 1.0);
	float band = smoothstep(inner, inner + 0.12, r) * (1.0 - smoothstep(0.88, 1.0, r));
	float fibre = 0.8 + 0.2 * sin(a * 220.0 + r * 9.0);
	float lip = exp(-behind * 60.0);
	float fade = 1.0 - smoothstep(0.75, 1.0, progress);
	ALBEDO = mix(tint.rgb, vec3(1.0), lip * 0.7) * (1.5 + power);
	ALPHA = clamp(band * (trail * fibre * 0.8 + lip) * fade, 0.0, 1.0);
}
