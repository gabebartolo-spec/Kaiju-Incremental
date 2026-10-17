shader_type spatial;
// Voxel material for MultiMesh cells. The instance colour is sRGB; its alpha is a glow flag:
// 1 = plain, 0 = glows (lit windows, eyes, glowing spines) at `glow` strength.

uniform float glow = 0.0;
uniform float roughness_value = 0.9;
// Below 1, a screen-door fade (vehicles between the camera and the kaiju, D-025's rule): the
// cells stay opaque and depth-sorted, a share of their pixels is dropped in a fixed pattern.
uniform float opacity = 1.0;
// A BoxMesh per cell (MultiMesh) reads its face coordinate from its corners; a baked mesh of
// faces (VoxelBuilder) carries it in UV.
uniform bool box_mesh = false;
const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

#include "res://scenes/voxel_edge.gdshaderinc"

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec2 face = box_mesh ? edge_box_face(VERTEX, NORMAL) : UV * 2.0 - 1.0;
	edge_vertex(NORMAL, face, mat3(MODELVIEW_MATRIX));
}

void fragment() {
	if (opacity < 1.0) {
		ivec2 p = ivec2(mod(FRAGCOORD.xy, 4.0));
		if ((BAYER[p.y * 4 + p.x] + 0.5) / 16.0 >= opacity) {
			discard;
		}
	}
	vec3 albedo = srgb_to_linear(COLOR.rgb);
	vec3 shaded = albedo;
	vec3 normal = NORMAL;
	edge_fragment(shaded, normal);
	ALBEDO = shaded;
	NORMAL = normal;
	ROUGHNESS = roughness_value;
	EMISSION = albedo * glow * (1.0 - COLOR.a);
}
