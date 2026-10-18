shader_type spatial;
// The stadium crowd's seated fans (StadiumCrowd): voxel.gdshader's colours plus an idle bob,
// a little hop on each fan's own beat, done here so a seated crowd costs no work per frame.

uniform float bob = 0.05;
uniform vec2 bob_hz = vec2(1.2, 2.4);
uniform float roughness_value = 0.9;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	float h = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	float hz = mix(bob_hz.x, bob_hz.y, h);
	VERTEX.y += bob * max(0.0, sin((TIME * hz + h) * 6.2831853));
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = roughness_value;
}
