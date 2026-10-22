shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
// A ground pressure ripple: a soft band of dust that runs outward and fades into the street
// (no glow: grounded-monster-film dust, not a UI ring). `peak` caps its opacity, `soft` is the
// band's feathered width as a share of the radius (data/tuning.json fx.shockwave).
// `progress` 0..1 is driven from script; the quad is scaled to the full radius.
// The dust is a light tone over a dark street (night) and a dark tone over a bright one (noon):
// it mixes the two by the street's own brightness under it, so one ring reads in both
// (VFX look sheet review 2026-10-23: the pale band vanished against the noon road).

uniform float progress = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 tint : source_color = vec4(0.62, 0.58, 0.52, 1.0);
uniform vec4 dark_tint : source_color = vec4(0.16, 0.14, 0.12, 1.0);
// Street brightness (linear) at which the tone is half way from the light to the dark one.
uniform float day_lo = 0.04;
uniform float day_hi = 0.14;
// A dark band on a bright street needs more opacity than a pale one on a dark street.
uniform float dark_boost = 1.6;
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
	float fade = 1.0 - progress * progress;
	float street = dot(texture(screen_tex, SCREEN_UV).rgb, vec3(0.2126, 0.7152, 0.0722));
	float day = smoothstep(day_lo, day_hi, street);
	ALBEDO = mix(tint.rgb, dark_tint.rgb, day);
	// Held strong, then gone at the end (not faded as the square of the time left): a wide ring
	// (a tail sweep's) is faint enough as it is.
	ALPHA = band * fade * peak * tint.a * mix(1.0, dark_boost, day);
}
