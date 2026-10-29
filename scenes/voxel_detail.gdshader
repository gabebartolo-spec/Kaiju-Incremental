shader_type spatial;
// The voxel material (voxel.gdshader) in the city's surface family (surface_detail.gdshaderinc), for a voxel
// model that moves as a whole (a train car, debt row 25: the cars were flat colour blocks). Same inputs as
// voxel.gdshader: the instance colour is sRGB, its alpha a glow flag (0 = glows at `glow`). On the colour, the
// city's block grain (sd_grain: a tone step per block, a 1 m patch step, specks, seams; same numbers) and the
// cast-concrete family's 4 m tone drift (sd_concrete's base tone), so it reads as a surface at the game camera.
// The detail sits in the model's own space, built from each cell's grid index (INSTANCE_CUSTOM.xyz, set by
// VoxelBuilder when `detail` is on), so it rides with the model instead of swimming over it as it moves. A
// baked model (VoxelBuilder.bake with `detail`: people, cars) has no instances; its vertices are already
// in the model's own space (`baked` on).

#include "res://scenes/surface_detail.gdshaderinc"

uniform float glow = 0.0;
uniform float roughness_value = 0.9;
uniform float self_light = 0.0;
// The model's cell size (m): INSTANCE_CUSTOM.xyz counts cells.
uniform float voxel = 0.125;
// How far the 4 m tone drift moves the colour (sd_concrete's 0.3).
uniform float tone_drift = 0.3;
// A baked mesh (VERTEX is the model-space point) instead of a MultiMesh of cubes.
uniform bool baked = false;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	// The cube's own vertex (MODEL_MATRIX carries the instance), lifted half a cell so the whole cube is
	// inside one block of sd_grain's grid.
	local_pos = baked ? VERTEX : (INSTANCE_CUSTOM.xyz + vec3(0.5)) * voxel + VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 base = sd_srgb(COLOR.rgb);
	vec3 q = local_pos - local_normal * 0.001;
	vec2 pc = sd_cell(sd_plane(q, local_normal));
	vec3 albedo = base * (1.0 + (sd_fbm(pc, 4.0) - 0.5) * tone_drift);
	albedo *= sd_grain(q, -VERTEX.z);
	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
	EMISSION = base * (glow * (1.0 - COLOR.a) + self_light);
}
