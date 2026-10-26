shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, skip_vertex_transform;
// Rain streaks (VFX family 11, WeatherView): a thin quad as long and thick on screen as its share of
// the viewport height says, at the one screen angle the fall direction has, drawn in a pale grey that
// stays under the 0.9 bloom threshold. WeatherView runs three of these (near, mid, far), each seen only
// in its own band of depth (near_clear..near_full in, far_begin..far_end out). Thinned like smoke (view_clear: D-018), softly in at birth and out at the end of its
// fall so nothing spawns visibly in mid-air.

uniform vec3 fall_dir = vec3(0.0, -1.0, 0.0);  // world, unit
uniform vec4 tint : source_color = vec4(0.8, 0.82, 0.85, 0.4);
uniform float streak_len = 0.03;  // share of the viewport height, along the fall
uniform float streak_width = 0.0012;  // share of the viewport height; never under 1 px
uniform float fade_in = 0.07;  // share of life
uniform float fade_out = 0.1;
uniform float far_begin = 60.0;
uniform float far_end = 110.0;
uniform float near_clear = 9.0;
uniform float near_full = 24.0;
uniform float centre_keep = 0.25;
uniform float centre_radius = 0.32;
uniform float focus_clear = 0.6;
uniform float focus_full = 1.0;
#include "res://scenes/view_clear.gdshaderinc"

varying float v_life;
varying float v_depth;

void vertex() {
	vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// One screen angle everywhere: the fall direction as the camera sees it, flattened into the
	// screen plane, so a streak leans the same over the street, a facade and the sky.
	vec2 lean = (VIEW_MATRIX * vec4(fall_dir, 0.0)).xy;
	lean = length(lean) > 0.01 ? normalize(lean) : vec2(0.0, -1.0);
	vec3 axis = vec3(lean, 0.0);
	vec3 side = vec3(-lean.y, lean.x, 0.0);
	float dist = max(-centre.z, 0.001);
	// px per metre at this depth: viewport height / (2 d tan(fov/2)); PROJECTION_MATRIX[1][1] = 1/tan.
	float px_per_m = VIEWPORT_SIZE.y * 0.5 * PROJECTION_MATRIX[1][1] / dist;
	float w = max(streak_width * VIEWPORT_SIZE.y, 1.0) / px_per_m;
	float l = streak_len * VIEWPORT_SIZE.y / px_per_m;
	VERTEX = centre + side * VERTEX.x * w + axis * VERTEX.y * l;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_life = INSTANCE_CUSTOM.y;
	v_depth = dist;
}

void fragment() {
	// Soft across the width, brightest along the middle, tapering at both ends.
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.65, UV.y);
	float life = smoothstep(0.0, fade_in, v_life) * (1.0 - smoothstep(1.0 - fade_out, 1.0, v_life));
	float far = 1.0 - smoothstep(far_begin, far_end, v_depth);
	float clear = view_clear(v_depth, SCREEN_UV, VIEWPORT_SIZE, near_clear, near_full,
		centre_keep, centre_radius, focus_clear, focus_full);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * across * along * life * far * clear;
}
