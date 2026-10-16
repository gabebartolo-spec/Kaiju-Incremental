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

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	float state = texelFetch(alive, ivec2(int(UV2.x + 0.5), 0), 0).r;
	if (state < 0.02 || UV2.y < 1.0 - state) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec3 albedo = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = roughness_value;
	if (FRONT_FACING) {
		ALBEDO = albedo;
		EMISSION = albedo * glow * (1.0 - COLOR.a);
	} else {
		ALBEDO = albedo * 0.12;
		NORMAL = -NORMAL;
	}
}
