shader_type spatial;
// The far shore's lights mirrored in the bay for the title screen: broken vertical streaks of lit
// windows and, wider and longer, of the fires, shimmering on a slow swell. Each water point takes
// the streak of the shore point that shows at the same screen column, so every streak is
// vertical on screen. Added over the water; presentation only (scenes/title_shore.gd).
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

void fragment() {
	float dz = wpos.z - shore_z;
	// The shore point on this water point's screen column.
	float k = (cam_pos.z - shore_z) / max(cam_pos.z - wpos.z, 0.001);
	float xs = cam_pos.x + (wpos.x - cam_pos.x) * k;
	// A slow swell bends the streaks a little and breaks them into dashes.
	float sway = sin(dz * 0.3 + TIME * 0.7 + xs * 0.04) * 0.45 + sin(dz * 0.8 - TIME * 1.1) * 0.2;
	// A footstep: the whole surface shivers, shearing the streaks into wobbling bands.
	float shake = shiver * ripple_amp * sin(dz * 0.85 - TIME * 9.0 + xs * 0.07) * (0.6 + 0.4 * sin(dz * 0.23 + TIME * 3.0));
	float x = xs + sway + shake;
	float c = floor(x / cell);
	float f = fract(x / cell);
	float shape = smoothstep(0.0, 0.3, f) * smoothstep(1.0, 0.7, f);
	float dash = 0.55 + 0.45 * sin(dz * 1.4 + h11(c) * 30.0 + TIME * 1.2);
	float lit = step(0.5, h11(c));
	float warm = 0.35 + 0.65 * h11(c + 17.0);
	vec3 col = window_colour * lit * shape * warm * dash * exp(-dz / window_length) * window_strength;
	for (int i = 0; i < MAX_FIRES; i++) {
		if (i >= fire_count) {
			break;
		}
		float dx = (x - fire_x[i]) / fire_radius;
		float flick = 0.6 + 0.4 * sin(dz * 0.9 + TIME * 2.6 + float(i) * 2.0);
		float stripe = 0.45 + 0.55 * h11(c + float(i) * 3.0);
		col += fire_colour * exp(-dx * dx) * stripe * flick * exp(-dz / fire_length) * fire_strength;
	}
	col *= 1.0 - shiver * 0.5 * (0.5 + 0.5 * sin(dz * 1.1 - TIME * 11.0));
	// ...and the bay's own surface catches the light in ripples that spread toward the camera.
	float crest = pow(0.5 + 0.5 * sin(dz * 0.55 - TIME * 7.0 + xs * 0.03), 4.0);
	col += vec3(0.5, 0.65, 1.0) * ripple_glow * shiver * crest * exp(-dz / 120.0);
	ALBEDO = col;
	ALPHA = 1.0;
}
