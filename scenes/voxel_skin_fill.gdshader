shader_type spatial;
// D-041: the filler under a kaiju's cubes (scenes/voxel_skin.gd): the joints' voxel faces as one
// watertight, linearly skinned surface a little inside the cubes, so where a bending joint pulls
// cubes apart the gap shows skin, never sky. CUSTOM0 = bones 0-2 and weight 0, CUSTOM1.xy =
// weights 1-2. Flat-shaded from screen derivatives (the bake stores no normals).

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
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(n, VERTEX) > 0.0 ? -n : n;
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = roughness_value;
}
