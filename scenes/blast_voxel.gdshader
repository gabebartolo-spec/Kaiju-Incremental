shader_type spatial;
render_mode cull_back, shadows_disabled;
// A blast's solid voxel (BlastParts fireball, smoke, chem cloud; BlastShock ring; lead QC
// 2026-10-21: "opaque, lit voxel cubes"): an opaque, lit cube in the particle's colour, so it
// sorts and hides like any other block in the city (trees and cars in front of it cover it, it
// covers what is behind). Colour above 1 (HDR, the fireball's white-hot core) glows: the excess
// over `glow_from` becomes emission, so hot cubes burn and soot, smoke and gas are plain lit
// blocks. It never fades by alpha: a voxel goes by shrinking (the particle's scale curve).

uniform float glow_from = 0.6;
uniform float glow = 1.6;

void fragment() {
	ALBEDO = clamp(COLOR.rgb, 0.0, 1.0);
	EMISSION = max(COLOR.rgb - vec3(glow_from), vec3(0.0)) * glow;
	ROUGHNESS = 0.9;
}
