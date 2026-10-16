shader_type spatial;
// D-041: a kaiju's voxels as rigid cubes on a smooth skin (scenes/voxel_skin.gd). One MultiMesh
// instance per voxel, its transform left at identity; INSTANCE_CUSTOM carries the voxel (packed as
// exact floats, see VoxelSkin.pack()). Each cube's centre follows its blended bones (smooth), it
// turns with its main bone (cubes of one bone stay on one tidy grid), and grows a little where its
// bones disagree so a bending joint stays closed. INSTANCE COLOR is sRGB (as voxel.gdshader).

uniform mat4 bones[128];
uniform float voxel = 0.0625;
uniform float inset = 0.99;
// Where a cube's bones disagree the blended basis shrinks: grow the cube by that much times this.
uniform float gap_fill = 1.0;
// 0 = jaw shut (mouth inside drawn as a dark lip seam), 1 = open (its pink shows).
uniform float mouth_open = 0.0;
uniform float seam_dark = 0.22;
uniform float roughness_value = 0.9;

varying vec3 tint;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 cell = vec3(mod(c.x, 1024.0), floor(c.x / 1024.0), mod(c.y, 1024.0)) - 512.0;
	float mouth = floor(c.y / 1024.0);
	int b0 = int(mod(c.z, 128.0));
	int b1 = int(mod(floor(c.z / 128.0), 128.0));
	int b2 = int(floor(c.z / 16384.0));
	float w0 = mod(c.w, 256.0) / 255.0;
	float w1 = floor(c.w / 256.0) / 255.0;
	float w2 = max(0.0, 1.0 - w0 - w1);
	vec3 centre = (cell + vec3(0.0, 0.5, 0.0)) * voxel;
	mat4 blend = bones[b0] * w0 + bones[b1] * w1 + bones[b2] * w2;
	vec3 moved = (blend * vec4(centre, 1.0)).xyz;
	float shrink = 1.0 - min(length(blend[0].xyz), min(length(blend[1].xyz), length(blend[2].xyz)));
	mat3 turn = mat3(bones[b0]);
	VERTEX = moved + turn * (VERTEX * (1.0 + gap_fill * max(0.0, shrink)));
	NORMAL = normalize(turn * NORMAL);
	tint = COLOR.rgb;
	if (mouth > 0.5) {
		tint = mix(tint * seam_dark, tint, mouth_open);
	}
}

void fragment() {
	ALBEDO = srgb_to_linear(tint);
	ROUGHNESS = roughness_value;
}
