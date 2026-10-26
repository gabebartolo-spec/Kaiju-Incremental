shader_type spatial;
// The pieces of him that fly off when he shatters (scenes/death_view.gd: his voxels as stone blocks and
// the sim's shards): the SAME stone as his hide (stone_body.gdshaderinc, the formula
// voxel_skin.gdshader turns him to stone with: his own shade kept, cube by cube) with the city's
// surface grain on every face (surface_detail.gdshaderinc: fine blocks, specks, a faint seam) and a few
// hairline cracks, so a flying block is textured stone, never a flat box (director 2026-10-27: "i dont
// like the pale blocks that come out of the explosion"; flat_surfaces.gd). The grain is in the
// block's own space, so it turns with the block as it tumbles.
// Per instance (MultiMesh colours): rgb his own sRGB colour at that spot, a a 0..1 hash of the piece.

#include "res://scenes/surface_detail.gdshaderinc"
#include "res://scenes/stone_body.gdshaderinc"

uniform float roughness_value = 1.0;

varying vec4 piece;
varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	piece = COLOR;
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	// The pattern is the piece's own: shifted by its hash, nudged inside the face (no seam on it).
	vec3 q = local_pos - local_normal * 0.001 + vec3(piece.a * 47.0, piece.a * 31.0, piece.a * 59.0);
	vec2 pc = sd_cell(sd_plane(q, local_normal));
	vec3 col = stone_rock(piece.rgb, piece.a);
	// Hairline cracks across the faces, and a slow drift of tone.
	float crack = abs(sd_vn(pc / 0.45 + 17.0) - 0.5);
	col *= 1.0 - 0.35 * (1.0 - smoothstep(0.012, 0.03, crack));
	col *= 1.0 + (sd_fbm(pc, 1.3) - 0.5) * 0.3;
	col *= sd_grain(q, -VERTEX.z);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
