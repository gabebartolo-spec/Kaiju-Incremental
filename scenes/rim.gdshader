shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;
// Regeneration, laid over the kaiju's own voxels (material_overlay): thin green rings run up
// the body and nothing between them is lit, so the hide stays readable. Additive and thin, so it never hides the kaiju (D-025).

uniform vec4 tint : source_color = vec4(0.55, 1.0, 0.7, 1.0);
uniform float strength = 0.0;

void fragment() {
	// World height per fragment: MODEL_MATRIX skips each voxel's own multimesh transform.
	float world_y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	float ring = pow(0.5 + 0.5 * sin(world_y * 1.4 - TIME * 4.0), 12.0);
	ALBEDO = tint.rgb * strength * ring * 2.5;
}
