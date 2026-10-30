shader_type spatial;
render_mode cull_disabled;
// A building baked into one mesh (BuildingMesher): only the faces you can see, so a city at
// eight voxels per floor costs about what it did at four. Each vertex carries its structural
// chunk (UV2.x) and a per-voxel hash (UV2.y). The `alive` texture holds one texel per chunk:
// 1 standing, 0 gone (its faces collapse to nothing), in between = bitten (that share of the
// chunk's voxels gone), so breaking the building never rebuilds the mesh. Colour is sRGB; its
// alpha is the glow flag (0 = glows at `glow`; a lit window's 1/255 glows too and takes its
// colour and brightness from the window palette), as in voxel.gdshader. Only outward faces are
// baked, so through a hole you see the backs of the walls: they draw as the dark inside
// (`inside` of their colour; a landmark's cut faces draw near their own colour instead).
// Outward faces take the baked voxel AO and their material's finish (building_common).

#include "res://scenes/building_common.gdshaderinc"

#include "res://scenes/window_palette.gdshaderinc"
#include "res://scenes/dither.gdshaderinc"

uniform sampler2D alive : filter_nearest;
uniform float glow = 0.0;
uniform float roughness_value = 0.9;
uniform float inside = 0.12;
// The stream swap (StreamDissolve): the share of a standing building drawn while it crosses with
// its stand-in box, a dither. 1 (every other moment, every falling piece, D-326) draws it whole.
uniform float dissolve = 1.0;
// The camera bubble (CameraBubble, D-283): a standing building the camera runs into is cut
// away inside a sphere round the camera, bubble_cut of the global bubble_radius, with a hard
// edge on its own blocks (no dither, no fade). 0 (every other building, every falling piece,
// D-326) draws it whole. Never in a shadow pass: the cut part still casts its shadow.
global uniform float bubble_radius;
uniform float bubble_cut = 0.0;

// Half a voxel inside the face, in model space: the window's cell, the same in the baked shell,
// the cell grid and a falling piece.
varying vec3 v_window;
// The face's normal in model space, for the window's half-open shift (window_hash).
varying vec3 v_window_n;
// The chunk's alive state (the `alive` texel), for the per-voxel bite in fragment().
varying flat float v_state;

// Merged faces (BuildingMesher's greedy merge, voxel_merged): a quad spans many voxels, so the
// per-voxel colour jitter (Look.jitter) and bite hash (BuildingMesher._start_cell) are rebuilt
// here from the voxel under the fragment, with the same hashes as the meshers. Off (the cell
// grid, which bakes both per vertex as before), nothing changes.
uniform bool voxel_merged = false;
// Model-space centre of voxel (0, 0, 0) (BuildingVoxels.origin + half a voxel up), voxel size,
// the building's style salt and Look's color_noise.
uniform vec3 voxel_origin;
uniform float voxel_size = 0.125;
uniform int voxel_salt = 0;
uniform float color_noise = 0.0;

// Godot's hash_murmur3_one_32 / hash_fmix32 (core/templates/hashfuncs.h), as GDScript hash().
uint murmur_step(uint k, uint h) {
	k *= 0xcc9e2d51u;
	k = (k << 15u) | (k >> 17u);
	k *= 0x1b873593u;
	h ^= k;
	h = (h << 13u) | (h >> 19u);
	return h * 5u + 0xe6546b64u;
}

uint murmur_fmix(uint h) {
	h ^= h >> 16u;
	h *= 0x85ebca6bu;
	h ^= h >> 13u;
	h *= 0xc2b2ae35u;
	h ^= h >> 16u;
	return h;
}

const uint MURMUR_SEED = 0x7F07C65u;

ivec3 merged_cell(vec3 model, vec3 n) {
	return ivec3(round((model - n * (voxel_size * 0.5) - voxel_origin) / voxel_size));
}

// Look.jitter's brightness factor: hash(Vector4i(cell, salt)) % 1000 -> t in [-1, 1).
float jitter_factor(ivec3 c) {
	uint h = murmur_step(uint(c.x), MURMUR_SEED);
	h = murmur_step(uint(c.y), h);
	h = murmur_step(uint(c.z), h);
	h = murmur_step(uint(voxel_salt), h);
	float t = float(murmur_fmix(h) % 1000u) / 1000.0 * 2.0 - 1.0;
	return 1.0 + t * color_noise;
}

// BuildingMesher._start_cell's bite hash: 2x2x2 clumps, hash(clump * 7 + (salt, 3, 11)) % 997.
float bite_hash(ivec3 c) {
	ivec3 k = (c >> 1) * 7 + ivec3(voxel_salt, 3, 11);
	uint h = murmur_step(uint(k.x), MURMUR_SEED);
	h = murmur_step(uint(k.y), h);
	h = murmur_step(uint(k.z), h);
	return float(murmur_fmix(h) % 997u) / 997.0;
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	v_window = VERTEX - NORMAL * (window_voxel * 0.5);
	v_window_n = NORMAL;
	float state = texelFetch(alive, ivec2(int(UV2.x + 0.5), 0), 0).r;
	v_state = state;
	if (state < 0.02 || (!voxel_merged && UV2.y < 1.0 - state)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec3 color = COLOR.rgb;
	if (voxel_merged) {
		ivec3 cell = merged_cell(v_window + v_window_n * (window_voxel * 0.5), v_window_n);
		if (bite_hash(cell) < 1.0 - v_state) {
			discard;
		}
		// The meshers stored the jittered colour as 8-bit vertex colour: round it the same way.
		color = round(clamp(color * jitter_factor(cell), 0.0, 1.0) * 255.0) / 255.0;
	}
	if (dissolve < 0.999 && !IN_SHADOW_PASS && dither(FRAGCOORD.xy) >= dissolve) {
		discard;
	}
	if (bubble_cut > 0.0 && !IN_SHADOW_PASS && length(VERTEX) < bubble_radius * bubble_cut) {
		discard;
	}
	vec3 albedo = srgb_to_linear(color);
	ROUGHNESS = roughness_value;
	if (FRONT_FACING) {
		float lit = 1.0 - COLOR.a;
		if (window_tagged(COLOR.a)) {
			lit = 1.0;
			if (window_palette_on) {
				vec4 w = window_pick(window_hash(v_window, v_window_n));
				albedo = w.rgb;
				lit = w.a;
			}
		}
		ALBEDO = albedo;
		EMISSION = albedo * glow * lit;
		AO = voxel_ao(UV);
		AO_LIGHT_AFFECT = ao_light_affect;
		if (finish_on) {
			int f = voxel_finish(UV);
			ROUGHNESS = finish_roughness[f];
			SPECULAR = finish_specular[f];
		}
	} else {
		ALBEDO = albedo * inside;
		NORMAL = -NORMAL;
	}
}
