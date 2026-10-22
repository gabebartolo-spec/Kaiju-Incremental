shader_type spatial;
// One ragged flame of a burning window seen from far away (scenes/far_fire.gd): a quad torn into
// a jagged tongue by noise that rolls upward, wide at its foot, its colour and alpha from the
// particle (COLOR: hot pale yellow at birth, orange, red, dark at the end). Every particle has
// its own tear, from its place in the world. Camera-facing, added over the scene.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float speed = 1.6;
uniform float ragged = 1.0;

varying float flame_seed;

void vertex() {
	flame_seed = fract(sin(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 40.0;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 7.3) * 0.3 + vnoise(p * 4.3 + 3.1) * 0.15;
}

void fragment() {
	float y = 1.0 - UV.y;  // 0 at the foot, 1 at the tip
	float x = (UV.x - 0.5) * 2.0;
	float n = fbm(vec2(x * 1.8 + flame_seed, y * 2.8 - TIME * speed));
	float n2 = fbm(vec2(x * 3.4 - flame_seed, y * 5.5 - TIME * speed * 1.7));
	float width = (1.0 - pow(y, 0.7)) * 0.85 + 0.1;
	width += (n - 0.5) * ragged * (0.4 + y);
	float body = smoothstep(width, width - 0.16, abs(x + (n2 - 0.5) * 0.5 * y));
	float tip = smoothstep(1.0, 0.4, y + (n2 - 0.5) * 0.6);
	float foot = smoothstep(0.0, 0.14, y + (n2 - 0.5) * 0.08);
	float m = body * tip * foot;
	float heat = clamp(m * (1.3 - y), 0.0, 1.0);
	ALBEDO = COLOR.rgb * (0.55 + 0.45 * heat);
	ALPHA = clamp(m, 0.0, 1.0) * COLOR.a;
}
