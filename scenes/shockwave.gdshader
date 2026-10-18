shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// A ground shockwave: a bright ring that runs outward and fades, with a ragged edge.
// `progress` 0..1 is driven from script; the quad is scaled to the full radius.

uniform float progress = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.55, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float ragged = 0.04 * hash(vec2(floor(angle * 24.0), 1.0));
	float front = progress + ragged;
	float band = smoothstep(front - 0.18, front, r) * (1.0 - smoothstep(front, front + 0.03, r));
	float fade = 1.0 - progress;
	ALBEDO = tint.rgb * 2.0;
	ALPHA = band * fade * fade;
}
