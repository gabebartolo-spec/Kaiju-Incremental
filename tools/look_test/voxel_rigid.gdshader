shader_type spatial;
// Look test panel C: every cube moves rigidly. Its centre follows the blended (smooth) skin, its
// rotation is the blend of its bones' rotations made orthonormal again, so near a joint cubes
// turn and overlap a little instead of shearing into slabs. Skinning happens here, not in a
// Skeleton3D: kaiju_skin.gd uploads each bone's skin matrix (pose * inverse bind) every frame.
// CUSTOM0.xyz = the cube's rest centre, CUSTOM1 = 4 bone indices, CUSTOM2 = their weights.
// COLOR is sRGB (as voxel.gdshader).

uniform mat4 bones[32];
uniform float cube_scale = 1.0;
// Where a cube's bones disagree (a bending joint) the blended basis shrinks; grow the cube by
// that much times gap_fill so the stretched side stays closed. Zero at rest: no z-fighting.
uniform float gap_fill = 1.0;
// 1 = each cube takes its main bone's rotation (cubes of one bone stay on one tidy grid; the
// centre still follows the smooth skin); 0 = the orthonormalised blend of all its bones.
uniform float snap_turn = 1.0;
uniform float roughness_value = 0.9;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec3 centre = CUSTOM0.xyz;
	mat4 blend = mat4(0.0);
	for (int k = 0; k < 4; k++) {
		blend += bones[int(CUSTOM1[k] + 0.5)] * CUSTOM2[k];
	}
	vec3 moved = (blend * vec4(centre, 1.0)).xyz;
	// Gram-Schmidt: the blended basis loses length and squareness between bones; keep only its turn.
	float shrink = 1.0 - min(length(blend[0].xyz), min(length(blend[1].xyz), length(blend[2].xyz)));
	float grow = cube_scale * (1.0 + gap_fill * max(0.0, shrink));
	vec3 x = normalize(blend[0].xyz);
	vec3 y = normalize(blend[1].xyz - x * dot(x, blend[1].xyz));
	vec3 z = cross(x, y);
	mat3 turn = mat3(x, y, z);
	if (snap_turn > 0.5) {
		turn = mat3(bones[int(CUSTOM1[0] + 0.5)]);
	}
	// Bone matrices carry no scale (rig space), so a rigid cube keeps its size.
	VERTEX = moved + turn * ((VERTEX - centre) * grow);
	NORMAL = turn * NORMAL;
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = roughness_value;
}
