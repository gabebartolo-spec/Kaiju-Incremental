shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
// Toon look candidate (director 2026-10-20, shader comparison): a full-screen quad that bands the
// lit scene into a few flat tones and inks its silhouettes and folds from the depth and normal
// buffers. Forward+ only. Drawn over the opaque scene; smoke, fire and effects stay on top.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;
uniform float bands = 4.0;
uniform float ink = 0.85;
uniform float radius = 1.2;
uniform float depth_step = 0.03;
uniform float normal_step = 1.5;  // > 1: folds never ink, only silhouettes (voxel steps read as noise)
uniform float band_mix = 0.7;

const float REFERENCE_LINES = 1080.0;
const vec2 OFFSETS[4] = vec2[](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));


void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


float view_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}


void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float lum = max(dot(col, vec3(0.299, 0.587, 0.114)), 1e-4);
	float banded = round(lum * bands) / bands;  // never lifts the darks
	col = mix(col, col * banded / lum, band_mix);
	vec2 px = radius * VIEWPORT_SIZE.y / REFERENCE_LINES / VIEWPORT_SIZE;
	float here = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 n = texture(normal_tex, SCREEN_UV).xyz * 2.0 - 1.0;
	float edge = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + OFFSETS[i] * px;
		float there = view_depth(uv, INV_PROJECTION_MATRIX);
		vec3 m = texture(normal_tex, uv).xyz * 2.0 - 1.0;
		if (here - there > here * depth_step || 1.0 - dot(n, m) > normal_step) {
			edge = 1.0;
		}
	}
	ALBEDO = mix(col, vec3(0.04, 0.04, 0.06), edge * ink);
}
