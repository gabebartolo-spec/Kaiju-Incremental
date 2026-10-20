shader_type spatial;
// Phase B look test (b2-20), never merged: a smooth-meshed prop, car or person (scenes/smooth_mesher.gd).
// Vertex colour is the albedo; alpha 0 marks a glowing cell (a lamp), as in the voxel palette.

uniform float roughness_value = 0.85;
uniform float glow = 1.0;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	vec3 col = srgb_to_linear(COLOR.rgb);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	EMISSION = col * glow * (1.0 - step(0.5, COLOR.a));
}
