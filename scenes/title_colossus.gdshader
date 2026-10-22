shader_type spatial;
// The title screen's colossus (scenes/title_colossus.gd): a baked black silhouette of the game's
// reptilian kaiju seen from behind, drawn as a camera-facing card. Only a thin rim, where the
// inferno behind it spills round the edge, takes the fire's colour; the rest is as dark as the
// smoke. `amount` is how much of it shows (0 hidden in the smoke .. 1 plain against the fire).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D body : source_color, filter_linear_mipmap;
uniform float amount = 0.0;
uniform vec3 rim_colour : source_color = vec3(1.0, 0.45, 0.12);
uniform float rim_width = 0.012;
uniform float rim_strength = 1.4;
// Where the fire light comes from, in the card's uv (y down): the edges facing it catch it, the
// rest only a little (rim_min), so the body is not outlined all round.
uniform vec2 rim_light = vec2(-0.3, 0.95);
uniform float rim_min = 0.1;
uniform vec3 body_colour : source_color = vec3(0.02, 0.012, 0.014);
// Smoke drifting in front of it: how much of the body the smog eats, more toward the feet and the
// tail than at the spines, shoulders and head (0 solid .. 1).
uniform float smog = 0.6;
uniform float smog_tail = 0.5;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float a = texture(body, UV).a;
	float around = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;
		around += texture(body, UV + vec2(cos(ang), sin(ang)) * rim_width).a;
	}
	around *= 0.125;
	// Lit only where the body meets empty air AND the edge faces the fire's light; thinner along the
	// top (the back-light on the spines), eaten by the smog in patches.
	float top = 1.0 - UV.y;
	vec2 grad = vec2(
		texture(body, UV + vec2(rim_width, 0.0)).a - texture(body, UV - vec2(rim_width, 0.0)).a,
		texture(body, UV + vec2(0.0, rim_width)).a - texture(body, UV - vec2(0.0, rim_width)).a);
	vec2 outward = -normalize(grad + vec2(0.0001));
	float catches = clamp(dot(outward, rim_light), 0.0, 1.0);
	float aim = rim_min + (1.0 - rim_min) * pow(catches, 1.3);
	float rim = clamp(a - around, 0.0, 1.0) * rim_strength * aim * mix(0.55, 1.0, smoothstep(0.2, 0.9, top));
	ALBEDO = mix(body_colour, rim_colour, clamp(rim, 0.0, 1.0));
	// Smog: slow patches of smoke over the body, thickest low down and along the tail, so the
	// legs and the tail fade into it and the head, shoulders and spines read.
	vec2 q = UV * vec2(2.4, 1.0) * 1.6 + vec2(TIME * 0.012, -TIME * 0.008);
	float patch = smoothstep(0.3, 0.7, texture(noise_tex, q).r * 0.65 + texture(noise_tex, q * 2.7 + 0.3).r * 0.35);
	float low = smoothstep(0.55, 0.1, top);
	float along = smoothstep(0.3, 0.95, UV.x);
	float eaten = clamp(smog * (0.35 * patch + 0.85 * low) + smog_tail * along, 0.0, 0.92);
	ALBEDO = mix(body_colour, rim_colour, clamp(rim * (1.0 - 0.85 * patch), 0.0, 1.0));
	ALPHA = a * amount * (1.0 - eaten * 0.9);
}
