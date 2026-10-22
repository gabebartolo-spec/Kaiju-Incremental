shader_type spatial;
// A billowing smoke puff seen from far away (scenes/far_fire.gd): a round mass with a ragged,
// noisy edge and an uneven body, so a column of them reads as roiling smoke. Colour and alpha come
// from the particle (COLOR: lit orange just above the fire, grey, then dark and thin with height),
// unlit, so the colour is exactly the ramp and never tints the sky above. Camera-facing.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

varying float puff_seed;

void vertex() {
	puff_seed = fract(sin(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 30.0;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float n = vnoise(UV * 4.0 + puff_seed) * 0.6 + vnoise(UV * 9.0 - puff_seed) * 0.4;
	float edge = length(p) + (n - 0.5) * 0.75;
	float mass = 1.0 - smoothstep(0.25, 1.0, edge);
	ALBEDO = COLOR.rgb * (0.8 + 0.4 * n);
	ALPHA = COLOR.a * mass * (0.65 + 0.7 * n);
}
