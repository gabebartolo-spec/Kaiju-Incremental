// One surface family for the whole city (director 2026-10-25: "flat textureless colour blocks need to
// go"; #80: "all surfaces must be textured and visually beautiful"; D-163: "Fine blocks like the city").
// Every surface shader includes this file, so asphalt, concrete, paving and lawn all share one grain,
// one seeding and one set of numbers (data/looks.json "ground_*").
//
// How it stays blocks: every feature is evaluated at the CENTRE of the 0.125 m world block the pixel is
// in (sd_cell), so it is constant over the block and steps from block to block, never a smooth gradient
// and never a second block size. It is in world space, so it never swims with the camera. Seeded:
// sd_seed (the city's map seed) shifts every hash, so the same seed gives the same ground.
//
// The 0.125 m grain and the one-block specks fade to flat between fade_near and fade_far (a block is
// under a pixel there and would only shimmer); the 0.5-6 m features (mottle, wheel tracks, patches, stains,
// panel joints, damp bands) do NOT fade: they are what reads from the game camera.
//
// Surface looks: sd_asphalt (roads, lots, deck tops), sd_pavement, sd_lawn, sd_concrete (river walls,
// quays, parapets, deck sides), sd_paint (road paint, worn at its edges). Each takes the linear base
// colour and returns the linear albedo.

uniform float block = 0.125;
uniform float block_noise = 0.09;
uniform float patch_noise = 0.05;
uniform float speck_chance = 0.04;
uniform float speck_dark = 0.72;
uniform float seam = 0.05;
uniform float fade_near = 35.0;
uniform float fade_far = 80.0;
// The big features' strengths (0 = off).
uniform float mottle = 0.22;      // 2-6 m tone shifts of asphalt
uniform float track = 0.4;        // worn wheel tracks
uniform float tar = 0.5;          // tar seams and the lane joint
uniform float patch_dark = 0.4;   // rectangular repair patches
uniform float stain = 0.4;        // oil and grime blobs
uniform float gutter = 0.3;       // darker band at the kerb
uniform float panel = 0.16;       // panel-to-panel tone of cast concrete and paving
uniform float damp = 0.5;         // damp band and algae at the waterline
uniform float streak = 0.28;      // vertical water streaks on walls
uniform float soil = 0.55;        // bare soil showing through the lawn
uniform float paving = 0.14;      // paving slab tone steps
uniform float band_h = 1.2;       // height of the damp band above the water line (m)
uniform float night_floor = 0.0;  // at night: a faint self-lit glow that follows the surface's own variation
uniform float river_y = -1.6;     // the river's water height (city_ground's river_depth), for bridge fascias
uniform float seed = 0.0;

float sd_h(vec2 p) {
	vec3 q = fract((p.xyx + seed) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float sd_h3(vec3 p) {
	p = fract((p + seed) * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float sd_vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(sd_h(i), sd_h(i + vec2(1.0, 0.0)), u.x),
			mix(sd_h(i + vec2(0.0, 1.0)), sd_h(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Three octaves, the first `m` metres across; 0..1.
float sd_fbm(vec2 p, float m) {
	vec2 q = p / m;
	return 0.55 * sd_vn(q) + 0.3 * sd_vn(q * 2.3 + 17.0) + 0.15 * sd_vn(q * 5.1 + 43.0);
}

vec3 sd_srgb(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

// The surface's own 2D coordinates: x, z on a top face; along the wall and up on a side face.
vec2 sd_plane(vec3 q, vec3 n) {
	vec3 a = abs(n);
	if (a.y > 0.5) {
		return q.xz;
	}
	if (a.x > a.z) {
		return vec2(q.z, q.y);
	}
	return vec2(q.x, q.y);
}

// The centre of the block `p` is in.
vec2 sd_cell(vec2 p) {
	return (floor(p / block) + 0.5) * block;
}

// The 0.125 m grain: a brightness step per block, a 1 m patch step, dark specks, a faint seam; faded
// to 1 with distance. q is the world position nudged inside the face.
float sd_grain(vec3 q, float depth) {
	vec3 cell = floor(q / block);
	float h = sd_h3(cell) * 2.0 - 1.0;
	float patch_h = sd_h3(floor(q) + 17.0) * 2.0 - 1.0;
	float k = 1.0 + h * block_noise + patch_h * patch_noise;
	if (sd_h3(cell + 91.0) < speck_chance) {
		k *= speck_dark;
	}
	vec3 f = fract(q / block);
	vec3 edge = min(f, 1.0 - f);
	float e = min(min(edge.x, edge.y), edge.z);
	k *= 1.0 - seam * (1.0 - smoothstep(0.0, 0.06, e));
	return mix(1.0, k, 1.0 - smoothstep(fade_near, fade_far, depth));
}

// Asphalt. pc: the block centre (world x, z); along / lat: where that is along the street and across it
// from the centre line (m); half_w: half the street's width; road: 1 for a street (lanes, tracks, joints,
// gutters), 0 for plain asphalt (a lot, the land).
vec3 sd_asphalt(vec3 base, vec2 pc, float along, float lat, float half_w, float road, out float polish) {
	polish = 0.0;
	float tone = sd_fbm(pc, 5.0) - 0.5;
	float tone2 = sd_vn(pc / 1.3) - 0.5;
	float k = 1.0 + tone * 2.0 * mottle + tone2 * mottle * 0.8;
	vec3 col = base * k;
	// Lighter grey-brown where it is worn, bluer black where it is fresh.
	col *= mix(vec3(0.93, 0.98, 1.07), vec3(1.08, 1.02, 0.92), smoothstep(-0.18, 0.18, tone));
	float lane_w = 2.0 + step(5.0, half_w * 2.0);
	float u = (lat + half_w) / lane_w;
	float li = floor(u);
	float lm = (fract(u) - 0.5) * lane_w;
	float cell_a = road > 0.5 ? along : pc.x;
	float cell_l = road > 0.5 ? lm : pc.y;
	// Repair patches: a rectangle in some lanes, darker and bluer, with a lighter sealed rim.
	vec2 cc = road > 0.5 ? vec2(floor(along / 11.0), li) : floor(pc / 9.0);
	float span = road > 0.5 ? 11.0 : 9.0;
	float lw = road > 0.5 ? lane_w : 9.0;
	if (patch_dark > 0.0 && sd_h(cc * vec2(1.7, 3.1) + 5.0) < 0.42) {
		float a0 = road > 0.5 ? fract(along / 11.0) * 11.0 : fract(pc.x / 9.0) * 9.0;
		float l0 = road > 0.5 ? lm : (fract(pc.y / 9.0) - 0.5) * 9.0;
		float len = mix(1.4, 4.5, sd_h(cc + 11.0));
		float st = mix(0.4, span - len - 0.4, sd_h(cc + 23.0));
		float wid = mix(0.8, lw * 0.85, sd_h(cc + 37.0));
		float lo = (sd_h(cc + 53.0) - 0.5) * max(lw - wid, 0.0);
		vec2 d2 = abs(vec2(a0 - (st + len * 0.5), l0 - lo)) - vec2(len, wid) * 0.5;
		float dd = max(d2.x, d2.y);
		float inside = 1.0 - step(0.0, dd);
		float rim = inside * step(-0.13, dd);
		vec3 fresh = base * vec3(0.62, 0.66, 0.76) * (0.85 + 0.3 * sd_h(cc + 71.0));
		col = mix(col, fresh, clamp(inside * patch_dark * 2.0, 0.0, 1.0));
		polish = max(polish, inside * 0.6);
		col *= 1.0 + rim * 0.32;
	}
	// Oil and grime blobs.
	float oil = sd_vn(vec2(cell_a * 1.6, cell_l * 2.2 + li * 5.0));
	float oil_m = smoothstep(0.64, 0.82, oil);
	if (road > 0.5) {
		oil_m *= 1.0 - smoothstep(0.12, 0.6, abs(lm));
	} else {
		oil_m *= smoothstep(0.55, 0.8, sd_vn(pc / 7.0 + 31.0));
	}
	col *= mix(vec3(1.0), vec3(0.62, 0.68, 0.8), oil_m * stain * 1.6);
	polish = max(polish, clamp(oil_m * stain * 2.5, 0.0, 1.0));
	if (road < 0.5) {
		return col;
	}
	// Worn wheel tracks: two lighter polished strips in each lane, patchy along the street.
	float drift = (sd_vn(vec2(along / 4.0, li * 3.7)) - 0.5) * 0.22;
	float tr = 1.0 - smoothstep(0.08, 0.22, abs(abs(lm + drift) - 0.42));
	// Broken into short worn stretches and single blocks, so no cell is stretched along the road.
	float tmod = smoothstep(0.52, 0.78, sd_vn(vec2(along / 1.5, li * 7.3 + 3.0)) * 0.55 + sd_vn(vec2(along / 6.0, li * 2.1 + 8.0)) * 0.5);
	tmod *= 0.65 + 0.35 * sd_h(vec2(floor(along / block), li + 13.0));
	polish = max(polish, tr * (0.25 + 0.75 * tmod));
	col = col * (1.0 + track * 1.7 * tr * (0.1 + 0.9 * tmod)) + vec3(0.012, 0.012, 0.013) * track * tr * tmod;
	// Tar seams: cracks across the street every ~9 m, wobbling and broken.
	float sid = floor(along / 9.0);
	float spos = (sid + 0.15 + 0.7 * sd_h(vec2(sid, 9.0))) * 9.0;
	float wob = (sd_vn(vec2(lat * 2.6, sid)) - 0.5) * 0.5;
	float line = 1.0 - smoothstep(0.05, 0.15, abs(along - spos + wob));
	line *= step(0.3, sd_vn(vec2(lat * 1.1, sid * 3.3)));
	// ...and the lane joint where two lanes meet.
	float je = min(fract(u), 1.0 - fract(u)) * lane_w;
	float joint = (1.0 - smoothstep(0.05, 0.14, je)) * step(0.4, u) * step(u, floor(half_w * 2.0 / lane_w + 0.5) - 0.4);
	joint *= step(0.55, sd_vn(vec2(along / 1.3, 11.0)));
	col *= 1.0 - tar * 0.7 * clamp(line + joint * 0.8, 0.0, 1.0);
	// The kerb's gutter: darker, with grit swept into it.
	float kd = half_w - abs(lat);
	float gut = 1.0 - smoothstep(0.12, 0.75, kd);
	col *= 1.0 - gutter * gut * (0.7 + 0.5 * sd_vn(pc / 0.8));
	col *= 1.0 + 0.5 * gutter * gut * step(sd_h(pc * 8.0 + 3.0), 0.12);
	return col;
}

// Paving: 1 m flags with a tone each, joints, a darker kerb edge (kerb_d: m to the slab's edge), stains.
vec3 sd_pavement(vec3 base, vec2 pc, float kerb_d) {
	// True running bond: flags 1 m long, every second row shifted half a flag; the tone, grime and
	// cracks are seeded per flag, so the pattern never repeats.
	float row = floor(pc.y);
	float shift = mod(row, 2.0) * 0.5;
	float len = 1.0;
	vec2 fp = vec2((pc.x + shift) / len, pc.y);
	vec2 fc = vec2(floor(fp.x), row);
	float flag = sd_h(fc * 1.3 + 7.0) * 2.0 - 1.0;
	float k = 1.0 + flag * paving * 1.3 + (sd_fbm(pc, 3.5) - 0.5) * 0.18;
	k *= 1.0 + (sd_vn(pc / 0.45 + fc) - 0.5) * 0.1;  // each flag's own slight gradient
	vec2 f = vec2(fract(fp.x) * len, fract(pc.y));
	vec2 e = min(f, vec2(len, 1.0) - f);
	float joint = 1.0 - step(0.075, min(e.x, e.y));
	vec3 col = base * k;
	col *= 1.0 - 0.3 * joint;
	// Grime and sooty stains in blobs; a sparse hairline crack through some flags.
	float grime = smoothstep(0.6, 0.8, sd_vn(pc / 2.2 + 13.0));
	col *= 1.0 - 0.28 * grime * stain * 1.6;
	if (sd_h(fc + 29.0) < 0.14) {
		float cr = abs(fract((pc.x + pc.y * 0.7) * 1.0) - 0.5);
		col *= 1.0 - 0.3 * (1.0 - step(0.045, cr)) * step(0.35, sd_vn(pc * 3.0));
	}
	// Dirt along the kerb.
	col *= 1.0 - gutter * 0.9 * (1.0 - smoothstep(0.05, 0.5, kerb_d)) * (0.6 + 0.6 * sd_vn(pc / 0.7));
	return col;
}

// A lawn: mown stripes, tone drifts, tufts and bare soil.
vec3 sd_lawn(vec3 base, vec2 pc) {
	float tone = sd_fbm(pc, 3.5) - 0.5;
	float k = 1.0 + tone * 0.5 + (step(0.5, fract(pc.y / 2.2)) - 0.5) * 0.09;
	vec3 col = base * k;
	col *= mix(vec3(0.92, 0.98, 0.88), vec3(1.1, 1.04, 0.86), smoothstep(-0.12, 0.2, tone));
	float t = sd_h(floor(pc / 0.25) + 3.0);
	col *= 1.0 + 0.2 * step(t, 0.12) - 0.2 * step(0.88, t);
	float s = sd_fbm(pc + 71.0, 2.4);
	float soil_m = smoothstep(0.56, 0.66, s) * soil * 1.7;
	float crumb = 0.75 + 0.5 * sd_h(pc * 8.0);
	col = mix(col, vec3(0.085, 0.057, 0.034) * crumb, clamp(soil_m, 0.0, 0.92));
	return col;
}

// Cast concrete: panels, joints, a lift line, tie holes, water streaks, a damp algae band at the water
// line (water_y; below -50 means none), rust bleeding from joints, a darker soffit underneath.
// uv: the block centre in sd_plane coordinates; wy: the world height; n: the world normal.
vec3 sd_concrete(vec3 base, vec2 uv, float wy, vec3 n, float water_y) {
	bool top = n.y > 0.5;
	bool under = n.y < -0.5;
	vec2 psz = top || under ? vec2(3.0, 3.0) : vec2(3.2, 1.5);
	vec2 pg = uv / psz;
	vec2 pcell = floor(pg);
	float ptone = sd_h(pcell * 1.9 + 3.0) * 2.0 - 1.0;
	vec3 col = base * (1.0 + ptone * panel + (sd_fbm(uv, 4.0) - 0.5) * 0.3);
	col *= mix(vec3(0.95, 0.98, 1.04), vec3(1.05, 1.02, 0.96), sd_vn(uv / 1.7 + 5.0));
	vec2 pf = fract(pg) * psz;
	vec2 pe = min(pf, psz - pf);
	float joint = 1.0 - step(0.08, pe.x);
	float lift = 1.0 - step(0.075, pe.y);
	col *= 1.0 - 0.34 * clamp(joint + lift * 0.8, 0.0, 1.0);
	// Tie holes on a grid inside each panel (side faces).
	if (!top && !under) {
		vec2 tf = abs(pf - vec2(0.6, 0.45));
		col *= 1.0 - 0.3 * (1.0 - step(0.07, max(tf.x, tf.y)));
	}
	// Water streaks and grime, drawn down the face.
	float st = sd_vn(vec2(uv.x * (top ? 1.4 : 2.4), uv.y * (top ? 1.4 : 0.1)));
	float sm = smoothstep(0.58, 0.85, st);
	col *= 1.0 - streak * 1.5 * sm * (top ? 0.6 : 1.0);
	col *= 1.0 + 0.6 * streak * (1.0 - smoothstep(0.3, 0.5, st)) * (top ? 0.0 : 1.0) * 0.4;
	if (top) {
		float g = smoothstep(0.55, 0.8, sd_vn(uv / 1.8 + 21.0));
		col *= 1.0 - 0.22 * g * stain * 1.6;
	}
	if (under) {
		col *= 0.55 * (0.8 + 0.4 * sd_fbm(uv, 2.0));
	}
	// Rust bleeding down from a panel joint corner.
	if (!top && !under && sd_h(pcell + 61.0) < 0.3) {
		float cx = abs(pf.x - 0.3) ;
		float below = pf.y;
		float rust = (1.0 - step(0.1, cx)) * (1.0 - smoothstep(0.0, 0.9, below)) * step(0.3, sd_vn(vec2(uv.x * 7.0, uv.y * 1.2)));
		col = mix(col, vec3(0.2, 0.085, 0.04), rust * 0.7);
	}
	// The damp band: dark and wet at the water line, green-brown slime in its lower part, a pale dried line above.
	if (water_y > -50.0 && !top) {
		float h = wy - water_y;
		// A calm band about half a metre tall with a gently wavering top: damp dark concrete, green-brown
		// algae thickest at the water, and a pale tide stain just above it.
		float edge = band_h + 0.1 * (sd_vn(vec2(uv.x * 0.9, 4.0)) - 0.5) * 2.0;
		float wet_band = 1.0 - smoothstep(edge - 0.1, edge + 0.03, h);
		float slime = (1.0 - smoothstep(0.0, edge * 0.55, h)) * (0.7 + 0.3 * sd_vn(vec2(uv.x * 1.6, 9.0)));
		col *= 1.0 - 0.9 * damp * wet_band;
		col = mix(col, vec3(0.05, 0.09, 0.02), clamp(slime * damp * 0.9, 0.0, 0.75));
		float dried = (1.0 - smoothstep(0.0, 0.08, abs(h - edge - 0.14))) * damp;
		col *= 1.0 + 0.3 * dried;
	}
	return col;
}

// Road paint (a dash, a zebra bar, a bay line): the paint's colour with grime and tyre-dark smears; the
// caller discards a chipped block (see sd_paint_chip).
vec3 sd_paint(vec3 base, vec2 pc) {
	float k = 0.94 + 0.1 * (sd_h(floor(pc / block)) - 0.5);
	return base * k;
}

// 0..1, how likely a block of paint is worn away: edges (edge_d, m to the nearest edge) wear first, and
// whole patches where the traffic runs.
float sd_paint_chip(vec2 pc, float edge_d) {
	// Only the end blocks of a bar can wear, and never more than half of them: a dash is never knocked out.
	return (1.0 - smoothstep(0.0, 0.2, edge_d)) * 0.45;
}
