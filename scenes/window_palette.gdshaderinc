// Lived-in windows (render plan item 6; WindowPalette is the CPU side and its replica): each lit
// window picks one colour from the look's palette (linear, cumulative shares) and its own
// brightness, by a hash of the window the layout lit as a whole. Off (window_palette_on false):
// every lit window keeps its baked single colour.

uniform bool window_palette_on = false;
uniform vec3 window_palette[8];
uniform float window_weight_end[8];
uniform int window_palette_size = 0;
uniform vec2 window_gain = vec2(1.0, 1.0);
// (bays, floors) per lit window above the ground floor, and where the world grid of those
// units starts for this building (its min corner x, z modulo the unit's width).
uniform vec2 window_unit = vec2(1.0, 1.0);
uniform vec2 window_align = vec2(0.0);
uniform float window_voxel = 0.125;

// A lit window's colour alpha is 1/255 (WindowPalette.TAG): it glows like alpha 0 and is told
// apart from neon, beacons and signs.
bool window_tagged(float a) {
	return a > 0.5 / 255.0 && a < 1.5 / 255.0;
}

// lowbias32 (Chris Wellons); WindowPalette._mix.
uint window_mix(uint v) {
	uint x = v;
	x ^= x >> 16u;
	x *= 2146121005u;
	x ^= x >> 15u;
	x *= 2221713035u;
	x ^= x >> 16u;
	return x;
}

// The lit window a point inside a window voxel falls in, as a world grid cell
// (WindowPalette.window_key), hashed (WindowPalette.window_hash).
uint window_hash(vec3 cell_point) {
	vec3 at = cell_point - vec3(window_voxel * 0.5);
	vec2 u = at.y < 1.0 ? vec2(1.0) : window_unit;
	vec3 grid = vec3((at.x - window_align.x) / u.x, at.y / u.y, (at.z - window_align.y) / u.x);
	ivec3 k = ivec3(floor(grid));
	uint h = window_mix(uint(k.x));
	h = window_mix(h ^ uint(k.y));
	return window_mix(h ^ uint(k.z));
}

// rgb: the window's linear colour; a: its brightness (WindowPalette.pick).
vec4 window_pick(uint h) {
	float u = float(h & 65535u) / 65536.0;
	int index = 0;
	for (int i = 0; i < 7; i++) {
		if (i < window_palette_size - 1 && u >= window_weight_end[i]) {
			index = i + 1;
		}
	}
	float gain = mix(window_gain.x, window_gain.y, float(h >> 16u) / 65535.0);
	return vec4(window_palette[index], gain);
}
