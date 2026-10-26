shader_type spatial;
// The warm pool a street lamp lays on the ground at night (LampPools): additive, unlit, a flat disc a little
// over the ground, brightest under the lamp and gone at `radius`. Its own grain (the ground's block-quantised
// noise, surface_detail.gdshaderinc) shows inside the pool, so it reads as light on asphalt and paving, not a
// flat glow. Light only where the lamp is: the rest of the night is untouched.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

#include "res://scenes/surface_detail.gdshaderinc"

uniform float pool = 0.05;
uniform float radius = 4.0;
uniform vec3 tint : source_color = vec3(1.0, 0.72, 0.42);

varying vec3 world_pos;
varying vec2 centre;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	centre = MODEL_MATRIX[3].xz;
}

void fragment() {
	float d = length(world_pos.xz - centre) / radius;
	float fall = pow(clamp(1.0 - d, 0.0, 1.0), 1.5);
	vec2 pc = sd_cell(world_pos.xz);
	float grain = 0.6 + 0.8 * sd_fbm(pc, 1.3) + (sd_h(floor(pc / block)) - 0.5) * 0.35;
	ALBEDO = tint * pool * fall * grain;
	ALPHA = 1.0;
}
