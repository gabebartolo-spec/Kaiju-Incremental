shader_type spatial;
// D-041: the filler under a kaiju's cubes (scenes/voxel_skin.gd): the joints' voxel faces as one
// watertight, linearly skinned surface a little inside the cubes, so where a bending joint pulls
// cubes apart the gap shows skin, never sky. CUSTOM0 = bones 0-2 and weight 0, CUSTOM1.xy =
// weights 1-2. Shaded like voxel faces: its normal snaps to the nearest axis of its main bone, so
// a stretched patch reads as cube faces instead of a streaked sheet (lead review, PR #15).

#include "res://scenes/stone_body.gdshaderinc"
// D-397: the hide grain, at the rest position (rides the bones), as on the cubes.
#include "res://scenes/hide_grain.gdshaderinc"

uniform mat4 bones[128];
uniform float roughness_value = 0.9;
// The stone creep as he dies (voxel_skin.gdshader's, same front): the filler turns with the cubes.
uniform float stone = 0.0;
uniform float body_top = 10.0;
varying vec3 rest;

varying flat vec3 axis_x;
varying flat vec3 axis_y;
varying flat vec3 axis_z;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	rest = VERTEX;
	mat4 main_bone = bones[int(CUSTOM0.x + 0.5)];
	mat4 blend = main_bone * CUSTOM0.w
		+ bones[int(CUSTOM0.y + 0.5)] * CUSTOM1.x
		+ bones[int(CUSTOM0.z + 0.5)] * CUSTOM1.y;
	VERTEX = (blend * vec4(VERTEX, 1.0)).xyz;
	mat3 to_view = mat3(MODELVIEW_MATRIX) * mat3(main_bone);
	axis_x = normalize(to_view[0]);
	axis_y = normalize(to_view[1]);
	axis_z = normalize(to_view[2]);
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	n = dot(n, VERTEX) > 0.0 ? -n : n;
	vec3 d = vec3(dot(n, axis_x), dot(n, axis_y), dot(n, axis_z));
	vec3 a = abs(d);
	if (a.x >= a.y && a.x >= a.z) {
		NORMAL = axis_x * sign(d.x);
	} else if (a.y >= a.z) {
		NORMAL = axis_y * sign(d.y);
	} else {
		NORMAL = axis_z * sign(d.z);
	}
	vec3 albedo = srgb_to_linear(COLOR.rgb) * hide_grain(rest);
	if (stone > 0.0) {
		float n = fract(sin(dot(floor(rest * 64.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		float stoned = step(rest.y / body_top, stone * 1.1 - 0.05 + (n - 0.5) * 0.1);
		albedo = mix(albedo, stone_rock(COLOR.rgb, n), stoned);
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness_value;
}
