shader_type spatial;
render_mode cull_back, shadows_disabled, fog_disabled;
// A blast's solid voxel (BlastParts fireball, smoke, chem cloud; BlastShock ring; lead QC
// 2026-10-21: "opaque, lit voxel cubes"): an opaque, lit cube in the particle's colour, so it
// sorts and hides like any other block in the city (trees and cars in front of it cover it, it
// covers what is behind). The city's fog never pales it (fog_disabled: a fireball read peach
// and the gas mint through it). Colour brighter than 1 (HDR: the fireball's yellow-white core
// about 4x, its orange about 2x) is driven by emission at that strength (`glow` times the
// colour, eased in as the brightest channel passes 1), so the tonemapper keeps hot cubes
// saturated instead of whiting them out through albedo; soot, smoke,
// dust and gas are plain lit blocks. It never fades by alpha: a voxel goes by shrinking (the
// particle's scale curve).

uniform float glow = 1.0;
uniform float dim = 0.85;

void fragment() {
	vec3 c = COLOR.rgb;
	float hot = clamp(max(c.r, max(c.g, c.b)) - 1.0, 0.0, 1.0);
	// The hue, never paled to white; a hot cube is mostly its own light, so the city's hazy
	// ambient cannot grey it (round 5: the fireball read caramel through the lit albedo).
	ALBEDO = c / max(1.0, max(c.r, max(c.g, c.b))) * (1.0 - hot * dim);
	EMISSION = c * hot * glow;
	ROUGHNESS = 0.9;
}
