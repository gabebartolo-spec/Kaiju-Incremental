shader_type spatial;
// Look-boards mock (capture-only branch): the ground slabs (roads, pavements, lawns, quay) with the
// buildings' grain. The slab's colour is the instance colour; each 0.125 block of the world gets
// its own small brightness step (the hash building_baked.gdshader uses), a coarser 1 m patch step,
// a few darker specks, and a faint seam where the blocks meet. Quantised noise, so it stays blocks.

uniform float block = 0.125;
uniform float block_noise = 0.09;
uniform float patch_noise = 0.05;
uniform float speck_chance = 0.04;
uniform float seam = 0.05;

varying vec3 world_pos;
varying vec3 world_normal;

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Nudge the sample inside the face, so a block edge never flips with float error.
	vec3 q = world_pos - world_normal * 0.001;
	vec3 cell = floor(q / block);
	float h = hash3(cell) * 2.0 - 1.0;
	float patch_h = hash3(floor(q / 1.0) + 17.0) * 2.0 - 1.0;
	float k = 1.0 + h * block_noise + patch_h * patch_noise;
	if (hash3(cell + 91.0) < speck_chance) {
		k *= 0.72;
	}
	vec3 f = fract(q / block);
	vec3 edge = min(f, 1.0 - f);
	float e = min(min(edge.x, edge.y), edge.z);
	// The seam shows on the faces that point up and sideways, one pixel-ish wide.
	float seam_k = 1.0 - seam * (1.0 - smoothstep(0.0, 0.06, e));
	ALBEDO = srgb_to_linear(COLOR.rgb) * k * seam_k;
	ROUGHNESS = 1.0;
}
