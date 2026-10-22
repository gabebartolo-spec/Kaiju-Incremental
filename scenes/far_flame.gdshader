shader_type spatial;
// A ragged flame seen from far away (the title's burning towers): a tongue that is wide at its foot
// and torn at its edges and tip by noise that rolls upward, hot yellow at the core and orange-red
// at the rim. A camera-facing quad, added over the scene (scenes/far_fire.gd).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 outer_colour : source_color = vec3(1.0, 0.35, 0.05);
uniform vec3 core_colour : source_color = vec3(1.0, 0.85, 0.4);
uniform float speed = 1.4;
uniform float seed = 0.0;
uniform float intensity = 0.8;
uniform float ragged = 0.9;

void vertex() {
	// Face the camera, keep the node's scale.
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
	float n = fbm(vec2(x * 1.6 + seed, y * 2.6 - TIME * speed));
	float n2 = fbm(vec2(x * 3.2 - seed, y * 5.0 - TIME * speed * 1.7));
	// Several tongues: the width breathes up the flame and the noise tears it.
	float width = (1.0 - pow(y, 0.8)) * 0.9 + 0.12;
	width += (n - 0.5) * ragged * (0.35 + y);
	float body = smoothstep(width, width - 0.28, abs(x + (n2 - 0.5) * 0.35 * y));
	float tip = smoothstep(1.0, 0.45, y + (n2 - 0.5) * 0.5);
	float foot = smoothstep(0.0, 0.16, y + (n2 - 0.5) * 0.08);
	float m = body * tip * foot;
	float heat = clamp(m * (1.25 - y * 0.9) + (n2 - 0.5) * 0.2, 0.0, 1.0);
	ALBEDO = mix(outer_colour, core_colour, heat * heat) * intensity;
	ALPHA = clamp(m, 0.0, 1.0);
}
