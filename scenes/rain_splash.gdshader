shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
// A rain drop landing (WeatherView): a tiny flat ring on the street that spreads and fades in
// about a third of a second. Pale grey under the bloom threshold, never a glow cube.
// Splashes rest only on upward-facing ground (director 2026-10-25: rings on walls look silly): the
// scene depth under each pixel is read back to a world height, and a ring is kept only where the
// surface it is drawn over lies in the ring's own horizontal plane (a street, a roof). A wall face,
// or the drop beyond a quay where the ground is not at ring height, is discarded.

uniform vec4 tint : source_color = vec4(0.8, 0.82, 0.85, 0.5);
uniform float near_clear = 9.0;
uniform float near_full = 24.0;
uniform float centre_keep = 0.6;
uniform float centre_radius = 0.32;
uniform float focus_clear = 0.3;
uniform float focus_full = 0.7;
uniform float rest_tolerance = 0.3;  // metres a surface may sit off the ring's plane
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
#include "res://scenes/view_clear.gdshaderinc"

varying float v_life;
varying float v_plane_y;

void vertex() {
	v_life = INSTANCE_CUSTOM.y;
	v_plane_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float ring_at = mix(0.25, 0.9, v_life);
	float ring = smoothstep(0.16, 0.0, abs(r - ring_at));
	float fade = (1.0 - v_life) * smoothstep(0.0, 0.06, v_life);
	float clear = view_clear(-VERTEX.z, SCREEN_UV, VIEWPORT_SIZE, near_clear, near_full,
		centre_keep, centre_radius, focus_clear, focus_full);
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 under = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float under_y = (INV_VIEW_MATRIX * vec4(under.xyz / under.w, 1.0)).y;
	float rests = 1.0 - smoothstep(rest_tolerance * 0.5, rest_tolerance, abs(under_y - v_plane_y));
	ALBEDO = tint.rgb;
	ALPHA = tint.a * ring * fade * clear * rests;
}
