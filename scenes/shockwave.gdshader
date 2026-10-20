shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
// A ground pressure ripple: a soft band of dust that runs outward and fades into the street
// (no glow: grounded-monster-film dust, not a UI ring). `peak` caps its opacity, `soft` is the
// band's feathered width as a share of the radius (data/tuning.json fx.shockwave).
// `progress` 0..1 is driven from script; the quad is scaled to the full radius.

uniform float progress = 0.0;
uniform vec4 tint : source_color = vec4(0.62, 0.58, 0.52, 1.0);
uniform float peak = 0.2;
uniform float soft = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float ragged = 0.04 * hash(vec2(floor(angle * 24.0), 1.0));
	float front = progress + ragged;
	float band = smoothstep(front - soft, front, r) * (1.0 - smoothstep(front, front + 0.12, r));
	float fade = 1.0 - progress;
	ALBEDO = tint.rgb;
	ALPHA = band * fade * fade * peak * tint.a;
}
