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

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	v_window = VERTEX - NORMAL * (window_voxel * 0.5);
	float state = texelFetch(alive, ivec2(int(UV2.x + 0.5), 0), 0).r;
	if (state < 0.02 || UV2.y < 1.0 - state) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	if (dissolve < 0.999 && !IN_SHADOW_PASS && dither(FRAGCOORD.xy) >= dissolve) {
		discard;
	}
	if (bubble_cut > 0.0 && !IN_SHADOW_PASS && length(VERTEX) < bubble_radius * bubble_cut) {
		discard;
	}
	vec3 albedo = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = roughness_value;
	if (FRONT_FACING) {
		float lit = 1.0 - COLOR.a;
		if (window_tagged(COLOR.a)) {
			lit = 1.0;
			if (window_palette_on) {
				vec4 w = window_pick(window_hash(v_window));
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
