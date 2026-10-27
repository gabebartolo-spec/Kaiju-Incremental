// The skyline's concrete (the elevated expressway, its parapets and pillars, the far shore's quay): the
// ground's concrete look (surface_detail.gdshaderinc) on plain boxes, in world space, block-quantised, seeded,
// so it is the same grain as the river walls. concrete_stand.gdshader takes the engine's fog;
// concrete_stand_far.gdshader fades by its own gentler haze like facade_far.gdshader (far_haze.gdshaderinc),
// concrete_stand_far_fogged.gdshader takes the engine's fog too (FarHaze). Instance colour (sRGB)
// = the concrete's base colour.

uniform vec3 haze_color : source_color = vec3(0.30, 0.45, 0.50);
uniform float haze = 0.0;
uniform float haze_start = 120.0;
#ifdef FAR_HAZE
#include "res://scenes/far_haze.gdshaderinc"
#endif

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 q = world_pos - world_normal * 0.001;
	vec2 pc = sd_cell(sd_plane(q, world_normal));
	vec3 col = sd_concrete(sd_srgb(COLOR.rgb), pc, world_pos.y, world_normal, -100.0);
	col *= sd_grain(q, -VERTEX.z);
	ROUGHNESS = 0.9;
#ifdef FAR_HAZE
	float f = far_haze(length(world_pos - CAMERA_POSITION_WORLD), world_pos.y);
	ALBEDO = col * (1.0 - f);
	EMISSION = haze_color * f;
#else
	ALBEDO = col;
#endif
}
