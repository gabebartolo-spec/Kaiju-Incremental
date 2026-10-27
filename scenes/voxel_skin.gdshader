shader_type spatial;
// D-041: a kaiju's voxels as rigid cubes on a smooth skin (scenes/voxel_skin.gd). One MultiMesh
// instance per voxel; its transform is the voxel's rest centre, INSTANCE_CUSTOM its bones as small
// whole numbers (half precision safe: the compatibility renderer stores per-instance data that
// way), COLOR.rgb its sRGB colour and COLOR.a its second bone's weight. Each cube's centre follows
// its blended bones (smooth); it turns with its main bone's rotation (cubes of one bone stay on
// one tidy grid) and keeps its size.

// The stone's colour, variation and kept shade: one formula with the pieces that fly off when he
// shatters (death_stone.gdshader).
#include "res://scenes/stone_body.gdshaderinc"
// Render plan item 14 (tuning render_opt.kaiju_three_faces): each cube drawn as three faces.
#include "res://scenes/voxel_three_faces.gdshaderinc"

uniform mat4 bones[128];
// The cubes' own node back to skin (rig) space, so the shader can read each instance's centre.
uniform mat4 to_skin;
// Where a cube's bones disagree the blended basis shrinks: grow the cube by that much times this.
uniform float gap_fill = 1.0;
// Cubes keep one size: growth is off by default (lead review round 2); the filler covers gaps.
uniform float max_grow = 0.0;
// 0 = jaw shut (mouth inside drawn as a dark lip seam), 1 = open or a snarl (its pink shows).
uniform float mouth_open = 0.0;
uniform float seam_dark = 0.22;
uniform float roughness_value = 0.9;
// On: the mesh is ThreeFaceCube's +X, +Y, +Z faces, mirrored per cube to the camera's sides.
uniform bool three_faces = false;
// The Special K overload as he dies (scenes/death_view.gd, DeathOverload): `overload` 0..1 lights
// a share of the cubes violet, flickering cube by cube (the crackle); `stone` 0..1 turns him to
// stone from the feet up to body_top (rest height, skin units), a ragged front cube by cube. A
// stone cube keeps stone_keep of its own shade and varies by stone_vary: textured, never flat.
uniform float overload = 0.0;
uniform vec3 overload_color : source_color = vec3(0.54, 0.24, 1.0);
uniform float crackle_share = 0.18;
uniform float crackle_hz = 14.0;
uniform float crackle_energy = 2.2;
uniform float stone = 0.0;
uniform float body_top = 10.0;

// Faint wounds (SkinHits): xyz a point in the cubes' rest space (it rides the bones), w its strength
// (0 = none, fading over minutes). A cube within wound_radius of one darkens to a wet, dull mark.
uniform vec4 wounds[48];
uniform float wound_radius = 0.2;
uniform vec3 wound_tint : source_color = vec3(0.1, 0.01, 0.012);

varying vec3 tint;
varying vec3 rest;
varying vec3 rest_pos;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float first = floor(c.x + 0.5);
	int b0 = int(mod(first, 128.0));
	float mouth = floor(first / 128.0);
	int b1 = int(c.y + 0.5);
	int b2 = int(c.z + 0.5);
	float w0 = floor(c.w + 0.5) / 255.0;
	float w1 = COLOR.a;
	float w2 = max(0.0, 1.0 - w0 - w1);
	vec3 centre = (to_skin * MODEL_MATRIX)[3].xyz;
	mat4 blend = bones[b0] * w0 + bones[b1] * w1 + bones[b2] * w2;
	vec3 moved = (blend * vec4(centre, 1.0)).xyz;
	float shrink = 1.0 - min(length(blend[0].xyz), min(length(blend[1].xyz), length(blend[2].xyz)));
	float grow = 1.0 + min(max_grow, gap_fill * max(0.0, shrink));
	// The main bone's turn only: its scale (a gait's swell or stretch) never reaches a cube, so
	// every cube keeps one size and square axes (lead review round 2: no slats).
	mat3 m = mat3(bones[b0]);
	vec3 ax = normalize(m[0]);
	vec3 ay = normalize(m[1] - ax * dot(ax, m[1]));
	mat3 turn = mat3(ax, ay, cross(ax, ay));
	vec3 local = VERTEX;
	vec3 n = NORMAL;
	if (three_faces) {
		three_faces_mirror(local, n, moved - centre, turn, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	}
	rest_pos = centre + local;
	// The engine adds the instance's centre back after this.
	VERTEX = (moved - centre) + turn * (local * grow);
	NORMAL = normalize(turn * n);
	tint = COLOR.rgb;
	rest = centre;
	if (mouth > 0.5) {
		tint = mix(tint * seam_dark, tint, mouth_open);
	}
}

float cube_hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	vec3 albedo = srgb_to_linear(tint);
	float n = cube_hash(floor(rest * 64.0));
	float stoned = 0.0;
	if (stone > 0.0) {
		float front = stone * 1.1 - 0.05 + (n - 0.5) * 0.1;
		stoned = step(rest.y / body_top, front);
		albedo = mix(albedo, stone_rock(tint, n), stoned);
	}
	float mark = 0.0;
	for (int i = 0; i < 48; i++) {
		if (wounds[i].w <= 0.0) {
			continue;
		}
		// A ragged edge: the radius wobbles with the point's own position, the same every frame.
		float wobble = 0.75 + 0.5 * fract(sin(dot(floor(rest_pos / (wound_radius * 0.35)), vec3(12.9, 78.2, 37.7))) * 43758.5);
		float d = distance(rest_pos, wounds[i].xyz) / (wound_radius * wobble);
		mark = max(mark, wounds[i].w * (1.0 - smoothstep(0.55, 1.0, d)));
	}
	ALBEDO = mix(albedo, wound_tint, mark * 0.8);
	ROUGHNESS = mix(mix(roughness_value, 1.0, stoned), 0.3, mark);
	if (overload > 0.0) {
		float flick = cube_hash(floor(rest * 64.0) + floor(TIME * crackle_hz));
		float lit = step(1.0 - crackle_share * overload, flick) * (1.0 - 0.6 * stoned);
		EMISSION = overload_color * crackle_energy * overload * lit;
	}
}
