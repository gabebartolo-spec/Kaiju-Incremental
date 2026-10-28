shader_type spatial;
// Voxel material for MultiMesh cells. The instance colour is sRGB; its alpha is a glow flag:
// 1 = plain, 0 = glows (lit windows, eyes, glowing spines) at `glow` strength.

uniform float glow = 0.0;
uniform float roughness_value = 0.9;
// A faint glow of the cell's own colour on every cell (night flyers: a silhouette that reads).
uniform float self_light = 0.0;
// Always solid: nothing drawn with it fades (vehicles D-290; D-326, no screen door anywhere).

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	vec3 albedo = srgb_to_linear(COLOR.rgb);
	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
	EMISSION = albedo * (glow * (1.0 - COLOR.a) + self_light);
}
