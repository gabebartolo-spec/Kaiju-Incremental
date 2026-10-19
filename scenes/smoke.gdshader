shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Soft billboard smoke puff: a round, noisy, dark mass that is lit dimly by the scene and
// thins out at its edges. Colour and alpha come from the particle (COLOR).
// Camera rule (director, 2026-10-16): a little smog in view is immersive, a wall of it ruins the
// view. Smoke thins as it nears the camera and over the screen centre, where the kaiju stands.
// Playtest (director, 2026-10-19: "probably still too much smoke on camera"): smoke in front of
// the kaiju (view depth under focus_clear of the camera-to-kaiju depth, smoke_focus, set by
// CityView) is cleared too, so the kaiju and the city read through it; smoke behind it stays.

uniform float softness = 0.2;
// Fully clear this close to the camera, full strength from near_full on (world units).
uniform float near_clear = 8.0;
uniform float near_full = 22.0;
// Opacity kept over the screen centre, and the screen radius that clearing reaches.
uniform float centre_keep = 0.3;
uniform float centre_radius = 0.32;
// Share of the camera-to-kaiju depth that is clear, and where smoke is back at full strength.
uniform float focus_clear = 0.55;
uniform float focus_full = 1.0;
global uniform float smoke_focus;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	// Face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float n = noise(UV * 5.0 + COLOR.rg * 13.0) * 0.6 + noise(UV * 11.0) * 0.4;
	float round_mask = 1.0 - smoothstep(softness, 1.0, length(p) + (n - 0.5) * 0.5);
	ALBEDO = COLOR.rgb * (0.75 + 0.35 * n);
	ROUGHNESS = 1.0;
	float near = smoothstep(near_clear, near_full, -VERTEX.z);
	vec2 off = (SCREEN_UV - 0.5) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float centre = mix(centre_keep, 1.0, smoothstep(centre_radius * 0.4, centre_radius, length(off)));
	float front = smoke_focus > 0.0
		? smoothstep(smoke_focus * focus_clear, smoke_focus * focus_full, -VERTEX.z) : 1.0;
	ALPHA = COLOR.a * round_mask * near * centre * front;
}
