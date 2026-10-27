#pragma once
// Native MultiMesh buckets (render plan item 7, render_opt.people_buffers): a set of MultiMeshes
// filled one frame at a time. Each bucket's instances are written into one float buffer in the
// layout MultiMesh.set_instance_transform writes (the 3x4 transform row by row, the origin in each
// row's fourth place, then the colour when coloured) and handed to its MultiMesh in one set_buffer,
// instead of one setter call per instance. scenes/multimesh_buckets.gd drives it; without the
// extension that script falls back to the per-instance setters.
// add() places one ready transform (the rooftop's figures and pools, the street's officers).
// add_people() places all of StreetLife's civilians in one call with the GDScript's own math
// (StreetLife.pose and _draw_people): the turn and the Basis come from the ENGINE (its atan2 utility
// and its Basis(axis, angle) constructor), so the floats are the GDScript path's bit for bit
// (tests/run_street_tests.gd holds them to it); this library's own trig may differ in the last bit.
// A buffer must be exactly instance_count * stride long, so a bucket's instance_count follows its
// instances: it grows by half again when full and shrinks once the bucket is under half full.
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <vector>

namespace godot {

class KaijuBuckets : public RefCounted {
	GDCLASS(KaijuBuckets, RefCounted)

	struct Bucket {
		Ref<MultiMesh> mm;
		std::vector<float> data; // slots * stride floats; [0, count * stride) is this frame's
		PackedFloat32Array shown; // the buffer last handed to the MultiMesh
		int32_t slots = 0; // the instance_count this frame needs
		int32_t allocated = 0; // the MultiMesh's instance_count
		int32_t count = 0; // instances added since begin()
		int32_t shown_count = -1; // the visible count last committed
	};
	std::vector<Bucket> buckets;
	int32_t min_slots = 1;
	int32_t stride = 12;
	bool colored = false;
	// StreetLife's poses: bucket = outfit * poses + pose; a stride alternates pose and pose + 1.
	int32_t poses = 1;
	int32_t walk_a = 0;
	int32_t run_a = 0;
	double walk_hz = 0.0;
	double run_hz = 0.0;
	GDExtensionPtrConstructor basis_axis_angle = nullptr;
	GDExtensionPtrUtilityFunction atan2_fn = nullptr;

	float *next_slot(Bucket &p_bucket);

protected:
	static void _bind_methods();

public:
	KaijuBuckets();
	// multimeshes: one per bucket (3D transforms; colours when colored). Each gets min_slots
	// instances. False (nothing set up) when one is not a MultiMesh or min_slots < 1.
	bool setup(const Array &p_multimeshes, int32_t p_min_slots, bool p_colored);
	// VoxelPerson.POSES, Pose.WALK_A, Pose.RUN_A and StreetLife.WALK_HZ / RUN_HZ.
	void set_poses(int32_t p_poses, int32_t p_walk_a, int32_t p_run_a, double p_walk_hz, double p_run_hz);
	void begin();
	// The next instance of bucket b stands at t (and shows colour c when coloured).
	void add(int32_t p_bucket, const Transform3D &p_transform, const Color &p_color);
	// StreetLife's people in array order, officers (cop 1) skipped: each civilian in the bucket of its
	// outfit and pose unless that bucket already holds `capacity`, at pos + its side step, turned to
	// its heading. Returns every bucket's count. Columns must be the same length (else nothing added).
	PackedInt32Array add_people(const PackedVector2Array &p_pos, const PackedVector2Array &p_heading,
			const PackedFloat64Array &p_side, const PackedInt32Array &p_outfit, const PackedFloat64Array &p_phase,
			const PackedFloat64Array &p_pinned_until, const PackedByteArray &p_fleeing, const PackedByteArray &p_cop,
			double p_clock, int32_t p_capacity);
	// Shows what was added: each MultiMesh gets its instance_count, its buffer and its visible count.
	void commit();
	PackedInt32Array get_counts() const;
	// The buffer bucket b last handed its MultiMesh (instance_count * stride floats).
	PackedFloat32Array get_buffer(int32_t p_bucket) const;
};

} // namespace godot
