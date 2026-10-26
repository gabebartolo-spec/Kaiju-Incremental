shader_type spatial;
// Rubble heaps, toppled-tower strips and thrown wall chunks (Ruin): the voxel cube's colour (sRGB, the
// building's own colours greyed) with the ground's surface family on top (surface_detail.gdshaderinc), so a
// heap reads as broken concrete, plaster and brick instead of one dark blue-grey: lumps of lighter and
// darker concrete two blocks across, brick-red and white plaster chips, soot, dust settled on the tops and
// hairline cracks. World space, block-quantised, seeded.

#include "res://scenes/surface_detail.gdshaderinc"

uniform float roughness_value = 0.92;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 q = world_pos - world_normal * 0.001;
	vec2 pc = sd_cell(sd_plane(q, world_normal));
	vec3 col = sd_srgb(COLOR.rgb);
	// Lumps two blocks across, lighter or darker, and a slow drift across the heap.
	float lump = sd_h3(floor(q / (block * 2.0)) + 5.0) * 2.0 - 1.0;
	col *= 1.0 + lump * 0.3 + (sd_fbm(pc, 1.3) - 0.5) * 0.5;
	// Warm and cool broken concrete side by side.
	col *= mix(vec3(0.9, 0.95, 1.06), vec3(1.12, 1.02, 0.88), sd_vn(pc / 0.7 + 3.0));
	// Chips: brick, plaster, soot.
	float chip = sd_h3(floor(q / block) + 41.0);
	if (chip < 0.05) {
		col = mix(col, vec3(0.3, 0.12, 0.075), 0.85);
	} else if (chip < 0.1) {
		col = mix(col, vec3(0.62, 0.6, 0.55), 0.8);
	} else if (chip < 0.15) {
		col *= 0.45;
	}
	// Dust settled on the tops, hairline cracks across the faces.
	if (world_normal.y > 0.5) {
		col = mix(col, vec3(0.34, 0.325, 0.3), 0.3 * smoothstep(0.3, 0.7, sd_vn(pc / 0.5 + 9.0)));
	}
	float crack = abs(sd_vn(pc / 0.45 + 17.0) - 0.5);
	col *= 1.0 - 0.35 * (1.0 - smoothstep(0.012, 0.03, crack));
	col *= sd_grain(q, -VERTEX.z);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
