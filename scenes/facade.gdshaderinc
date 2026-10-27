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

// Interleaved gradient noise: a cheap screen-space dither in [0, 1).
float dither(vec2 at) {
	return fract(52.9829189 * fract(dot(at, vec2(0.06711056, 0.00583715))));
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
	float seed = v_custom.w;
	if (plain) {
		albedo = wall * (v_normal.y > 0.5 ? 1.08 : 1.0);
	} else if (v_normal.y > 0.5) {
		albedo = roof_color * (0.85 + 0.3 * hash3(floor(v_world * 4.0)));
		// A red beacon on the roof of the tallest towers, blinking.
		if (v_custom.z > 0.5) {
			vec2 c = abs(v_world.xz - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz);
			if (max(c.x, c.y) < 0.6) {
				float blink = step(0.5, fract(TIME * 0.6 + seed * 7.0));
				emit = vec3(1.0, 0.12, 0.08) * 6.0 * blink;
				albedo = vec3(0.4, 0.05, 0.03);
			}
		}
	} else if (v_normal.y > -0.5) {
		float along = abs(v_normal.x) > 0.5 ? v_world.z : v_world.x;
		float cell = floor(along * grain);
		float y4 = floor(v_world.y * grain);
		float row = mod(y4, 4.0);
		float p = mod(cell + floor(seed * 13.0), 64.0);
		int style = int(v_custom.x + 0.5);
		bool window = false;
		bool trim = false;
		if (v_world.y * grain < 4.0) {
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
		if ((v_top - v_world.y) * grain < 2.0) {
			trim = true;
			window = false;
		}
		float jitter = 0.92 + 0.16 * hash3(vec3(cell, y4, seed));
		if (trim) {
			albedo = wall * 1.25 * jitter;
		} else if (window) {
			vec3 pane = window_color;
			if (style == 2) {
				pane = mix(pane, wall, 0.3) * 1.1;
			}
			albedo = pane * jitter;
			float lit = hash3(vec3(floor(cell / 2.0), floor(y4 / 4.0), seed * 31.0));
			bool dark = hash3(vec3(floor(cell / 14.0), floor(y4 / 12.0), seed * 17.0 + 5.0)) < blackout;
			if (lit < v_custom.y && !dark) {
				vec3 l = lit_color;
				float gain = 1.0;
				if (window_palette_on) {
					uint h = window_mix(uint(int(seed * 65536.0)) ^ 40503u);
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
		// The thin dark seam between voxels, so the stand-ins share the voxel grain.
		vec2 seam = fract(vec2(along, v_world.y) * grain);
		if (min(min(seam.x, seam.y), min(1.0 - seam.x, 1.0 - seam.y)) < 0.04) {
			albedo *= 0.8;
		}
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
