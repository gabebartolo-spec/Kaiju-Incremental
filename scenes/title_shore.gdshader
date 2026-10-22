shader_type spatial;
// The far shore's lights mirrored in the bay for the title screen: soft vertical streaks of lit
// windows and, wider and longer, of the fires, with a gentle shimmer along their length. Each
// water point takes the streak of the shore point that shows at the same screen column, so every
// streak is vertical on screen and, at rest, smooth (streak brightness is smooth value noise
// across the picture, never on/off columns). Only a footfall (shiver > 0) shears the streaks into
// wobbling bands. Added over the water; presentation only (scenes/title_shore.gd).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

const int MAX_FIRES = 12;

uniform vec3 window_colour : source_color = vec3(1.0, 0.85, 0.55);
uniform vec3 fire_colour : source_color = vec3(1.0, 0.45, 0.12);
uniform float shore_z = -300.0;
uniform vec3 cam_pos = vec3(0.0, 10.0, -100.0);
uniform float window_length = 55.0;
uniform float fire_length = 140.0;
uniform float window_strength = 0.35;
uniform float fire_strength = 0.8;
uniform float fire_radius = 6.0;
uniform float cell = 1.7;
uniform float sheet_length = 190.0;
uniform float shiver = 0.0;
uniform float ripple_amp = 2.0;
uniform float ripple_glow = 0.06;
uniform int fire_count = 0;
uniform float fire_x[MAX_FIRES];

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

// Smooth 1D value noise: no cell edges, so a streak never has a hard side.
float n1(float p) {
	float i = floor(p);
	float f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(h11(i), h11(i + 1.0), f);
}

void fragment() {
	float dz = wpos.z - shore_z;
	// The shore point on this water point's screen column.
	float k = (cam_pos.z - shore_z) / max(cam_pos.z - wpos.z, 0.001);
	float xs = cam_pos.x + (wpos.x - cam_pos.x) * k;
	// At rest the streaks barely bend; a footstep shears them into wobbling bands.
	float sway = sin(dz * 0.3 + TIME * 0.5 + xs * 0.04) * 0.04;
	float shake = shiver * ripple_amp * sin(dz * 0.85 - TIME * 9.0 + xs * 0.07) * (0.6 + 0.4 * sin(dz * 0.23 + TIME * 3.0));
	float x = xs + sway + shake;
	float u = x / cell;
	// Streak brightness across the picture: smooth, never fully dark between streaks.
	float streak = 0.3 + 0.7 * smoothstep(0.2, 0.85, n1(u * 0.8 + 3.0) * 0.65 + n1(u * 2.3 + 11.0) * 0.35);
	float warm = 0.4 + 0.6 * n1(u * 0.5 + 40.0);
	// A gentle shimmer along each streak (stronger while the water shivers).
	float shimmer = 1.0 - (0.14 + 0.4 * shiver) * (0.5 + 0.5 * sin(dz * 0.55 + n1(u * 0.7) * 20.0 + TIME * 0.9));
	vec3 col = window_colour * streak * warm * shimmer * exp(-dz / window_length) * window_strength;
	for (int i = 0; i < MAX_FIRES; i++) {
		if (i >= fire_count) {
			break;
		}
		float dx = (x - fire_x[i]) / fire_radius;
		float flick = 0.7 + 0.3 * sin(dz * 0.5 + TIME * 1.8 + float(i) * 2.0);
		float stripe = 0.55 + 0.45 * n1(u * 0.9 + float(i) * 7.0);
		col += fire_colour * exp(-dx * dx) * stripe * flick * shimmer * exp(-dz / fire_length) * fire_strength;
	}
	col *= 1.0 - shiver * 0.6 * (0.5 + 0.5 * sin(dz * 1.1 - TIME * 11.0));
	// The streaks fade in from the shore and out toward the camera: no cut edges.
	col *= smoothstep(0.0, 6.0, dz) * (1.0 - smoothstep(sheet_length * 0.55, sheet_length * 0.97, dz));
	// ...and the bay's own surface catches the light in ripples that spread toward the camera.
	float crest = pow(0.5 + 0.5 * sin(dz * 0.55 - TIME * 7.0 + xs * 0.03), 4.0);
	col += vec3(0.5, 0.65, 1.0) * ripple_glow * shiver * crest * exp(-dz / 120.0);
	ALBEDO = col;
	ALPHA = 1.0;
}
