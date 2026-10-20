shader_type spatial;
// Phase B look test (b2-20), never merged: the kaiju as one smooth skinned surface (surface nets
// over the same cells the cubes use, scenes/smooth_mesher.gd), shaded with its own smooth normals
// instead of snapped to cube axes. Skinning as voxel_skin_fill.gdshader: CUSTOM0 = bones 0-2 and
// weight 0, CUSTOM1.xy = weights 1-2.

uniform mat4 bones[128];
uniform float roughness_value = 0.9;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	mat4 blend = bones[int(CUSTOM0.x + 0.5)] * CUSTOM0.w
		+ bones[int(CUSTOM0.y + 0.5)] * CUSTOM1.x
		+ bones[int(CUSTOM0.z + 0.5)] * CUSTOM1.y;
	VERTEX = (blend * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize(mat3(blend) * NORMAL);
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = roughness_value;
}
