#include "kaiju_walk.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <cmath>

using namespace godot;

// Vector2's own math (core/math/vector2.cpp), written out so no library variant can differ.
static inline float length_of(float x, float y) {
	return std::sqrt(x * x + y * y);
}

static inline void normalize(float &x, float &y) {
	float l = x * x + y * y;
	if (l != 0.0f) {
		l = std::sqrt(l);
		x /= l;
		y /= l;
	}
}

void KaijuWalk::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_nodes", "nodes"), &KaijuWalk::set_nodes);
	ClassDB::bind_method(D_METHOD("set_frame", "panic", "calm", "gawk", "run", "walk"), &KaijuWalk::set_frame);
	ClassDB::bind_method(D_METHOD("step", "pos", "heading", "fleeing", "pinned_until", "from_node", "to_node", "pace",
								 "cop", "kaiju", "clock", "delta"),
			&KaijuWalk::step);
}

void KaijuWalk::set_nodes(const PackedVector2Array &p_nodes) {
	nodes = p_nodes;
}

void KaijuWalk::set_frame(double p_panic, double p_calm, double p_gawk, double p_run, double p_walk) {
	panic = p_panic;
	calm = p_calm;
	gawk = p_gawk;
	run_speed = p_run;
	walk_speed = p_walk;
}

Array KaijuWalk::step(const PackedVector2Array &p_pos, const PackedVector2Array &p_heading,
		const PackedByteArray &p_fleeing, const PackedFloat64Array &p_pinned_until, const PackedInt32Array &p_from,
		const PackedInt32Array &p_to, const PackedFloat64Array &p_pace, const PackedByteArray &p_cop,
		const Vector2 &p_kaiju, double p_clock, double p_delta) {
	const int64_t n = p_pos.size();
	const bool same = p_heading.size() == n && p_fleeing.size() == n && p_pinned_until.size() == n &&
			p_from.size() == n && p_to.size() == n && p_pace.size() == n && p_cop.size() == n;
	ERR_FAIL_COND_V_MSG(!same, Array(), "KaijuWalk.step: the columns differ in length");
	// Copy-on-write: a column is copied only when this frame changes it.
	PackedVector2Array pos = p_pos;
	PackedVector2Array heading = p_heading;
	PackedByteArray fleeing = p_fleeing;
	PackedFloat64Array pinned = p_pinned_until;
	PackedInt32Array from = p_from;
	PackedInt32Array to = p_to;
	PackedInt32Array corners;
	Vector2 *pos_w = n > 0 ? pos.ptrw() : nullptr;
	Vector2 *heading_w = n > 0 ? heading.ptrw() : nullptr;
	uint8_t *fleeing_w = nullptr;
	double *pinned_w = nullptr;
	int32_t *from_w = nullptr;
	int32_t *to_w = nullptr;
	const uint8_t *fleeing_r = p_fleeing.ptr();
	const double *pinned_r = p_pinned_until.ptr();
	const int32_t *from_r = p_from.ptr();
	const int32_t *to_r = p_to.ptr();
	const double *pace = p_pace.ptr();
	const uint8_t *cop = p_cop.ptr();
	const Vector2 *node = nodes.ptr();
	const int64_t node_count = nodes.size();
	const float kx = p_kaiju.x;
	const float ky = p_kaiju.y;
	int64_t startled = 0;
	for (int64_t i = n - 1; i >= 0; i--) {
		if (cop[i] == 1 || pinned_r[i] > p_clock) {
			continue;
		}
		const float ax = pos_w[i].x;
		const float ay = pos_w[i].y;
		const float d = length_of(ax - kx, ay - ky); // at.distance_to(kaiju)
		if (fleeing_r[i] == 0 && double(d) < panic) {
			// _startle: a moment facing the kaiju, then it runs; one walking toward it turns.
			if (fleeing_w == nullptr) {
				fleeing_w = fleeing.ptrw();
				fleeing_r = fleeing_w;
			}
			if (pinned_w == nullptr) {
				pinned_w = pinned.ptrw();
				pinned_r = pinned_w;
			}
			fleeing_w[i] = 1;
			startled++;
			pinned_w[i] = p_clock + gawk;
			float hx = kx - ax;
			float hy = ky - ay;
			normalize(hx, hy);
			heading_w[i] = Vector2(hx, hy);
			ERR_FAIL_INDEX_V(to_r[i], node_count, Array());
			const Vector2 ahead = node[to_r[i]];
			if ((ahead.x - ax) * (kx - ax) + (ahead.y - ay) * (ky - ay) > 0.0f) {
				if (from_w == nullptr) {
					from_w = from.ptrw();
					from_r = from_w;
				}
				if (to_w == nullptr) {
					to_w = to.ptrw();
					to_r = to_w;
				}
				const int32_t swap = from_w[i];
				from_w[i] = to_w[i];
				to_w[i] = swap;
			}
		} else if (fleeing_r[i] == 1 && double(d) > calm) {
			if (fleeing_w == nullptr) {
				fleeing_w = fleeing.ptrw();
				fleeing_r = fleeing_w;
			}
			fleeing_w[i] = 0;
		}
		const bool running = fleeing_r[i] == 1;
		ERR_FAIL_INDEX_V(to_r[i], node_count, Array());
		const Vector2 goal = node[to_r[i]];
		float tx = goal.x - ax;
		float ty = goal.y - ay;
		const double step = (running ? run_speed : walk_speed) * pace[i] * p_delta;
		if (double(length_of(tx, ty)) > step) {
			normalize(tx, ty);
			heading_w[i] = Vector2(tx, ty);
			const float fs = float(step); // Vector2 * float takes the float as a real_t
			pos_w[i] = Vector2(ax + tx * fs, ay + ty * fs);
			continue;
		}
		pos_w[i] = goal;
		corners.push_back(int32_t(i));
	}
	Array out;
	out.append(pos);
	out.append(heading);
	out.append(fleeing);
	out.append(pinned);
	out.append(from);
	out.append(to);
	out.append(corners);
	out.append(startled);
	return out;
}
