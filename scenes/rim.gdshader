shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;
// A glow laid over the kaiju's own voxels (material_overlay): brightest at the silhouette, so
// the body stays readable under it. shimmer 1 runs thin rings up the body (Regeneration) and
// lights nothing between them; 0 is a rim flash (signature ready). Additive and thin, so it never hides the kaiju (D-025).

uniform vec4 tint : source_color = vec4(0.55, 1.0, 0.7, 1.0);
uniform float strength = 0.0;
uniform float shimmer = 0.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	// World height per fragment: MODEL_MATRIX skips each voxel's own multimesh transform.
	float world_y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	float ring = pow(0.5 + 0.5 * sin(world_y * 1.4 - TIME * 4.0), 12.0);
	float flash = 0.04 + 1.2 * rim;
	ALBEDO = tint.rgb * strength * mix(flash, ring * 2.5, shimmer);
}
