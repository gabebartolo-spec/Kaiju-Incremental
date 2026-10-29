#pragma once
// Native carve core (WP2). Same algorithm as the spike's carve_grid.gd and native_bench.cpp:
// a building is a byte grid (0 = empty), index x + z*w + y*w*d, dims = (w, h, d). The object
// owns the grid after set_grid(), so a carve never copies it (a PackedByteArray passed to a
// call is a copy the caller cannot see mutated). Positions and radii are in CELL units.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector3i.hpp>

namespace godot {

class KaijuCarve : public RefCounted {
	GDCLASS(KaijuCarve, RefCounted)

	PackedByteArray cells;
	int w = 0, h = 0, d = 0;

protected:
	static void _bind_methods();

public:
	// Takes the grid; returns false (and holds nothing) when its size is not w*h*d.
	bool set_grid(const PackedByteArray &p_grid, const Vector3i &p_dims);
	PackedByteArray get_grid() const;
	// Empties every cell whose centre is inside the sphere; returns the cells removed.
	int carve_sphere(const Vector3 &p_centre, float p_radius);
	// Empties every cell not 6-connected to a non-empty cell of the ground layer (y = 0);
	// returns the cells removed.
	int ground_flood();
	// CarveCollider's boxes for one region of a building's grid (render plan item 10, D-311;
	// scenes/carve_collider.gd is the oracle). The region is p_bricks bricks a side from brick
	// p_region * p_bricks, a brick p_res cells a side, taken in y, z, x order. A brick gives the
	// cell box round its solid cells; when those fill less than p_sparse of that box (and
	// p_res >= 2) it gives the box of each non-empty half-brick instead, in y, z, x order. Six ints
	// a box: its lower cell x, y, z, then its size in cells x, y, z. Reads p_grid (dims p_dims, the
	// layout above) and keeps nothing; empty when the grid does not match its dims.
	PackedInt32Array region_boxes(const PackedByteArray &p_grid, const Vector3i &p_dims,
			const Vector3i &p_region, int p_bricks, int p_res, double p_sparse) const;
};

} // namespace godot
