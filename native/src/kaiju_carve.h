#pragma once
// Native carve core (WP2). Same algorithm as the spike's carve_grid.gd and native_bench.cpp:
// a building is a byte grid (0 = empty), index x + z*w + y*w*d, dims = (w, h, d). The object
// owns the grid after set_grid(), so a carve never copies it (a PackedByteArray passed to a
// call is a copy the caller cannot see mutated). Positions and radii are in CELL units.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
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
};

} // namespace godot
