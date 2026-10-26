shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
// A rain drop landing (WeatherView, director 2026-10-25: "a lighter misting effect upon impact", no rings, no
// crowns): a soft, low puff of mist that swells a little and fades fast (each drop its own pace and size). Pale grey under the bloom threshold, never a glow cube.
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
varying float v_seed;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	v_life = INSTANCE_CUSTOM.y;
	v_plane_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	v_seed = hash(float(INSTANCE_ID) + 1.7);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float life = clamp(v_life * mix(0.8, 1.25, v_seed), 0.0, 1.0);
	// A soft lumpy puff: wisps off the middle so it reads as mist, not a disc.
	float a = atan(p.y, p.x) + v_seed * 6.2832;
	float lump = 0.92 + 0.08 * sin(a * 2.0 + v_seed * 9.0);
	float r = length(p) / mix(0.5, 1.0, sqrt(life)) / lump;
	float puff = exp(-r * r * 3.0) * smoothstep(1.0, 0.7, r);
	float fade = smoothstep(0.0, 0.08, life) * pow(1.0 - life, 1.5);
	float clear = view_clear(-VERTEX.z, SCREEN_UV, VIEWPORT_SIZE, near_clear, near_full,
		centre_keep, centre_radius, focus_clear, focus_full);
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 under = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float under_y = (INV_VIEW_MATRIX * vec4(under.xyz / under.w, 1.0)).y;
	float rests = 1.0 - smoothstep(rest_tolerance * 0.5, rest_tolerance, abs(under_y - v_plane_y));
	ALBEDO = tint.rgb;
	ALPHA = tint.a * puff * fade * clear * rests;
}
