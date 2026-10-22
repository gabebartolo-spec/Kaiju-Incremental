shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A camera-facing flash of light (beam impact, a shell glancing off the hide): a hot core and
// four short rays. `fade` 1..0 from script.

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float fade = 1.0;
// A glance (a shell off the hide) is one round soft sprite: `streak` 1 swaps the four rays for a
// short horizontal streak (set `ray_gain` 0 for none), fades the core out before the quad's edge
// and softens where it meets the street; the core's width, strength and the halo are set to suit.
uniform float streak = 0.0;
uniform float streak_len = 0.5;
uniform float core_width = 18.0;
uniform float core_gain = 4.0;
uniform float halo_gain = 0.5;
uniform float ray_gain = 1.5;
// A glance fades out where its quad meets the street (a soft intersection), not in a hard line.
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float meet_fade = 1.2;

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
	float core = exp(-r * r * core_width);
	float halo = exp(-r * 4.0) * halo_gain;
	float cross_rays = exp(-abs(p.x * p.y) * 90.0) * (1.0 - smoothstep(0.2, 1.0, r));
	float line = exp(-abs(p.y) * 40.0) * (1.0 - smoothstep(0.0, streak_len, abs(p.x)));
	float rays = mix(cross_rays, line, streak);
	vec3 hot = mix(tint.rgb, vec3(1.0), core);
	// A glance's wide soft core must be gone before the quad's edge, or the quad shows as a square.
	float edge = mix(1.0, 1.0 - smoothstep(0.35, 0.9, r), streak);
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(depth_tex, SCREEN_UV).x, 1.0);
	float gap = -(scene.z / scene.w) + VERTEX.z;  // how far in front of the street this pixel is
	float meet = mix(1.0, clamp(gap / meet_fade, 0.0, 1.0), streak);
	ALBEDO = hot * (core * core_gain + halo + rays * ray_gain) * edge * meet * fade;
}
