shader_type spatial;
render_mode cull_disabled;
// Look-boards mock C (capture-only branch): the croc titan's own Tripo mesh and texture, linearly
// skinned by the same bone matrices the voxel skin uses (VoxelSkin.pose: rest rig space -> posed rig
// space). CUSTOM0 = the four bones, CUSTOM1 = their weights.

uniform mat4 bones[128];
uniform sampler2D albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float roughness_value = 0.85;

void vertex() {
	mat4 blend = bones[int(CUSTOM0.x + 0.5)] * CUSTOM1.x
		+ bones[int(CUSTOM0.y + 0.5)] * CUSTOM1.y
		+ bones[int(CUSTOM0.z + 0.5)] * CUSTOM1.z
		+ bones[int(CUSTOM0.w + 0.5)] * CUSTOM1.w;
	VERTEX = (blend * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize(mat3(blend) * NORMAL);
}

void fragment() {
	ALBEDO = texture(albedo, UV).rgb;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
