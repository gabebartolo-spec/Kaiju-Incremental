shader_type spatial;
render_mode cull_disabled;
// A building baked into one mesh (BuildingMesher): only the faces you can see, so a city at
// eight voxels per floor costs about what it did at four. Each vertex carries its structural
// chunk (UV2.x) and a per-voxel hash (UV2.y). The `alive` texture holds one texel per chunk:
// 1 standing, 0 gone (its faces collapse to nothing), in between = bitten (that share of the
// chunk's voxels gone), so breaking the building never rebuilds the mesh. Colour is sRGB; its
// alpha is the glow flag (0 = glows at `glow`), as in voxel.gdshader. Only outward faces are
// baked, so through a hole you see the backs of the walls: they draw as the dark inside.

uniform sampler2D alive : filter_nearest;
uniform float glow = 0.0;
uniform float roughness_value = 0.9;
// Below 1, a screen-door fade (a building between the camera and the kaiju, D-025's rule as
// the vehicles have it, voxel.gdshader): a share of its pixels is dropped in a fixed pattern.
uniform float opacity = 1.0;
const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

#include "res://scenes/voxel_edge.gdshaderinc"

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	float state = texelFetch(alive, ivec2(int(UV2.x + 0.5), 0), 0).r;
	if (state < 0.02 || UV2.y < 1.0 - state) {
		VERTEX = vec3(0.0);
	}
	edge_face = UV * 2.0 - 1.0;
	edge_u = normalize(mat3(MODELVIEW_MATRIX) * edge_u_axis(NORMAL));
	edge_v = normalize(mat3(MODELVIEW_MATRIX) * edge_v_axis(NORMAL));
}

void fragment() {
	if (opacity < 1.0) {
		ivec2 p = ivec2(mod(FRAGCOORD.xy, 4.0));
		if ((BAYER[p.y * 4 + p.x] + 0.5) / 16.0 >= opacity) {
			discard;
		}
	}
	vec3 albedo = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = roughness_value;
	if (FRONT_FACING) {
		vec3 shaded = albedo;
		vec3 normal = NORMAL;
		edge_fragment(edge_face, edge_u, edge_v, shaded, normal);
		ALBEDO = shaded;
		NORMAL = normal;
		EMISSION = albedo * glow * (1.0 - COLOR.a);
	} else {
		ALBEDO = albedo * 0.12;
		NORMAL = -NORMAL;
	}
}
