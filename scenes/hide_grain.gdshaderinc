// D-398: the kaiju's own hide grain (not the city's block grain): small scutes with dark crevices
// between them, a tone shift scute to scute and a few pale or dark flecks. Sampled at a point in
// the hide's rest space (rides the bones: never swims), seeded, the same every frame. Numbers from
// data/looks.json kaiju_hide_* (Look.hide_params). The flat-surface test counts this include as
// a textured surface (tests/lib/flat_surfaces.gd HIDE_INCLUDE).

// One scute's width (rest-space units: voxel x kaiju_hide_cell_voxels).
uniform float hide_cell = 0.05;
uniform float hide_crevice = 0.35;
uniform float hide_crevice_width = 0.12;
uniform float hide_tone = 0.1;
uniform float hide_fleck = 0.05;
uniform float hide_fleck_dark = 0.3;
uniform float hide_seed = 0.0;

vec3 hide_hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// The albedo multiplier at rest-space point p (1 = untouched).
float hide_grain(vec3 p) {
	vec3 q = p / hide_cell + hide_seed;
	vec3 i = floor(q);
	vec3 f = q - i;
	float d1 = 8.0;
	float d2 = 8.0;
	vec3 best = i;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 o = vec3(float(x), float(y), float(z));
				vec3 r = o + hide_hash3(i + o) - f;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					best = i + o;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	float edge = sqrt(d2) - sqrt(d1);
	float crevice = 1.0 - smoothstep(0.0, hide_crevice_width, edge);
	vec3 h = hide_hash3(best + 17.0);
	float tone = 1.0 + (h.x - 0.5) * 2.0 * hide_tone;
	float fleck = step(1.0 - hide_fleck, h.y) * (h.z > 0.5 ? 1.0 : -1.0);
	return tone * (1.0 - hide_crevice * crevice) * (1.0 - hide_fleck_dark * fleck);
}
