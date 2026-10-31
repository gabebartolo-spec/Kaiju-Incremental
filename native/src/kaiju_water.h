#pragma once
// Native water step (WaterSim._pipes, director 2026-10-31: "all water behaving like water"): the
// shallow-water virtual pipes over a basin's stepped window, sub-step after sub-step, with the
// GDScript's own math: the columns stored in 32-bit floats (PackedFloat32Array), every sum and
// product in 64-bit (GDScript's floats), in the same order, so the water moves the GDScript path's
// floats bit for bit (tests/run_water_tests.gd holds the two equal). With it the whole bay is
// stepped every frame (the GDScript path costs ~8 us a column). The bay's mouth (row 0, `open`) is
// open sea: water runs out of it at the wave's own speed, so a wave leaves there, never bouncing back.
// Packed arrays are copy-on-write: step() returns the columns it changed and WaterSim keeps them.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/rect2i.hpp>

namespace godot {

class KaijuWater : public RefCounted {
	GDCLASS(KaijuWater, RefCounted)

protected:
	static void _bind_methods();

public:
	// `subs` sub-steps of `h` seconds over window r of a basin nx columns wide: floor, depth, body,
	// flow (4 per column) as WaterSim.Basin; keep: the flow each sub-step keeps (friction); g, cell,
	// rest: gravity, the column's width and the still surface; open: row 0 is open sea (the bay's
	// mouth). Returns [depth, flow, stir]:
	// stir the last sub-step's biggest surface lift (m). Arrays of the wrong length: [] (nothing moves).
	Array step(const PackedFloat32Array &p_floor, const PackedFloat32Array &p_depth, const PackedFloat32Array &p_body,
			const PackedFloat32Array &p_flow, int64_t p_nx, const Rect2i &p_r, int64_t p_subs, double p_h,
			double p_keep, double p_g, double p_cell, double p_rest, bool p_open);
};

} // namespace godot
