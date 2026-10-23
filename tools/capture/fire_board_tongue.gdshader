shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled;
// FIRE BOARD treatment C (capture only): a camera-facing soft tongue per particle, a teardrop mask
// with a noisy edge that tapers to a point at the top, graded by height within the tongue (white-yellow
// foot, orange body, red then dark red-brown tip), like a long exposure of real flame. Colour from
// the quad's own UV: v 1 is the foot, 0 the tip. The particle's colour carries alpha and a seed.

uniform float heat = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}

void fragment() {
	float h = 1.0 - UV.y;  // 0 foot, 1 tip
	float x = (UV.x - 0.5) * 2.0;
	float width = (1.0 - pow(h, 0.8)) * (0.35 + 0.65 * sin(clamp(h * 3.0, 0.0, 1.5708)));  // teardrop, a point at the tip
	float n = noise(vec2(UV.x * 6.0 + COLOR.r * 20.0, UV.y * 5.0 - TIME * 3.0));
	float d = abs(x) / max(width, 0.001) + (n - 0.5) * 0.55 * (0.4 + h);
	float mask = 1.0 - smoothstep(0.55, 1.0, d);
	mask *= 1.0 - smoothstep(0.82, 1.0, h);
	vec3 base = vec3(0.60, 0.13, 0.05);
	vec3 orange = vec3(1.0, 0.40, 0.06);
	vec3 red = vec3(0.86, 0.20, 0.04);
	vec3 deep = vec3(0.34, 0.08, 0.05);
	vec3 c = mix(base, orange, smoothstep(0.0, 0.16, h));
	c = mix(c, red, smoothstep(0.25, 0.5, h));
	c = mix(c, deep, smoothstep(0.5, 0.85, h));
	float core = (1.0 - smoothstep(0.05, 0.34, h)) * (1.0 - smoothstep(0.0, 0.55, abs(x)));
	c = mix(c, mix(vec3(1.0, 0.8, 0.38), vec3(1.0, 0.94, 0.72), core), core);
	ALBEDO = c * heat;
	ALPHA = mask * COLOR.a;
}
