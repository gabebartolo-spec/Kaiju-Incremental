shader_type spatial;
// Voxel material for MultiMesh cells. The instance colour is sRGB; its alpha is a glow flag:
// 1 = plain, 0 = glows (lit windows, eyes, glowing spines) at `glow` strength.

uniform float glow = 0.0;
uniform float roughness_value = 0.9;
// A faint glow of the cell's own colour on every cell (night flyers: a silhouette that reads).
uniform float self_light = 0.0;
// The cut-away bubble round the camera (CameraBubble): vehicles set bubble_on to 1; every
// fragment nearer the camera than the global bubble_radius is not drawn (a hard edge, no dither).
global uniform float bubble_radius;
uniform float bubble_on = 0.0;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	if (bubble_on > 0.5 && length(VERTEX) < bubble_radius) {
		discard;
	}
	vec3 albedo = srgb_to_linear(COLOR.rgb);
	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
	EMISSION = albedo * (glow * (1.0 - COLOR.a) + self_light);
}
