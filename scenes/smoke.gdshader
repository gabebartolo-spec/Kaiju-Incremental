shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Soft billboard smoke puff: a round, noisy, dark mass that is lit dimly by the scene and
// thins out at its edges. Colour and alpha come from the particle (COLOR).

uniform float softness = 0.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	// Face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float n = noise(UV * 5.0 + COLOR.rg * 13.0) * 0.6 + noise(UV * 11.0) * 0.4;
	float round_mask = 1.0 - smoothstep(softness, 1.0, length(p) + (n - 0.5) * 0.5);
	ALBEDO = COLOR.rgb * (0.75 + 0.35 * n);
	ROUGHNESS = 1.0;
	ALPHA = COLOR.a * round_mask;
}
