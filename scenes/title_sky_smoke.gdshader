shader_type spatial;
// A heavy smoke cloud puff in the title's sky (scenes/title_sky_smoke.gd): a round mass with a
// ragged noisy edge, lit orange from underneath by the fires below and darker toward its top, drifting
// slowly and slowly changing shape. Alpha-blended, unlit, camera-facing; the layer's colour and
// alpha are uniforms, so a whole layer is one draw call.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.1, 0.1, 0.1, 0.5);
// The fires' light on the puff's underside: colour and how far up the puff it reaches (0..1).
uniform vec3 under_colour : source_color = vec3(1.0, 0.42, 0.12);
uniform float under_amount = 0.0;
uniform float drift = 4.0;
uniform float morph = 0.03;
// Seamless smooth noise (an image made once in title_sky_smoke.gd), sampled with linear filtering.
uniform sampler2D noise_tex : filter_linear, repeat_enable;

varying float puff_seed;

void vertex() {
	puff_seed = fract(sin(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 30.0;
	vec3 sway = vec3(sin(TIME * 0.05 + puff_seed) * drift, cos(TIME * 0.04 + puff_seed * 1.7) * drift * 0.25, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		vec4(MODEL_MATRIX[3].xyz + sway, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 q = UV * 0.9 + puff_seed * 0.37 + vec2(TIME * morph, -TIME * morph * 0.6) * 0.3;
	float n = texture(noise_tex, q).r * 0.6 + texture(noise_tex, q * 2.3 - puff_seed).r * 0.3 + texture(noise_tex, q * 5.1).r * 0.1;
	float edge = length(p) + (n - 0.5) * 0.9;
	float mass = 1.0 - smoothstep(0.2, 1.0, edge);
	// Always fade out before the card's own border: no straight edges, whatever the noise does.
	mass *= 1.0 - smoothstep(0.72, 1.0, length(p));
	// The lower part of the puff catches the fire's light, the top stays dark.
	float low = clamp((1.0 - UV.y) * 1.4 - 0.2, 0.0, 1.0);
	vec3 col = mix(tint.rgb, under_colour, low * low * under_amount);
	ALBEDO = col * (0.75 + 0.5 * n);
	ALPHA = tint.a * mass * (0.6 + 0.8 * n);
}
