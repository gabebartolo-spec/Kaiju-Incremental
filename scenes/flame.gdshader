shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled;
// The game's flame (docs/VFX_STYLE.md family 1, director 2026-10-23: "Smooth flames"): a camera-facing
// tongue per particle, a teardrop with a noisy flickering edge tapering to a point and an uneven,
// ragged foot. Colour is graded by HEIGHT above the fire's base, the same for every tongue (so
// overlapping tongues agree): a dark red-orange foot, orange body, red, then dark red-brown tips; a
// soft yellow-white heart low in the body, and each tongue edged a deeper red so tongues read against
// one another. Opaque to the edge (no haze, no ghost strips). The particle's colour carries only its
// alpha (life fade); a tongue's seed is its particle index mixed with the fire's own `fire_seed`, so
// every fire is its own. Owner: Fire (scenes/fire.gd); the helicopter's fireball and the blast use it.

uniform float heat = 0.88;  // under the bloom threshold: the body stays saturated, never cream
uniform float base_y = 0.0;  // the fire's floor (world y), kept up to date by its owner
uniform float flame_h = 2.5;  // how high the ramp runs (metres) before the tips are dark red
uniform float fire_seed = 0.0;

varying float tongue;

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
	tongue = hash(vec2(float(INSTANCE_ID) * 0.37 + fire_seed, fire_seed * 1.7 + 3.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float hw = clamp((wp.y - base_y) / flame_h, 0.0, 1.0);
	float seed = tongue;
	float tall = 0.78 + 0.44 * seed;  // each tongue its own height
	float h = (1.0 - UV.y) / tall;  // 0 foot, 1 tip
	float x = (UV.x - 0.5) * 2.0 - (seed - 0.5) * 0.5 * h;  // and its own lean
	float foot = 0.03 + 0.08 * fract(seed * 7.3) + 0.04 * noise(vec2(UV.x * 11.0, seed * 31.0));
	float width = (1.0 - pow(clamp(h, 0.0, 1.0), 0.8)) * (0.35 + 0.65 * sin(clamp(h * 3.0, 0.0, 1.5708)));
	width *= mix(0.4, 1.0, smoothstep(foot, foot + 0.25, h));  // a rounded, uneven foot: no flat cut, no toes
	float n = noise(vec2(UV.x * 6.0 + seed * 20.0, UV.y * 5.0 - TIME * 3.0));
	float d = abs(x) / max(width, 0.001) + (n - 0.5) * 0.7 * (0.4 + h);
	float mask = 1.0 - smoothstep(0.55, 1.0, d);
	mask *= 1.0 - smoothstep(0.92, 1.0, h);
	mask *= smoothstep(foot - 0.02, foot + 0.05, h);
	vec3 base = vec3(0.70, 0.20, 0.05);
	vec3 orange = vec3(1.0, 0.40, 0.06);
	vec3 red = vec3(0.94, 0.23, 0.05);
	vec3 deep = vec3(0.50, 0.11, 0.06);
	vec3 c = mix(base, orange, smoothstep(0.02, 0.2, hw));
	c = mix(c, red, smoothstep(0.3, 0.55, hw));
	c = mix(c, deep, smoothstep(0.62, 0.95, hw));
	// the heart: a soft yellow-white band a little way up the body, broken up, in most tongues
	float band = smoothstep(0.03, 0.1, hw) * (1.0 - smoothstep(0.24, 0.42, hw));
	float heart = band * (1.0 - smoothstep(0.0, 0.62, abs(x))) * (0.6 + 0.4 * n) * (0.5 + 0.5 * step(0.3, fract(seed * 3.7)));
	c = mix(c, mix(vec3(1.0, 0.78, 0.30), vec3(1.0, 0.95, 0.74), smoothstep(0.5, 0.9, heart)), smoothstep(0.1, 0.4, heart));
	float rim = smoothstep(0.35, 0.95, d);  // each tongue edged deeper red
	c *= (0.9 + 0.2 * fract(seed * 13.7)) * mix(1.0, 0.62, rim);
	c = mix(c, red * 0.6, rim * 0.4);
	ALBEDO = c * heat * (1.0 + 0.4 * smoothstep(0.55, 0.9, heart));
	ALPHA = smoothstep(0.3, 0.62, mask) * COLOR.a;  // hard edges: no ghost haze
}
