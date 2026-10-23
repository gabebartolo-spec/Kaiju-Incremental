shader_type spatial;
// The ground slabs (roads, pavements, lawns, the quay) in the city's block grain (director D-163:
// "Fine blocks like the city"). The slab's colour is the instance colour; each block of the world
// (ground_block, 0.125 m, the city's voxel size) gets its own small brightness step (the hash the
// buildings use), a coarser 1 m patch step, a few darker specks and a faint seam where blocks meet.
// All of it is quantised to the world grid, so it stays blocks and never swims with the camera, and
// it fades to the slab's flat colour with distance (fade_near..fade_far), where a block is under a
// pixel and the noise would only shimmer. Numbers come from data/looks.json "ground_*".

uniform float block = 0.125;
uniform float block_noise = 0.09;
uniform float patch_noise = 0.05;
uniform float speck_chance = 0.04;
uniform float speck_dark = 0.72;
uniform float seam = 0.05;
uniform float fade_near = 35.0;
uniform float fade_far = 80.0;

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
	float patch_h = hash3(floor(q) + 17.0) * 2.0 - 1.0;
	float k = 1.0 + h * block_noise + patch_h * patch_noise;
	if (hash3(cell + 91.0) < speck_chance) {
		k *= speck_dark;
	}
	vec3 f = fract(q / block);
	vec3 edge = min(f, 1.0 - f);
	float e = min(min(edge.x, edge.y), edge.z);
	// One pixel-ish wide, on the faces that point up and sideways.
	float seam_k = 1.0 - seam * (1.0 - smoothstep(0.0, 0.06, e));
	float grain = 1.0 - smoothstep(fade_near, fade_far, -VERTEX.z);
	ALBEDO = srgb_to_linear(COLOR.rgb) * mix(1.0, k * seam_k, grain);
	ROUGHNESS = 1.0;
}
