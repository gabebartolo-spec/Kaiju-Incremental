shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
// A glow laid over the kaiju's own voxels (material_overlay): brightest at the silhouette, so
// the body stays readable under it. shimmer 1 runs bands up the body (Regeneration); 0 is a
// flat flash (signature ready). Additive and thin, so it never hides the kaiju (D-025).

uniform vec4 tint : source_color = vec4(0.55, 1.0, 0.7, 1.0);
uniform float strength = 0.0;
uniform float shimmer = 0.0;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float bands = mix(1.0, 0.35 + 0.65 * pow(0.5 + 0.5 * sin(world_y * 1.6 - TIME * 5.0), 3.0), shimmer);
	ALBEDO = tint.rgb * strength * (0.2 + 1.6 * rim) * bands;
}
