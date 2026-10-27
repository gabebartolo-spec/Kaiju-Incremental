#pragma once
// Native street walk (render plan item 7, render_opt.people_buffers): StreetLife._walk's step for
// every civilian in one call, with the GDScript's own math: positions and headings in 32-bit floats
// (Vector2's distance_to, length, normalized, dot, `+` and `* float`), the paces, clocks and radii in
// 64-bit (GDScript's floats). + - * / and sqrt are IEEE-exact in both builds, so the people walk the
// GDScript path's floats bit for bit (tests/run_street_tests.gd holds the two paths' digests equal).
// Officers (cop 1) are skipped: Police moves them. A walker that reaches its corner stands on it and
// is listed, last index first (the GDScript loop's order); StreetLife then picks each one's next
// corner in that order (Pavements.next_corner draws from the walkers' random stream).
// Packed arrays are copy-on-write: step() returns the columns it changed and StreetLife keeps them.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

namespace godot {

class KaijuWalk : public RefCounted {
	GDCLASS(KaijuWalk, RefCounted)

	PackedVector2Array nodes; // the pavement corners (Pavements.nodes)
	double panic = 0.0; // a calm walker nearer the kaiju than this startles
	double calm = 0.0; // a fleeing one further than this calms down
	double gawk = 0.0; // seconds a startled walker stands facing the kaiju
	double run_speed = 0.0;
	double walk_speed = 0.0;

protected:
	static void _bind_methods();

public:
	void set_nodes(const PackedVector2Array &p_nodes);
	// This frame's radii and speeds (StreetLife._walk reads them once a frame).
	void set_frame(double p_panic, double p_calm, double p_gawk, double p_run, double p_walk);
	// One frame for every civilian, last index first, as StreetLife._walk. Returns
	// [pos, heading, fleeing, pinned_until, from_node, to_node, corners, startled]: the columns (the
	// same arrays when unchanged), the indices that reached their corner (last first) and how many
	// startled. Columns of different lengths: nothing moves (an empty array).
	Array step(const PackedVector2Array &p_pos, const PackedVector2Array &p_heading, const PackedByteArray &p_fleeing,
			const PackedFloat64Array &p_pinned_until, const PackedInt32Array &p_from, const PackedInt32Array &p_to,
			const PackedFloat64Array &p_pace, const PackedByteArray &p_cop, const Vector2 &p_kaiju, double p_clock,
			double p_delta);
};

} // namespace godot
