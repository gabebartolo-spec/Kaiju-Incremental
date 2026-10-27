shader_type spatial;
// The jagged stone chunks he breaks into when he shatters (scenes/death_view.gd: his voxels and the
// sim's shards, as the broken rock of assets/death/chunk_*.obj; director 2026-10-27, D-323: "Jagged
// stone chunks", irregular broken rock in his hide's texture). His hide's stone at his hide's scale:
// the chunk is cut into cubes one voxel of his body across (`voxel`), and each takes the SAME stone
// tone his stoned hide gives a cube (stone_body.gdshaderinc, the formula voxel_skin.gdshader turns him
// to stone with: his own shade kept, varied cube by cube), with the city's surface grain on every
// facet (surface_detail.gdshaderinc: fine blocks, specks, a faint seam) and a few hairline cracks, so
// a chunk is textured stone, never a flat block (flat_surfaces.gd). The pattern is in the chunk's own
// space at world size, so it turns with the chunk as it tumbles and is one size on every chunk.
// Per instance (MultiMesh colours): rgb his own sRGB colour where it broke off, a a 0..1 hash of it.

#include "res://scenes/surface_detail.gdshaderinc"
#include "res://scenes/stone_body.gdshaderinc"

uniform float roughness_value = 1.0;
// One cube of his hide in the world (KaijuModel.VOXEL x his body scale; DeathView sets it).
uniform float voxel = 0.12;

varying vec4 piece;
varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	piece = COLOR;
	// The chunk's own space at world size (the instance scales a chunk of side 1 to its size).
	local_pos = VERTEX * length(MODEL_MATRIX[0].xyz);
	local_normal = NORMAL;
}

float hide_hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	// The pattern is the chunk's own: shifted by its hash, nudged inside the facet (no seam on it).
	vec3 q = local_pos - local_normal * 0.001 + vec3(piece.a * 47.0, piece.a * 31.0, piece.a * 59.0);
	vec2 pc = sd_cell(sd_plane(q, local_normal));
	// His hide's cubes: one stone tone per voxel of the chunk, as on his stoned body.
	float n = hide_hash(floor(q / max(0.001, voxel)));
	vec3 col = stone_rock(piece.rgb, n);
	// Hairline cracks across the facets, and a slow drift of tone.
	float crack = abs(sd_vn(pc / 0.45 + 17.0) - 0.5);
	col *= 1.0 - 0.35 * (1.0 - smoothstep(0.012, 0.03, crack));
	col *= 1.0 + (sd_fbm(pc, 1.3) - 0.5) * 0.3;
	col *= sd_grain(q, -VERTEX.z);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
}
