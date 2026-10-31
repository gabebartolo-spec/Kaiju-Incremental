// The overworld globe's continents (plan row G2): the second sphere, just outside the hologram shell, reads the
// Tellus Nova mask (assets/overworld, 0 sea, 1..7 the continents in D-420 order). Sea draws nothing; land adds a
// flat fill, a bright coastline where a neighbouring texel differs, and more light on the hovered continent.
// Additive like the shell, so it only ever brightens. Each continent wears its campaign state (plan row G3, D-430,
// Campaign.State): locked draws its coastline only, in locked_tint; available fills in tint and pulses slowly;
// conquered fills steady in conquered_tint.
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;

uniform sampler2D mask : filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.0, 1.0);  // available
uniform vec4 locked_tint : source_color = vec4(0.49, 0.49, 0.52, 1.0);
uniform vec4 conquered_tint : source_color = vec4(0.49, 1.0, 0.42, 1.0);
uniform int states[8];  // per mask value, Campaign.State: 0 locked, 1 available, 2 conquered
uniform float pulse_hz = 0.5;  // an available continent's fill breathes this many times a second
uniform float pulse_depth = 0.3;  // the share of its fill the pulse takes away at its lowest
uniform int hover_id = 0;  // the continent under the pointer, 0 = none
uniform float fill = 0.22;  // conquered
uniform float available_fill = 0.45;  // brighter: it has to stand off the yellow shell, even at the pulse low
uniform float hover_fill = 0.6;
uniform float coast = 1.0;
uniform float coast_texels = 2.0;  // coastline width, mask texels
uniform float scan_count = 90.0;
uniform float scan_speed = 0.12;
uniform float scan_strength = 0.25;

varying vec3 model_pos;

int id_at(vec2 uv) {
	return int(round(texture(mask, uv).r * 255.0));
}

void vertex() {
	model_pos = VERTEX;
}

void fragment() {
	int id = id_at(UV);
	if (id == 0) {
		discard;
	}
	vec2 t = coast_texels / vec2(textureSize(mask, 0));
	bool edge = id_at(UV + vec2(t.x, 0.0)) != id || id_at(UV - vec2(t.x, 0.0)) != id
			|| id_at(UV + vec2(0.0, t.y)) != id || id_at(UV - vec2(0.0, t.y)) != id;
	int state = states[id];
	if (state == 0 && !edge) {
		discard;
	}
	vec3 col = state == 0 ? locked_tint.rgb : (state == 2 ? conquered_tint.rgb : tint.rgb);
	float h = model_pos.y * 0.5 + 0.5;
	float scan = smoothstep(0.35, 0.5, fract(h * scan_count - TIME * scan_speed * scan_count)) * scan_strength;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float body = (id == hover_id ? hover_fill : (state == 1 ? available_fill : fill)) + scan;
	if (state == 1) {
		body *= 1.0 - pulse_depth * (0.5 - 0.5 * cos(TIME * pulse_hz * 6.28318531));
	}
	ALBEDO = col * (edge ? coast : body) * (0.4 + 0.6 * facing);
}
