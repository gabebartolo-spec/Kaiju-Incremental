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
};

} // namespace godot
