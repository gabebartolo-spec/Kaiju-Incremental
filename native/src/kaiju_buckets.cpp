#include "kaiju_buckets.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/core/gdextension_interface_loader.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <algorithm>
#include <cstring>

using namespace godot;

static const int32_t TRANSFORM_FLOATS = 12;
static const int32_t COLOR_FLOATS = 4;
// Basis(axis: Vector3, angle: float), the constructor GDScript's Basis(Vector3.UP, a) runs
// (index 3 of Basis's constructors in godot-cpp/gdextension/extension_api-4-7.json).
static const int32_t BASIS_AXIS_ANGLE = 3;

// One transform's 12 floats as the MultiMesh setter writes them: row r = basis row r, origin[r].
static inline void write_transform(float *w, const Basis &b, float ox, float oy, float oz) {
	w[0] = b.rows[0][0];
	w[1] = b.rows[0][1];
	w[2] = b.rows[0][2];
	w[3] = ox;
	w[4] = b.rows[1][0];
	w[5] = b.rows[1][1];
	w[6] = b.rows[1][2];
	w[7] = oy;
	w[8] = b.rows[2][0];
	w[9] = b.rows[2][1];
	w[10] = b.rows[2][2];
	w[11] = oz;
}

void KaijuBuckets::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "multimeshes", "min_slots", "colored"), &KaijuBuckets::setup);
	ClassDB::bind_method(D_METHOD("set_poses", "poses", "walk_a", "run_a", "walk_hz", "run_hz"), &KaijuBuckets::set_poses);
	ClassDB::bind_method(D_METHOD("begin"), &KaijuBuckets::begin);
	ClassDB::bind_method(D_METHOD("add", "bucket", "transform", "color"), &KaijuBuckets::add);
	ClassDB::bind_method(D_METHOD("add_people", "pos", "heading", "side", "outfit", "phase", "pinned_until", "fleeing",
								 "cop", "clock", "capacity"),
			&KaijuBuckets::add_people);
	ClassDB::bind_method(D_METHOD("commit"), &KaijuBuckets::commit);
	ClassDB::bind_method(D_METHOD("get_counts"), &KaijuBuckets::get_counts);
	ClassDB::bind_method(D_METHOD("get_buffer", "bucket"), &KaijuBuckets::get_buffer);
}

KaijuBuckets::KaijuBuckets() {
	basis_axis_angle = gdextension_interface::variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_BASIS, BASIS_AXIS_ANGLE);
}

bool KaijuBuckets::setup(const Array &p_multimeshes, int32_t p_min_slots, bool p_colored) {
	buckets.clear();
	ERR_FAIL_COND_V(p_min_slots < 1, false);
	std::vector<Bucket> made(size_t(p_multimeshes.size()));
	for (int64_t b = 0; b < p_multimeshes.size(); b++) {
		MultiMesh *mm = Object::cast_to<MultiMesh>(p_multimeshes[b].operator Object *());
		ERR_FAIL_NULL_V(mm, false);
		made[size_t(b)].mm = Ref<MultiMesh>(mm);
	}
	min_slots = p_min_slots;
	colored = p_colored;
	stride = TRANSFORM_FLOATS + (colored ? COLOR_FLOATS : 0);
	for (Bucket &bk : made) {
		bk.slots = min_slots;
		bk.allocated = min_slots;
		bk.data.assign(size_t(min_slots) * size_t(stride), 0.0f);
		bk.mm->set_instance_count(min_slots);
	}
	buckets = std::move(made);
	return true;
}

void KaijuBuckets::set_poses(int32_t p_poses, int32_t p_walk_a, int32_t p_run_a, double p_walk_hz, double p_run_hz) {
	poses = p_poses;
	walk_a = p_walk_a;
	run_a = p_run_a;
	walk_hz = p_walk_hz;
	run_hz = p_run_hz;
}

void KaijuBuckets::begin() {
	for (Bucket &bk : buckets) {
		bk.count = 0;
	}
}

// The next free slot of a bucket (full: it grows by half again, as the GDScript buckets did).
float *KaijuBuckets::next_slot(Bucket &p_bucket) {
	const int32_t n = p_bucket.count++;
	if (n >= p_bucket.slots) {
		p_bucket.slots = n + 1 + (n >> 1);
		p_bucket.data.resize(size_t(p_bucket.slots) * size_t(stride), 0.0f);
	}
	return p_bucket.data.data() + size_t(n) * size_t(stride);
}

void KaijuBuckets::add(int32_t p_bucket, const Transform3D &p_transform, const Color &p_color) {
	ERR_FAIL_INDEX(p_bucket, int32_t(buckets.size()));
	float *w = next_slot(buckets[size_t(p_bucket)]);
	const Vector3 &o = p_transform.origin;
	write_transform(w, p_transform.basis, o.x, o.y, o.z);
	if (colored) {
		w[12] = p_color.r;
		w[13] = p_color.g;
		w[14] = p_color.b;
		w[15] = p_color.a;
	}
}

PackedInt32Array KaijuBuckets::add_people(const PackedVector2Array &p_pos, const PackedVector2Array &p_heading,
		const PackedFloat64Array &p_side, const PackedInt32Array &p_outfit, const PackedFloat64Array &p_phase,
		const PackedFloat64Array &p_pinned_until, const PackedByteArray &p_fleeing, const PackedByteArray &p_cop,
		double p_clock, int32_t p_capacity) {
	const int64_t n = p_pos.size();
	const bool same = p_heading.size() == n && p_side.size() == n && p_outfit.size() == n && p_phase.size() == n &&
			p_pinned_until.size() == n && p_fleeing.size() == n && p_cop.size() == n;
	ERR_FAIL_COND_V_MSG(!same, get_counts(), "add_people: the columns differ in length");
	ERR_FAIL_NULL_V(basis_axis_angle, get_counts());
	const Vector2 *pos = p_pos.ptr();
	const Vector2 *heading = p_heading.ptr();
	const double *side = p_side.ptr();
	const int32_t *outfit = p_outfit.ptr();
	const double *phase = p_phase.ptr();
	const double *pinned = p_pinned_until.ptr();
	const uint8_t *fleeing = p_fleeing.ptr();
	const uint8_t *cop = p_cop.ptr();
	const uint32_t count = uint32_t(buckets.size());
	const Vector3 up(0, 1, 0);
	for (int64_t i = 0; i < n; i++) {
		if (cop[i] == 1) {
			continue;
		}
		// StreetLife.pose for a civilian: standing while pinned, else a stride at its pace's rate.
		int32_t pose = walk_a;
		if (!(pinned[i] > p_clock)) {
			const bool running = fleeing[i] == 1;
			const double beat = p_clock * (running ? run_hz : walk_hz) + phase[i] * 2.0;
			pose = (running ? run_a : walk_a) + int32_t(int64_t(beat) % 2);
		}
		const int32_t bucket = outfit[i] * poses + pose;
		if (uint32_t(bucket) >= count) {
			continue;
		}
		Bucket &bk = buckets[size_t(bucket)];
		if (bk.count >= p_capacity) {
			continue;
		}
		// _draw_people: at = pos + Vector2(-look.y, look.x) * side (float math, side to a float first);
		// basis = Basis(Vector3.UP, atan2(-look.x, -look.y)), both through the engine.
		const Vector2 look = heading[i];
		const float s = float(side[i]);
		const float ax = pos[i].x + (-look.y) * s;
		const float az = pos[i].y + look.x * s;
		const double angle = UtilityFunctions::atan2(-double(look.x), -double(look.y));
		Basis basis;
		const GDExtensionConstTypePtr args[2] = { &up, &angle };
		basis_axis_angle(&basis, args);
		write_transform(next_slot(bk), basis, ax, 0.0f, az);
	}
	return get_counts();
}

void KaijuBuckets::commit() {
	for (Bucket &bk : buckets) {
		if (bk.slots > min_slots && bk.count * 2 < bk.slots) {
			bk.slots = std::max(min_slots, bk.count + (bk.count >> 2) + 1);
			bk.data.resize(size_t(bk.slots) * size_t(stride), 0.0f);
		}
		const bool resized = bk.allocated != bk.slots;
		if (resized) {
			bk.mm->set_instance_count(bk.slots);
			bk.allocated = bk.slots;
		} else if (bk.count == 0 && bk.shown_count == 0) {
			continue; // empty before and now: nothing to show, nothing to send
		}
		PackedFloat32Array buf;
		buf.resize(int64_t(bk.slots) * stride);
		memcpy(buf.ptrw(), bk.data.data(), sizeof(float) * bk.data.size());
		bk.mm->set_buffer(buf);
		bk.mm->set_visible_instance_count(bk.count);
		bk.shown = buf;
		bk.shown_count = bk.count;
	}
}

PackedInt32Array KaijuBuckets::get_counts() const {
	PackedInt32Array out;
	out.resize(int64_t(buckets.size()));
	int32_t *w = out.ptrw();
	for (size_t b = 0; b < buckets.size(); b++) {
		w[b] = buckets[b].count;
	}
	return out;
}

PackedFloat32Array KaijuBuckets::get_buffer(int32_t p_bucket) const {
	ERR_FAIL_INDEX_V(p_bucket, int32_t(buckets.size()), PackedFloat32Array());
	return buckets[size_t(p_bucket)].shown;
}
