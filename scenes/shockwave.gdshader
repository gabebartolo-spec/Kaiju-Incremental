shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// A ground shockwave: a bright ring that runs outward and fades, with a ragged edge.
// `progress` 0..1 is driven from script; the quad is scaled to the full radius.

uniform float progress = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.55, 1.0);
// The band's width and outer edge (fractions of the radius), its glow and an alpha the script fades
// (a soft ring: wide, soft-edged, dimmer, faded in and out by the script).
uniform float width = 0.18;
uniform float edge = 0.03;
uniform float glow = 2.0;
uniform float alpha = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float ragged = 0.04 * hash(vec2(floor(angle * 24.0), 1.0));
	float front = progress + ragged;
	float band = smoothstep(front - width, front, r) * (1.0 - smoothstep(front, front + edge, r));
	float fade = 1.0 - progress;
	ALBEDO = tint.rgb * glow;
	ALPHA = band * fade * fade * alpha;
}
