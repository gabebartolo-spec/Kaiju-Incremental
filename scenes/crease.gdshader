shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
// Screen-space crease pass (director, 2026-10-18): darkens where the scene folds or steps back,
// read from the depth and normal buffers in screen pixels, so it shows at any zoom: building
// corners and setbacks, the rims of bitten holes, the kaiju's silhouette against the street and
// the folds of its skin. A full-screen quad (CreasePass) drawn first among transparent things, so
// smoke, fire and effects stay on top. Forward+ only (the normal buffer). Strengths come from the
// look (data/looks.json crease_*); crease_strength 0 removes the pass.

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;
uniform float strength = 0.0;
// Sample distance in pixels at 1080 lines; scaled with the viewport so 4K matches 1080p.
uniform float radius = 1.5;
// How far (as a share of the pixel's own distance) a neighbour must stand in front to count.
uniform float depth_step = 0.02;
// How sharply the surface must turn (1 - cos of the angle) to count as a crease.
uniform float normal_step = 0.25;
// Creases fade out between these distances (world units), so the far city does not turn to grit.
uniform float fade_near = 60.0;
uniform float fade_far = 180.0;
// The kaiju's roughness (looks.json kaiju_roughness) tags its pixels in the normal buffer: inside
// its own voxel relief the creases would boil as it moves, so it keeps only the shadow its
// silhouette casts onto what lies behind it. Negative = skip nothing.
uniform float skip_roughness = -1.0;
const float SKIP_BAND = 0.02;

const float REFERENCE_LINES = 1080.0;
const vec2 OFFSETS[4] = vec2[](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_projection) {
	float d = texture(depth_tex, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -view.z / view.w;
}

// The buffer packs roughness with a sign flag above 0.5 (Godot's normal_roughness layout).
float buffer_roughness(vec2 uv) {
	float r = texture(normal_tex, uv).w;
	if (r > 0.5) {
		r = 1.0 - r;
	}
	return r / (127.0 / 255.0);
}

vec3 view_normal(vec2 uv) {
	return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (abs(buffer_roughness(uv) - skip_roughness) < SKIP_BAND) {
		discard;
	}
	vec2 texel = radius * (VIEWPORT_SIZE.y / REFERENCE_LINES) / VIEWPORT_SIZE;
	float d = view_depth(uv, INV_PROJECTION_MATRIX);
	vec3 n = view_normal(uv);
	float behind = 0.0;
	float turn = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 at = uv + OFFSETS[i] * texel;
		float dn = view_depth(at, INV_PROJECTION_MATRIX);
		// A neighbour clearly nearer: this pixel sits behind an edge (a silhouette, a hole's rim).
		behind = max(behind, smoothstep(depth_step, depth_step * 3.0, (d - dn) / d));
		// The surface turns here (a corner, a setback, a fold), on a surface of about one depth.
		float same = 1.0 - smoothstep(depth_step, depth_step * 3.0, abs(d - dn) / d);
		turn = max(turn, same * smoothstep(normal_step, normal_step * 2.0, 1.0 - dot(n, view_normal(at))));
	}
	float fade = 1.0 - smoothstep(fade_near, fade_far, d);
	ALBEDO = vec3(0.0);
	ALPHA = clamp(max(behind, turn) * strength * fade, 0.0, 1.0);
}
