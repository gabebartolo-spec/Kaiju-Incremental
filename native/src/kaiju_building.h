#pragma once
// Native building bake (BuildingMesher._init for a plain BuildingVoxels, director 2026-11-02: "lets make
// the game playable"): the same visible-face bake, greedy merge and debris samples as the GDScript, in
// the same order and with the same 32-bit float math, so the arrays match it byte for byte
// (tests/run_building_bake_tests.gd holds the two equal). The GDScript cost ~120 ms a building on the
// title's 122 (14.5 s of worker time, the title's longest wait); this is the hot loop only: a dense
// occupancy grid in place of the cells dictionary's lookups.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

class KaijuBuilding : public RefCounted {
	GDCLASS(KaijuBuilding, RefCounted)

protected:
	static void _bind_methods();

public:
	// cells: Vector3i -> palette key (VoxelBuilder.cells), colors: the DIRECT cells' colours, palette:
	// key -> Color, finish: key -> finish class (VoxelAO.finish_table); dims: [w, h, d] in voxels, the
	// building's [w, height, d] in chunks, RES, style; origin: the first voxel's centre; noise: the
	// look's colour noise; face_u, face_v, axes (3 per direction), rings (8 steps of 3 per direction)
	// and ao (VoxelAO.table) as BuildingMesher._begin builds them. Returns [shell arrays, slab arrays,
	// samples] as BuildingMesher keeps them, or null when the cells span too big a box for the grid.
	Variant bake(const Dictionary &p_cells, const Dictionary &p_colors, const Dictionary &p_palette,
			const Dictionary &p_finish, const PackedInt32Array &p_dims, const Vector3 &p_origin, double p_noise,
			const PackedVector3Array &p_face_u, const PackedVector3Array &p_face_v, const PackedInt32Array &p_axes,
			const PackedInt32Array &p_rings, const PackedInt32Array &p_ao);
};

} // namespace godot
