shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A camera-facing flash of light (beam impact, a shell glancing off the hide): a hot core and
// four short rays. `fade` 1..0 from script.

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float fade = 1.0;
// Callers that set them (the lightning's muzzle and strike glows): `soft` metres over which the glow
// fades out against geometry behind it (no hard straight edge where a building cuts the quad), and
// `edge` > 0 fades it to nothing before the quad's border, ragged by that much.
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float soft = 0.0;
uniform float edge = 0.0;

float hash1(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = exp(-r * r * 18.0);
	float halo = exp(-r * 4.0) * 0.5;
	float rays = exp(-abs(p.x * p.y) * 90.0) * (1.0 - smoothstep(0.2, 1.0, r));
	vec3 hot = mix(tint.rgb, vec3(1.0), core);
	float k = fade;
	if (edge > 0.0) {
		float a = atan(p.y, p.x) * 3.0;
		float n = mix(hash1(floor(a)), hash1(floor(a) + 1.0), smoothstep(0.0, 1.0, fract(a)));
		float lim = 1.0 - edge * n;
		k *= 1.0 - smoothstep(lim - 0.4, lim, r);
	}
	if (soft > 0.0) {
		float d = texture(depth_tex, SCREEN_UV).x;
		vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
		k *= clamp((-v.z / v.w + VERTEX.z) / soft, 0.0, 1.0);
	}
	float ray_share = edge > 0.0 ? 0.0 : 1.5;  // a glow with an `edge` is round: no 4-point rays
	ALBEDO = hot * (core * 4.0 + halo + rays * ray_share) * k;
}
