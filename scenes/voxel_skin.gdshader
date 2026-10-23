shader_type spatial;
// D-041: a kaiju's voxels as rigid cubes on a smooth skin (scenes/voxel_skin.gd). One MultiMesh
// instance per voxel; its transform is the voxel's rest centre, INSTANCE_CUSTOM its bones as small
// whole numbers (half precision safe: the compatibility renderer stores per-instance data that
// way), COLOR.rgb its sRGB colour and COLOR.a its second bone's weight. Each cube's centre follows
// its blended bones (smooth); it turns with its main bone's rotation (cubes of one bone stay on
// one tidy grid) and keeps its size.

#include "res://scenes/voxel_breath.gdshaderinc"

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
// The eyes' cubes turn to the lid's colour (sRGB) as `blink` goes 0 to 1 (D-165).
uniform float blink = 0.0;
uniform vec3 lid_colour = vec3(0.0);

varying vec3 tint;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float first = floor(c.x + 0.5);
	int b0 = int(mod(first, 128.0));
	float flag = floor(first / 128.0);
	int b1 = int(c.y + 0.5);
	int b2 = int(c.z + 0.5);
	float w0 = floor(c.w + 0.5) / 255.0;
	float w1 = COLOR.a;
	float w2 = max(0.0, 1.0 - w0 - w1);
	vec3 centre = (to_skin * MODEL_MATRIX)[3].xyz;
	mat4 blend = bones[b0] * w0 + bones[b1] * w1 + bones[b2] * w2;
	vec3 moved = (blend * vec4(centre, 1.0)).xyz;
	moved += breath_push(moved, w0 * breath_k[b0] + w1 * breath_k[b1] + w2 * breath_k[b2]);
	float shrink = 1.0 - min(length(blend[0].xyz), min(length(blend[1].xyz), length(blend[2].xyz)));
	float grow = 1.0 + min(max_grow, gap_fill * max(0.0, shrink));
	// The main bone's turn only: its scale (a gait's swell or stretch) never reaches a cube, so
	// every cube keeps one size and square axes (lead review round 2: no slats).
	mat3 m = mat3(bones[b0]);
	vec3 ax = normalize(m[0]);
	vec3 ay = normalize(m[1] - ax * dot(ax, m[1]));
	mat3 turn = mat3(ax, ay, cross(ax, ay));
	// The engine adds the instance's centre back after this.
	VERTEX = (moved - centre) + turn * (VERTEX * grow);
	NORMAL = normalize(turn * NORMAL);
	tint = COLOR.rgb;
	if (flag > 0.5 && flag < 1.5) {
		tint = mix(tint * seam_dark, tint, mouth_open);
	} else if (flag > 1.5) {
		// The lid is skin: the mean colour, mottled cube by cube like the skin round it.
		float mottle = 0.8 + 0.4 * fract(sin(dot(centre, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		tint = mix(tint, lid_colour * mottle, blink);
	}
}

void fragment() {
	ALBEDO = srgb_to_linear(tint);
	ROUGHNESS = roughness_value;
}
