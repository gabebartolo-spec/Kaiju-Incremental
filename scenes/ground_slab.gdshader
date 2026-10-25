shader_type spatial;
render_mode diffuse_burley;  // StandardMaterial3D's default diffuse (the shader default is lambert)
// The street plan's slabs and road paint (CityGround): the one ground shader. The instance colour (sRGB)
// is the surface's base colour; the instance custom data says what it is (kind) and where it runs:
//   custom.x = kind + axis / 8   kind: 0 asphalt, 1 road (lanes), 2 pavement, 3 lawn, 4 concrete,
//                                5 bridge deck (road on top, concrete round it), 6 road paint
//                                axis: 0 the street runs along x, 1 along z, 2 turned (the diagonal)
//   road / deck: custom.y + custom.z = the street's centre line (world x or z) as a big part and a small
//                part, so a half-float instance buffer keeps it exact; custom.w = half the street's width
//   concrete:    custom.y = the water line's height (below -50: none)
// The look itself is surface_detail.gdshaderinc, shared by every surface shader (seeded, block-quantised,
// world-space). `wet` (0..1, set only by WeatherView, D-155) is the one weather switch, applied LAST so
// whatever the surface is, the rain darkens it and makes it glossy, so lamps, fires and the sun lay soft
// sheen on it (no screen-space reflections; those are post-demo).
// WET_DARKEN and WET_ROUGHNESS are this material's identity; how wet each weather is, is data.

#include "res://scenes/surface_detail.gdshaderinc"

uniform float wet : hint_range(0.0, 1.0) = 0.0;
// The road paint's material sets these: a colour, and the kind for every instance (-1: read the instance).
uniform vec4 tint : source_color = vec4(1.0);
uniform float force_kind = -1.0;

const float WET_DARKEN = 0.5;
const float WET_ROUGHNESS = 0.18;
const float WET_SPECULAR = 0.9;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 local_pos;
varying flat vec4 data;
varying flat vec4 axes;  // the slab's own x axis (xz) and its centre (xz), for the turned diagonal

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_pos = VERTEX * size;
	data = INSTANCE_CUSTOM;
	axes = vec4(normalize(MODEL_MATRIX[0].xz), MODEL_MATRIX[3].xz);
}

void fragment() {
	// Nudge the sample inside the face, so a block edge never flips with float error.
	vec3 q = world_pos - world_normal * 0.001;
	vec2 pc = sd_cell(sd_plane(q, world_normal));
	float code = force_kind >= 0.0 ? force_kind : data.x;
	float kind = floor(code + 0.001);
	float axis = floor(fract(code + 0.001) * 8.0 + 0.5);
	vec3 base = sd_srgb(COLOR.rgb) * tint.rgb;
	bool up = world_normal.y > 0.5;
	// Where the pixel is along the street and across it (roads and decks).
	vec2 wc = sd_cell(q.xz);
	float centre_line = data.y + data.z;
	float along = axis < 0.5 ? wc.x : wc.y;
	float lat = (axis < 0.5 ? wc.y : wc.x) - centre_line;
	if (axis > 1.5) {
		vec2 d = wc - axes.zw;
		along = dot(d, axes.xy) + axes.z * 0.37;
		lat = dot(d, vec2(-axes.y, axes.x));
	}
	vec3 col;
	float polish = 0.0;
	if (kind < 0.5) {
		col = sd_asphalt(base, pc, 0.0, 0.0, 1.0, 0.0, polish);
	} else if (kind < 1.5) {
		col = sd_asphalt(base, pc, along, lat, data.w, 1.0, polish);
	} else if (kind < 2.5) {
		if (up) {
			float kd = min(0.5 * length(MODEL_MATRIX[0].xyz) - abs(local_pos.x), 0.5 * length(MODEL_MATRIX[2].xyz) - abs(local_pos.z));
			col = sd_pavement(base, pc, kd);
		} else {
			col = sd_concrete(base, pc, world_pos.y, world_normal, -100.0);
		}
	} else if (kind < 3.5) {
		col = up ? sd_lawn(base, pc) : base;
	} else if (kind < 4.5) {
		col = sd_concrete(base, pc, world_pos.y, world_normal, data.y);
	} else if (kind < 5.5) {
		if (up) {
			col = sd_asphalt(base, pc, along, lat, data.w, 1.0, polish);
		} else {
			// The deck's fascia reaches down to the river, so it carries the same damp band as the walls.
			col = sd_concrete(base, pc, world_pos.y, world_normal, river_y);
		}
	} else {
		// A bar wears from its ends (the long axis), not its sides.
		float lx = 0.5 * length(MODEL_MATRIX[0].xyz) - abs(local_pos.x);
		float lz = 0.5 * length(MODEL_MATRIX[2].xyz) - abs(local_pos.z);
		float edge_d = length(MODEL_MATRIX[0].xyz) > length(MODEL_MATRIX[2].xyz) ? lx : lz;
		if (sd_h(pc * 7.0 + 2.0) < sd_paint_chip(pc, edge_d)) {
			discard;
		}
		col = sd_paint(base, pc);
	}
	float grain = sd_grain(q, -VERTEX.z);
	col *= grain;
	// Wet goes last: the same darkening and gloss whatever the surface.
	ALBEDO = col * (1.0 - wet * WET_DARKEN);
	// Worn tracks, patches and oil are polished: the sky, the moon and the lamps show on them.
	ROUGHNESS = mix(mix(1.0, 0.45, polish), WET_ROUGHNESS, wet);
	// Night: a faint glow that follows the surface's own variation (the ratio of its look to its base,
	// sharpened), so the road reads by its grain, not as a flat black block. Zero by day.
	float ratio = dot(col, vec3(0.3, 0.55, 0.15)) / max(dot(base, vec3(0.3, 0.55, 0.15)), 0.0001);
	EMISSION = base * night_floor * pow(ratio, 2.5) * (kind < 2.5 || (kind > 4.5 && (up || kind > 5.5)) ? 1.0 : 0.0) * (1.0 - wet * 0.5);
	SPECULAR = mix(0.5, WET_SPECULAR, wet);
}
