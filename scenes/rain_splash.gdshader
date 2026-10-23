shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
// A rain drop landing (WeatherView): a tiny flat ring on the street that spreads and fades in
// about a third of a second. Pale grey under the bloom threshold, never a glow cube.

uniform vec4 tint : source_color = vec4(0.8, 0.82, 0.85, 0.5);
uniform float near_clear = 9.0;
uniform float near_full = 24.0;
uniform float centre_keep = 0.6;
uniform float centre_radius = 0.32;
uniform float focus_clear = 0.3;
uniform float focus_full = 0.7;
#include "res://scenes/view_clear.gdshaderinc"

varying float v_life;

void vertex() {
	v_life = INSTANCE_CUSTOM.y;
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float ring_at = mix(0.25, 0.9, v_life);
	float ring = smoothstep(0.16, 0.0, abs(r - ring_at));
	float fade = (1.0 - v_life) * smoothstep(0.0, 0.06, v_life);
	float clear = view_clear(-VERTEX.z, SCREEN_UV, VIEWPORT_SIZE, near_clear, near_full,
		centre_keep, centre_radius, focus_clear, focus_full);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * ring * fade * clear;
}
