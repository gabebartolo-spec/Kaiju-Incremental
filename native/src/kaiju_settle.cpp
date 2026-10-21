#include "kaiju_settle.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <algorithm>
#include <cstdlib>
#include <cstdint>
#include <vector>

using namespace godot;

namespace {

// The cells touching cell i (26 at most, inside the grid), in VoxelSupport._ring's order: y, then
// z, then x, from -1 to +1. Returns how many; out holds the indices and face whether it shares
// a face.
struct Ring {
	int idx[26];
	bool face[26];
	int n = 0;
};

inline void ring_of(int i, int w, int d, int h, int plan, Ring &r) {
	const int x = i % w, z = (i / w) % d, y = i / plan;
	r.n = 0;
	for (int dy = std::max(-y, -1); dy < std::min(h - y, 2); dy++)
		for (int dz = std::max(-z, -1); dz < std::min(d - z, 2); dz++)
			for (int dx = std::max(-x, -1); dx < std::min(w - x, 2); dx++) {
				const int step = std::abs(dx) + std::abs(dy) + std::abs(dz);
				if (step > 0) {
					r.idx[r.n] = i + dx + dz * w + dy * plan;
					r.face[r.n] = step == 1;
					r.n++;
				}
			}
}

} // namespace

void KaijuSettle::_bind_methods() {
	ClassDB::bind_method(D_METHOD("label", "cells", "fixtures", "dims", "has_fixtures"), &KaijuSettle::label);
	ClassDB::bind_method(D_METHOD("islands", "labels", "cells", "fixtures", "dims", "has_fixtures"),
			&KaijuSettle::islands);
	ClassDB::bind_method(D_METHOD("floors", "labels", "cells", "fixtures", "dims", "count"), &KaijuSettle::floors);
}

Array KaijuSettle::label(const PackedByteArray &p_cells, const PackedByteArray &p_fixtures,
		const Vector3i &p_dims, bool p_has_fixtures) const {
	const int w = p_dims.x, h = p_dims.y, d = p_dims.z;
	const int plan = w * d;
	const int64_t n = int64_t(w) * h * d;
	PackedInt32Array labels;
	Array out;
	out.push_back(labels);
	out.push_back(0);
	if (p_cells.size() != n || p_fixtures.size() < 256 || n == 0) return out;
	labels.resize(n);
	labels.fill(0);
	int32_t *lab = labels.ptrw();
	const uint8_t *cells = p_cells.ptr();
	const uint8_t *fix = p_fixtures.ptr();
	int count = 0;
	std::vector<int> stack;
	stack.reserve(size_t(std::min<int64_t>(n, 1 << 20)));
	auto structural = [&](int j) { return cells[j] != 0 && fix[cells[j]] == 0; };
	for (int start = 0; start < plan; start++) {
		if (!structural(start) || lab[start] != 0) continue;
		count++;
		lab[start] = count;
		stack.clear();
		stack.push_back(start);
		while (!stack.empty()) {
			const int i = stack.back();
			stack.pop_back();
			const int x = i % w, z = (i / w) % d, y = i / plan;
			auto visit = [&](int j) {
				if (lab[j] == 0 && structural(j)) {
					lab[j] = count;
					stack.push_back(j);
				}
			};
			if (x > 0) visit(i - 1);
			if (x < w - 1) visit(i + 1);
			if (z > 0) visit(i - w);
			if (z < d - 1) visit(i + w);
			if (y > 0) visit(i - plan);
			if (y < h - 1) visit(i + plan);
		}
	}
	if (p_has_fixtures) {
		Ring ring;
		for (int start = 0; start < n; start++) {
			const uint8_t m = cells[start];
			if (m == 0 || fix[m] == 0 || lab[start] != 0) continue;
			int label = 0;
			ring_of(start, w, d, h, plan, ring);
			for (int r = 0; r < ring.n; r++)
				if (lab[ring.idx[r]] > 0) {
					label = lab[ring.idx[r]];
					break;
				}
			if (label == 0) {
				// A fixture on grid layer 0 is grounded though it touches nothing else.
				if (start >= plan) continue;
				count++;
				label = count;
			}
			lab[start] = label;
			stack.clear();
			stack.push_back(start);
			while (!stack.empty()) {
				const int i = stack.back();
				stack.pop_back();
				ring_of(i, w, d, h, plan, ring);
				for (int r = 0; r < ring.n; r++) {
					const int j = ring.idx[r];
					if (lab[j] == 0 && cells[j] != 0 && fix[cells[j]] != 0) {
						lab[j] = label;
						stack.push_back(j);
					}
				}
			}
		}
	}
	out[0] = labels;
	out[1] = count;
	return out;
}

Array KaijuSettle::islands(const PackedInt32Array &p_labels, const PackedByteArray &p_cells,
		const PackedByteArray &p_fixtures, const Vector3i &p_dims, bool p_has_fixtures) const {
	Array out;
	const int w = p_dims.x, h = p_dims.y, d = p_dims.z;
	const int plan = w * d;
	const int64_t n = int64_t(w) * h * d;
	if (p_cells.size() != n || p_labels.size() != n || p_fixtures.size() < 256) return out;
	const int32_t *lab = p_labels.ptr();
	const uint8_t *cells = p_cells.ptr();
	const uint8_t *fix = p_fixtures.ptr();
	std::vector<uint8_t> taken(size_t(n), 0);
	std::vector<int> part;
	Ring ring;
	auto open = [&](int j) { return lab[j] == 0 && !taken[j] && cells[j] != 0; };
	for (int start = 0; start < n; start++) {
		if (!open(start)) continue;
		part.clear();
		part.push_back(start);
		taken[start] = 1;
		for (size_t k = 0; k < part.size(); k++) {
			const int i = part[k];
			if (p_has_fixtures) {
				const bool loose = fix[cells[i]] != 0;
				ring_of(i, w, d, h, plan, ring);
				for (int r = 0; r < ring.n; r++) {
					const int j = ring.idx[r];
					if (!open(j)) continue;
					if (loose || ring.face[r] || fix[cells[j]] != 0) {
						taken[j] = 1;
						part.push_back(j);
					}
				}
				continue;
			}
			const int x = i % w, z = (i / w) % d, y = i / plan;
			auto visit = [&](int j) {
				if (open(j)) {
					taken[j] = 1;
					part.push_back(j);
				}
			};
			if (x > 0) visit(i - 1);
			if (x < w - 1) visit(i + 1);
			if (z > 0) visit(i - w);
			if (z < d - 1) visit(i + w);
			if (y > 0) visit(i - plan);
			if (y < h - 1) visit(i + plan);
		}
		PackedInt32Array island;
		island.resize(int64_t(part.size()));
		std::copy(part.begin(), part.end(), island.ptrw());
		out.push_back(island);
	}
	return out;
}

Dictionary KaijuSettle::floors(const PackedInt32Array &p_labels, const PackedByteArray &p_cells,
		const PackedByteArray &p_fixtures, const Vector3i &p_dims, int p_count) const {
	Dictionary out;
	const int w = p_dims.x, h = p_dims.y, d = p_dims.z;
	const int plan = w * d;
	const int64_t n = int64_t(w) * h * d;
	PackedInt64Array mass, sx, sz;
	PackedInt32Array box;
	mass.resize(int64_t(p_count) * (h + 1));
	mass.fill(0);
	sx.resize(mass.size());
	sx.fill(0);
	sz.resize(mass.size());
	sz.fill(0);
	box.resize(int64_t(p_count) * h * 4);
	box.fill(-1);
	// The arrays go into `out` last: a packed array in a Variant is shared copy-on-write, so
	// writing through ptrw() after that would leave `out` holding the zeros.
	auto pack = [&]() {
		out["mass"] = mass;
		out["sx"] = sx;
		out["sz"] = sz;
		out["box"] = box;
		return out;
	};
	if (p_cells.size() != n || p_labels.size() != n || p_fixtures.size() < 256 || p_count <= 0) return pack();
	const int32_t *lab = p_labels.ptr();
	const uint8_t *cells = p_cells.ptr();
	const uint8_t *fix = p_fixtures.ptr();
	int64_t *ms = mass.ptrw();
	int64_t *xs = sx.ptrw();
	int64_t *zs = sz.ptrw();
	int32_t *bx = box.ptrw();
	for (int i = 0; i < n; i++) {
		const int k = lab[i] - 1;
		if (k < 0 || cells[i] == 0) continue;
		const int x = i % w, z = (i / w) % d, y = i / plan;
		const int64_t at = int64_t(k) * (h + 1) + y;
		ms[at] += 1;
		xs[at] += 2 * x + 1;
		zs[at] += 2 * z + 1;
		const uint8_t below = y > 0 ? cells[i - plan] : 0;
		if (below != 0 && fix[below] == 0 && fix[cells[i]] == 0) {
			int32_t *b = bx + (int64_t(k) * h + y) * 4;
			const bool fresh = b[2] < 0;
			b[0] = fresh ? x : std::min(b[0], x);
			b[1] = fresh ? z : std::min(b[1], z);
			b[2] = fresh ? x + 1 : std::max(b[2], x + 1);
			b[3] = fresh ? z + 1 : std::max(b[3], z + 1);
		}
	}
	for (int k = 0; k < p_count; k++)
		for (int y = h - 1; y >= 0; y--) {
			const int64_t at = int64_t(k) * (h + 1) + y;
			ms[at] += ms[at + 1];
			xs[at] += xs[at + 1];
			zs[at] += zs[at + 1];
		}
	return pack();
}
