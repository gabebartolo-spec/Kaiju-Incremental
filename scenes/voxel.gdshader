shader_type spatial;
// Voxel material for MultiMesh cells. The instance colour is sRGB; its alpha is a glow flag:
// 1 = plain, 0 = glows (lit windows, eyes, glowing spines) at `glow` strength.

uniform float glow = 0.0;
uniform float roughness_value = 0.9;
// Below 1, a screen-door fade (vehicles between the camera and the kaiju, D-025's rule): the
// cells stay opaque and depth-sorted, a share of their pixels is dropped in a fixed pattern.
uniform float opacity = 1.0;
// A white-hot flash over the whole part (a helicopter breaking apart): added light, 0 = none.
uniform float flash = 0.0;
// 0..1: the part chars dark (a helicopter hull burning after it breaks), 0 = unchanged.
uniform float scorch = 0.0;
// Firelight on a burning part (a helicopter hull going down): the colour of the fire under it
// (HDR), thrown most on faces turned down and a little everywhere, added as light. Black = none.
uniform vec3 ember_light = vec3(0.0);
const float DITHER_PX = 2.0;  // a 4K-readable pattern: each dither cell 2 physical pixels
const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	if (opacity < 1.0) {
		ivec2 p = ivec2(mod(floor(FRAGCOORD.xy / DITHER_PX), 4.0));  // cells of DITHER_PX pixels
		if ((BAYER[p.y * 4 + p.x] + 0.5) / 16.0 >= opacity) {
			discard;
		}
	}
	vec3 albedo = srgb_to_linear(COLOR.rgb);
	albedo *= mix(1.0, 0.16, scorch);
	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
	float down = 0.5 - 0.5 * (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	float tone = 0.55 + 1.3 * dot(srgb_to_linear(COLOR.rgb), vec3(0.333));
	EMISSION = albedo * glow * (1.0 - COLOR.a) + vec3(flash) + ember_light * (0.3 + 0.7 * down) * tone;
}
