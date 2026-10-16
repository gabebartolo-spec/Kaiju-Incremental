shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A camera-facing flash of light (beam impact, a shell glancing off the hide): a hot core and
// four short rays. `fade` 1..0 from script.

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float fade = 1.0;

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
	ALBEDO = hot * (core * 4.0 + halo + rays * 1.5) * fade;
}
