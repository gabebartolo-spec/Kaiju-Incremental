#pragma once
// Native support flood (b2-3): the three whole-grid passes of VoxelSupport (sim/voxel_support.gd),
// which the GDScript runs cell by cell. Same results as that code, which stays the oracle
// (tests/lib/settle_replay.gd holds this to it on seeded carves of real building grids): every
// scan, neighbour and tie-break order below is the GDScript's. A grid is a byte array, index
// x + z*w + y*w*d, dims = (w, h, d); fixtures[m] is 1 when material m is a fixture. Stateless:
// every call reads its arguments and returns fresh arrays, so it is safe on several threads.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/vector3i.hpp>

namespace godot {

class KaijuSettle : public RefCounted {
	GDCLASS(KaijuSettle, RefCounted)

protected:
	static void _bind_methods();

public:
	// [labels: PackedInt32Array, count: int]. labels: per cell, the label (1, 2, ... in scan order
	// of the part's first ground cell) of the grounded part it is in, 0 when not grounded.
	// Structural parts are the 6-connected ones touching layer 0; fixtures then join a part they
	// touch (26 neighbours) or start one on layer 0 (VoxelSupport._init).
	Array label(const PackedByteArray &p_cells, const PackedByteArray &p_fixtures, const Vector3i &p_dims,
			bool p_has_fixtures) const;
	// The ungrounded parts, as VoxelSupport.islands(): each a PackedInt32Array of grid indices in
	// flood order, parts in scan order of their first cell.
	Array islands(const PackedInt32Array &p_labels, const PackedByteArray &p_cells,
			const PackedByteArray &p_fixtures, const Vector3i &p_dims, bool p_has_fixtures) const;
	// {"mass", "sx", "sz": PackedInt64Array, "box": PackedInt32Array}: VoxelSupport._floors().
	Dictionary floors(const PackedInt32Array &p_labels, const PackedByteArray &p_cells,
			const PackedByteArray &p_fixtures, const Vector3i &p_dims, int p_count) const;

	// The per-cell loops around a settle and a blow (b2-3 part 3, kaiju_settle_parts.cpp), each
	// the GDScript it replaces, which stays the reference (VoxelFrame, VoxelSupport, Carving).
	// A grid's chunk owners: cx, cz, fy map grid x, z, y to the chunk column and floor
	// (Carving.Grid); `geo` packs [w, d, h, bw, bd].

	// The cells of grounded part `label` from grid index `from` on (VoxelFrame.settle_full).
	PackedInt32Array gather(const PackedInt32Array &p_labels, const PackedByteArray &p_cells, int p_from,
			int p_label) const;
	// Empties every part's cells: [cells, mats: Array of PackedByteArray, list: Array of Arrays of
	// building-local Vector3i] (VoxelFrame._take, parts in order).
	Array take(const PackedByteArray &p_cells, const Array &p_parts, const Vector3i &p_dims,
			const Vector3i &p_offset) const;
	// Where an island (out of the grid) meets what stands below it: PackedInt64Array [sum 2x+1,
	// sum 2z+1, mass, box x0, z0, x1, z1 (the columns with the least gap), lands, least gap]
	// (VoxelSupport.landing, Carving._drop).
	PackedInt64Array land(const PackedInt32Array &p_part, const PackedByteArray &p_cells,
			const Vector3i &p_dims) const;
	// Per chunk, its non-empty cells (Carving._promote).
	PackedInt32Array chunk_counts(const PackedByteArray &p_cells, const PackedInt32Array &p_cx,
			const PackedInt32Array &p_cz, const PackedInt32Array &p_fy, const PackedInt32Array &p_geo,
			int p_chunks) const;
	// A fallen part's bookkeeping (Carving.settle): [live (one less per cell, by chunk),
	// PackedInt32Array [lo x, y, z, hi x, y, z, base x0, z0, x1, z1, under]].
	Array part_info(const PackedInt32Array &p_index, const PackedByteArray &p_cells,
			const PackedInt32Array &p_cx, const PackedInt32Array &p_cz, const PackedInt32Array &p_fy,
			const PackedInt32Array &p_geo, const PackedInt32Array &p_live) const;
	// A blow's wear on a grid (Carving.hit's and Carving.apply's loops, Carving.wear_column):
	// spans holds per chunk [x0, x1, z0, z1, floor]; each column takes damage x at[col] x mult
	// where at[col] > 0, or, when `at` is empty, amounts[chunk] x mult on every column. nums
	// [damage, mult, hp, weakest], ints [w, d, h, bw, bd, floors, offset y, res].
	// Returns [cells, wear, live, removed, mats].
	Array wear(const PackedByteArray &p_cells, const PackedFloat32Array &p_wear,
			const PackedFloat32Array &p_at, const PackedFloat32Array &p_amounts, const PackedInt32Array &p_spans,
			const PackedFloat32Array &p_strength, const PackedFloat64Array &p_nums,
			const PackedInt32Array &p_ints, const PackedInt32Array &p_cx, const PackedInt32Array &p_cz,
			const PackedInt32Array &p_fy, const PackedInt32Array &p_live) const;

	// A beam's force per grid column (Carving.hit's sampling loop, RampageSim.Beam.reaches): 1 or 0
	// on each column the spans cover, -1 elsewhere. ints [w, d, offset x, offset z, res], nums
	// [world x0, world z0, origin x, origin y, dir x, dir y, length, half].
	PackedFloat32Array beam_at(const PackedInt32Array &p_spans, const PackedInt32Array &p_ints,
			const PackedFloat64Array &p_nums) const;

	// BuildingCells' generation (b2-3 part 4, kaiju_cells.cpp): [offset, dims, cells] as
	// sim/building_cells.gd makes them, or an empty Array when a mark falls outside its margin.
	// ints [w, d, floors, res, style, tier, column_bay, party side bits, neon count], nums [x, z,
	// sign chance], ids: material id per BuildingCells.NATIVE_KEYS.
	Array cells(const PackedInt32Array &p_ints, const PackedFloat64Array &p_nums, const PackedInt32Array &p_ids) const;
};

} // namespace godot
