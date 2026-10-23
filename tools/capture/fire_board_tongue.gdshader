shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled;
// FIRE BOARD (capture only, not the game's look): ONE flame design drawn two ways. A camera-facing
// tongue per particle: a teardrop mask with a noisy, flickering edge tapering to a point, a ragged
// foot, colour graded by height (dark red-orange foot, orange body, red then dark red-brown tips)
// and a soft yellow-white heart band low in the flame. `cell` 0: smooth, as is. `cell` above 0:
// the very same flame snapped to a grid of cells that size (world units), hard cell edges, each
// cell coloured from the same height ramp (a touch of per-cell variation, like voxels).
// The particle's colour carries alpha (a) and the tongue's seed (r).

uniform float heat = 0.88;  // under the bloom threshold: the body stays saturated
uniform float cell = 0.0;
uniform vec2 quad_size = vec2(1.15, 2.7);
// Where the fire stands (world): colour is graded by height above `base_y` over `flame_h`, the same for
// every tongue, so overlapping tongues agree (a short tongue's orange never covers a tall one's red tip).
uniform float base_y = 0.0;
uniform float flame_h = 2.5;
uniform vec2 axis = vec2(0.0);
uniform float half_w = 0.7;

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
	vec2 uv = UV;
	float jitter = 1.0;
	if (cell > 0.0) {
		vec2 step_uv = vec2(cell) / quad_size;
		uv = (floor(UV / step_uv) + 0.5) * step_uv;
		jitter = 0.92 + 0.16 * hash(floor(UV / step_uv) + vec2(COLOR.r * 57.0));
	}
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (cell > 0.0) {
		wp.y = (floor(wp.y / cell) + 0.5) * cell;
	}
	float hw = clamp((wp.y - base_y) / flame_h, 0.0, 1.0);
	float seed = COLOR.r;
	float tall = 0.78 + 0.44 * seed;  // each tongue its own height
	float h = (1.0 - uv.y) / tall;  // 0 foot, 1 tip
	float x = (uv.x - 0.5) * 2.0 - (seed - 0.5) * 0.5 * h;  // and its own lean
	float width = (1.0 - pow(clamp(h, 0.0, 1.0), 0.8)) * (0.35 + 0.65 * sin(clamp(h * 3.0, 0.0, 1.5708)));
	float n = noise(vec2(uv.x * 6.0 + seed * 20.0, uv.y * 5.0 - TIME * 3.0));
	float d = abs(x) / max(width, 0.001) + (n - 0.5) * 0.7 * (0.4 + h);
	float mask = 1.0 - smoothstep(0.55, 1.0, d);
	mask *= 1.0 - smoothstep(0.92, 1.0, h);
	float foot = 0.05 + 0.1 * fract(seed * 7.3) + 0.06 * noise(vec2(uv.x * 11.0, seed * 31.0));
	mask *= smoothstep(foot, foot + 0.12, h);  // an uneven, ragged foot: no flat cut, no equal toes
	vec3 base = vec3(0.70, 0.20, 0.05);
	vec3 orange = vec3(1.0, 0.40, 0.06);
	vec3 red = vec3(0.94, 0.23, 0.05);
	vec3 deep = vec3(0.50, 0.11, 0.06);
	vec3 c = mix(base, orange, smoothstep(0.02, 0.2, hw));
	c = mix(c, red, smoothstep(0.3, 0.55, hw));
	c = mix(c, deep, smoothstep(0.62, 0.95, hw));
	// the heart: a soft yellow-white band a little way up the body, at the fire's middle, broken up
	float radial = length(wp.xz - axis) / half_w;
	float band = smoothstep(0.03, 0.1, hw) * (1.0 - smoothstep(0.24, 0.42, hw));
	float heart = band * (1.0 - smoothstep(0.0, 0.62, abs(x))) * (0.6 + 0.4 * n) * (0.5 + 0.5 * step(0.3, fract(seed * 3.7)));
	c = mix(c, mix(vec3(1.0, 0.78, 0.30), vec3(1.0, 0.95, 0.74), smoothstep(0.5, 0.9, heart)), smoothstep(0.1, 0.4, heart));
	float rim = smoothstep(0.35, 0.95, d);  // each tongue edged deeper red: tongues read against each other
	c *= (0.9 + 0.2 * fract(seed * 13.7)) * mix(1.0, 0.62, rim);
	c = mix(c, red * 0.6, rim * 0.4);
	ALBEDO = c * heat * jitter * (1.0 + 0.4 * smoothstep(0.55, 0.9, heart));
	float a = cell > 0.0 ? step(0.5, mask) : smoothstep(0.3, 0.62, mask);  // hard edges: no ghost haze
	ALPHA = a * COLOR.a;
}
