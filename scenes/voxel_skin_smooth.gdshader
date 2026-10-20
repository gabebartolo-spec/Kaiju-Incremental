shader_type spatial;
// Phase B look test (b2-20), never merged: the kaiju as one smooth skinned surface (surface nets
// over the same cells the cubes use, scenes/smooth_mesher.gd), shaded with its own smooth normals
// instead of snapped to cube axes. Skinning as voxel_skin_fill.gdshader: CUSTOM0 = bones 0-2 and
// weight 0, CUSTOM1.xy = weights 1-2.

uniform mat4 bones[128];
uniform float roughness_value = 0.9;
// The mouth's inside (CUSTOM1.z = 1) is a dark seam while the jaw is shut, as voxel_skin.gdshader.
uniform float mouth_open = 0.0;
uniform float seam_dark = 0.22;

varying vec3 tint;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	mat4 blend = bones[int(CUSTOM0.x + 0.5)] * CUSTOM0.w
		+ bones[int(CUSTOM0.y + 0.5)] * CUSTOM1.x
		+ bones[int(CUSTOM0.z + 0.5)] * CUSTOM1.y;
	VERTEX = (blend * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize(mat3(blend) * NORMAL);
	tint = COLOR.rgb;
	if (CUSTOM1.z > 0.5) {
		tint = mix(tint * seam_dark, tint, mouth_open);
	}
}

void fragment() {
	ALBEDO = srgb_to_linear(tint);
	ROUGHNESS = roughness_value;
}
