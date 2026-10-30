// Cheap stand-in buildings for the city past the playable edge and the skyline across the bay:
// one box per building, its facade painted in world space at the playable buildings' voxel
// grid (4 cells per floor: slab line, two window rows, lintel), so from the street they read
// as the same voxel city. Lit windows glow. Instance colour = wall colour (sRGB); custom data
// x = archetype (0..3), y = share of windows lit, z = beacon on the roof (1), w = seed.
// facade.gdshader takes the engine's fog; facade_far.gdshader fades by its own gentler haze and
// height fog (far_haze.gdshaderinc) and no engine fog; facade_far_fogged.gdshader takes both, the
// far city in the same air as the bay (FarHaze, on by default). Lit windows take the playable
// buildings' window palette (WindowPalette): the same colours and shares, picked per lit facade
// window here (an exact per-window match across the stream swap is impossible).

#include "res://scenes/window_palette.gdshaderinc"
#include "res://scenes/dither.gdshaderinc"
// The city's surface family (flat surfaces P2): walls and roofs take its block grain and its cast-concrete
// tone drift, so a stand-in reads as the same surface as the voxel buildings, never a flat block.
#include "res://scenes/surface_detail.gdshaderinc"
// How far the 4 m tone drift moves walls and roofs (voxel_detail.gdshader's tone_drift).
uniform float tone_drift = 0.3;

uniform vec3 roof_color : source_color = vec3(0.43, 0.42, 0.40);
uniform vec3 window_color : source_color = vec3(0.17, 0.23, 0.27);
uniform vec3 lit_color : source_color = vec3(0.91, 0.85, 0.69);
uniform float glow = 1.3;
uniform vec3 haze_color : source_color = vec3(0.30, 0.45, 0.50);
uniform float haze = 0.0;
uniform float haze_start = 120.0;
#ifdef FAR_HAZE
#include "res://scenes/far_haze.gdshaderinc"
#endif
uniform float blackout = 0.0;  // share of window blocks dark (a power cut: whole floors at a time)
uniform float grain = 4.0;  // facade cells per world unit (4 = the playable voxels)
uniform bool plain = false;  // just the instance colour (concrete, hills)
// Window filtering (tuning render_opt.facade_aa, director 10-27 "flashing/stuttering lit windows"):
// once a pixel spans more than filter_start facade cells, a window is thinner than the pixel and
// one point sample per pixel makes it pop as the camera moves. There the pixel takes every cell
// under its footprint, each weighted by the share of the pixel it covers (an exact box filter: a
// window keeps its brightness however it lands on the pixels), and the seam is box-filtered too;
// nearer walls keep the one exact sample. The footprint is held to filter_cells cells each way.
uniform bool filter_windows = false;
uniform float filter_start = 0.25;
uniform float filter_cells = 6.0;

varying vec3 v_world;
varying vec3 v_normal;
varying vec4 v_custom;
varying float v_top;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

// The wall at one point (`at` = along the wall, height; world units): albedo and the lit
// window's emission. `top` is the box's roof height.
void facade_wall(vec2 at, float top, vec3 wall, float bseed, float share, int style, out vec3 albedo, out vec3 emit) {
	albedo = wall;
	emit = vec3(0.0);
	float cell = floor(at.x * grain);
	float y4 = floor(at.y * grain);
	float row = mod(y4, 4.0);
	float p = mod(cell + floor(bseed * 13.0), 64.0);
	bool window = false;
	bool trim = false;
	if (at.y * grain < 4.0) {
		window = mod(p, 5.0) > 0.5 && row < 2.5;
		trim = row > 2.5;
	} else if (style == 0) {
		trim = row < 0.5;
		window = (row > 0.5 && row < 2.5) && mod(p, 4.0) > 0.5;
	} else if (style == 1) {
		window = (row > 0.5 && row < 2.5) && mod(p, 3.0) > 0.5;
	} else if (style == 2) {
		window = !(mod(p, 4.0) < 0.5 || row < 0.5);
	} else {
		trim = mod(y4, 20.0) < 0.5;
		window = (row > 0.5 && row < 2.5) && (mod(p, 4.0) > 0.5 && mod(p, 4.0) < 2.5);
	}
	if ((top - at.y) * grain < 2.0) {
		trim = true;
		window = false;
	}
	float jitter = 0.92 + 0.16 * hash3(vec3(cell, y4, bseed));
	if (trim) {
		albedo = wall * 1.25 * jitter;
	} else if (window) {
		vec3 pane = window_color;
		if (style == 2) {
			pane = mix(pane, wall, 0.3) * 1.1;
		}
		albedo = pane * jitter;
		float lit = hash3(vec3(floor(cell / 2.0), floor(y4 / 4.0), bseed * 31.0));
		bool dark = hash3(vec3(floor(cell / 14.0), floor(y4 / 12.0), bseed * 17.0 + 5.0)) < blackout;
		if (lit < share && !dark) {
			vec3 l = lit_color;
			float gain = 1.0;
			if (window_palette_on) {
				uint h = window_mix(uint(int(bseed * 65536.0)) ^ 40503u);
				h = window_mix(h ^ uint(int(floor(cell / 2.0))));
				vec4 w = window_pick(window_mix(h ^ uint(int(floor(y4 / 4.0)))));
				l = w.rgb;
				gain = w.a;
			}
			albedo = l;
			emit = l * glow * gain;
		}
	} else {
		albedo = wall * jitter;
	}
}

// Share of a pixel `w` cells wide, centred at `x` cells, that lies on a seam line (the band
// within 0.04 of a cell edge): the box-filtered seam.
float seam_cover(float x, float w) {
	float a = x - 0.5 * w;
	float b = x + 0.5 * w;
	float ia = floor(a) * 0.08 + min(fract(a), 0.04) + max(fract(a) - 0.96, 0.0);
	float ib = floor(b) * 0.08 + min(fract(b), 0.04) + max(fract(b) - 0.96, 0.0);
	return clamp((ib - ia) / w, 0.0, 1.0);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_custom = INSTANCE_CUSTOM;
	v_top = (MODEL_MATRIX * vec4(0.0, 0.5, 0.0, 1.0)).y;
}

void fragment() {
	// A box dissolving out as its mesh arrives (StreamDissolve): instance alpha is its opacity.
	if (COLOR.a < 0.999 && dither(FRAGCOORD.xy) > COLOR.a) {
		discard;
	}
	vec3 wall = srgb_to_linear(COLOR.rgb);
	vec3 albedo = wall;
	vec3 emit = vec3(0.0);
	float bseed = v_custom.w;
	// The wall point (along the wall, height) and its change across the pixel, taken here in
	// uniform control flow; foot = the pixel's footprint in facade cells (along, up).
	vec2 at = vec2(abs(v_normal.x) > 0.5 ? v_world.z : v_world.x, v_world.y);
	vec2 foot = max(fwidth(at) * grain, vec2(1e-5));
	if (plain) {
		albedo = wall * (v_normal.y > 0.5 ? 1.08 : 1.0);
	} else if (v_normal.y > 0.5) {
		albedo = roof_color * (0.85 + 0.3 * hash3(floor(v_world * 4.0)));
		// A red beacon on the roof of the tallest towers, blinking.
		if (v_custom.z > 0.5) {
			vec2 c = abs(v_world.xz - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz);
			if (max(c.x, c.y) < 0.6) {
				float blink = step(0.5, fract(TIME * 0.6 + bseed * 7.0));
				emit = vec3(1.0, 0.12, 0.08) * 6.0 * blink;
				albedo = vec3(0.4, 0.05, 0.03);
			}
		}
	} else if (v_normal.y > -0.5) {
		int style = int(v_custom.x + 0.5);
		if (filter_windows && max(foot.x, foot.y) > filter_start) {
			vec2 w = min(foot, vec2(filter_cells));
			vec2 lo = at * grain - 0.5 * w;
			vec2 hi = lo + w;
			int nx = int(floor(hi.x) - floor(lo.x)) + 1;
			int ny = int(floor(hi.y) - floor(lo.y)) + 1;
			vec3 albedo_sum = vec3(0.0);
			vec3 emit_sum = vec3(0.0);
			for (int i = 0; i < nx; i++) {
				float cx = floor(lo.x) + float(i);
				float x0 = max(lo.x, cx);
				float x1 = min(hi.x, cx + 1.0);
				for (int j = 0; j < ny; j++) {
					float cy = floor(lo.y) + float(j);
					float y0 = max(lo.y, cy);
					float y1 = min(hi.y, cy + 1.0);
					// The cell, read at the middle of the part the pixel covers.
					vec3 a;
					vec3 e;
					facade_wall(vec2(x0 + x1, y0 + y1) * (0.5 / grain), v_top, wall, bseed, v_custom.y, style, a, e);
					float k = max(x1 - x0, 0.0) * max(y1 - y0, 0.0);
					albedo_sum += a * k;
					emit_sum += e * k;
				}
			}
			albedo = albedo_sum / (w.x * w.y);
			emit = emit_sum / (w.x * w.y);
			vec2 c = vec2(seam_cover(lo.x + 0.5 * w.x, w.x), seam_cover(lo.y + 0.5 * w.y, w.y));
			albedo *= 1.0 - 0.2 * (c.x + c.y - c.x * c.y);
		} else {
			facade_wall(at, v_top, wall, bseed, v_custom.y, style, albedo, emit);
			// The thin dark seam between voxels, so the stand-ins share the voxel grain.
			vec2 vseam = fract(at * grain);
			if (min(min(vseam.x, vseam.y), min(1.0 - vseam.x, 1.0 - vseam.y)) < 0.04) {
				albedo *= 0.8;
			}
		}
	}
	// The surface family on wall and roof (a lit window keeps its own glow): the 4 m tone drift and the
	// block grain, in world space; the grain fades with distance as on the ground.
	if (dot(emit, emit) < 1e-6) {
		vec3 q = v_world - v_normal * 0.001;
		vec2 pc = sd_cell(sd_plane(q, v_normal));
		albedo *= (1.0 + (sd_fbm(pc, 4.0) - 0.5) * tone_drift) * sd_grain(q, -VERTEX.z);
	}
	ROUGHNESS = 0.9;
#ifdef FAR_HAZE
	// The far skyline fades by its own curve; lights burn through it more than walls do.
	float f = far_haze(length(v_world - CAMERA_POSITION_WORLD), v_world.y);
	ALBEDO = albedo * (1.0 - f);
	EMISSION = emit * (1.0 - f * 0.6) + haze_color * f;
#else
	ALBEDO = albedo;
	EMISSION = emit;
#endif
}
