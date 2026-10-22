shader_type spatial;
// The stone ledge along the bottom of the title picture (scenes/title_shore.gd): paving slabs
// with dark joints, a warm pool of lamplight under every lamp, and the orange of the fires on the
// far shore washing the lip nearest the water, so the shore is visible and its railing and kerb
// stand against a lit surface instead of a dark strip. Unlit, so the light is exactly what is
// painted here; presentation only.
render_mode unshaded, blend_mix, cull_back, fog_disabled;

uniform vec3 stone_colour : source_color = vec3(0.17, 0.18, 0.24);
uniform vec3 pool_colour : source_color = vec3(1.0, 0.68, 0.34);
uniform vec3 fire_colour : source_color = vec3(1.0, 0.36, 0.1);
uniform float lamp_gap = 24.0;
uniform float lamp_span = 450.0;
uniform float lamp_z = -100.0;
uniform vec2 pool_radius = vec2(12.0, 8.0);
uniform float pool_strength = 0.9;
uniform float lip_z = -110.0;
uniform float fire_x = 60.0;
uniform float fire_width = 260.0;
uniform float fire_strength = 0.5;
uniform vec2 slab = vec2(3.2, 2.4);

varying vec3 wpos;
varying vec3 wnormal;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float pool(float x, float z) {
	float k = round((x + lamp_span) / lamp_gap - 0.5);
	float best = 0.0;
	for (int s = -1; s <= 1; s++) {
		float lx = -lamp_span + (k + float(s) + 0.5) * lamp_gap;
		vec2 d = vec2((x - lx) / pool_radius.x, (z - lamp_z) / pool_radius.y);
		best += exp(-dot(d, d) * 1.6);
	}
	return best;
}

void fragment() {
	vec2 cell = wpos.xz / slab;
	vec2 id = floor(cell);
	vec2 f = abs(fract(cell) - 0.5) * 2.0;
	float joint = smoothstep(0.93, 0.985, max(f.x, f.y));
	float tone = 0.8 + 0.4 * hash(id);
	float up = smoothstep(0.5, 0.9, wnormal.y);
	vec3 col = stone_colour * tone * (1.0 - joint * 0.55);
	float lamp_light = pool(wpos.x, wpos.z) * pool_strength;
	col += stone_colour * 1.6 * pool_colour * lamp_light * (1.0 - joint * 0.6);
	// The fires' light on the lip toward the water, strongest under the burning district.
	float lip = exp(-max(wpos.z - lip_z, 0.0) / 3.5);
	float along = exp(-pow((wpos.x - fire_x) / fire_width, 2.0));
	col += fire_colour * 0.55 * lip * (0.35 + 0.65 * along) * fire_strength;
	// The ledge's side faces stay darker than its top.
	col *= mix(0.45, 1.0, up);
	ALBEDO = col;
}
