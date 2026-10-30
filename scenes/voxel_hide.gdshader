shader_type spatial;
// voxel.gdshader for the voxels a kaiju rig puts on its bones (KaijuRig.attach_voxels: the mouth's
// inside and seam): the same colour and glow flag, with the hide grain (hide_grain.gdshaderinc) on
// each cube. Glowing cells (alpha 0: eyes, spines) stay clean.

#include "res://scenes/hide_grain.gdshaderinc"

uniform float glow = 0.0;
uniform float roughness_value = 0.9;

varying vec3 bone_pos;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

// The cube's own corner space, offset by its colour (jittered per cell): the grain rides the cube
// and two cubes never share a pattern. Cheaper than a per-frame node inverse; these voxels show
// only on a kaiju without a baked skin (VoxelSkin hides them).
void vertex() {
	bone_pos = VERTEX + COLOR.rgb * 37.0;
}

void fragment() {
	vec3 albedo = srgb_to_linear(COLOR.rgb);
	ALBEDO = albedo * mix(1.0, hide_grain(bone_pos), COLOR.a);
	ROUGHNESS = roughness_value;
	EMISSION = albedo * glow * (1.0 - COLOR.a);
}
