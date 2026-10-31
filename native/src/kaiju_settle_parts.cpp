// KaijuSettle's per-cell helpers (b2-3 part 3): the GDScript loops around a settle and a blow
// that cost a heavy swipe most of its step. Each is the GDScript it replaces line for line (same
// scan order, same float steps), which stays the reference; tests/lib/settle_replay.gd and
// tests/run_carving_tests.gd (_check_replay) hold them to it. Packed arrays are filled through ptrw() before they
// go into a returned Array (a packed array in a Variant is shared copy-on-write).
#include "kaiju_settle.h"
#include <godot_cpp/variant/vector3i.hpp>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

using namespace godot;

namespace {

// VoxelFrame.column_top: the highest non-empty cell in column (gx, gz) below below_gy, or -1.
inline int column_top(const uint8_t *cells, int w, int d, int h, int gx, int gz, int below_gy) {
	if (gx < 0 || gz < 0 || gx >= w || gz >= d) return -1;
	const int plan = w * d;
	for (int y = std::min(below_gy, h) - 1; y >= 0; y--)
		if (cells[gx + gz * w + y * plan] != 0) return y;
	return -1;
}

// Carving._span: grid range [lo, hi) along one axis of chunk c (of count).
inline void span(int c, int count, int offset, int size, int res, int &lo, int &hi) {
	lo = c == 0 ? 0 : c * res - offset;
	hi = c == count - 1 ? size : (c + 1) * res - offset;
	lo = std::clamp(lo, 0, size);
	hi = std::clamp(hi, 0, size);
}

// Carving.Grid.chunk.
inline int chunk_of(int i, int w, int d, int bw, int bd, const int32_t *cx, const int32_t *cz,
		const int32_t *fy) {
	return cx[i % w] + cz[(i / w) % d] * bw + fy[i / (w * d)] * bw * bd;
}

} // namespace

PackedInt32Array KaijuSettle::gather(const PackedInt32Array &p_labels, const PackedByteArray &p_cells,
		int p_from, int p_label) const {
	PackedInt32Array out;
	const int64_t n = p_cells.size();
	if (p_labels.size() != n || p_from < 0) return out;
	const int32_t *lab = p_labels.ptr();
	const uint8_t *cells = p_cells.ptr();
	int64_t count = 0;
	for (int64_t i = p_from; i < n; i++)
		count += lab[i] == p_label && cells[i] != 0;
	out.resize(count);
	int32_t *o = out.ptrw();
	int64_t k = 0;
	for (int64_t i = p_from; i < n; i++)
		if (lab[i] == p_label && cells[i] != 0) o[k++] = int32_t(i);
	return out;
}

Array KaijuSettle::take(const PackedByteArray &p_cells, const Array &p_parts, const Vector3i &p_dims,
		const Vector3i &p_offset) const {
	const int w = p_dims.x, d = p_dims.z;
	const int plan = w * d;
	PackedByteArray cells = p_cells;
	uint8_t *c = cells.ptrw();
	Array mats;
	Array lists;
	for (int64_t p = 0; p < p_parts.size(); p++) {
		const PackedInt32Array part = p_parts[p];
		const int32_t *idx = part.ptr();
		PackedByteArray m;
		m.resize(part.size());
		uint8_t *mo = m.ptrw();
		Array list;
		list.resize(part.size());
		for (int64_t k = 0; k < part.size(); k++) {
			const int i = idx[k];
			mo[k] = c[i];
			c[i] = 0;
			list[k] = Vector3i(i % w, i / plan, (i / w) % d) + p_offset;
		}
		mats.push_back(m);
		lists.push_back(list);
	}
	Array out;
	out.push_back(cells);
	out.push_back(mats);
	out.push_back(lists);
	return out;
}

PackedInt64Array KaijuSettle::land(const PackedInt32Array &p_part, const PackedByteArray &p_cells,
		const Vector3i &p_dims) const {
	const int w = p_dims.x, h = p_dims.y, d = p_dims.z;
	const int plan = w * d;
	PackedInt64Array out;
	out.resize(9);
	out.fill(0);
	if (p_cells.size() != int64_t(plan) * h) return out;
	const int32_t *idx = p_part.ptr();
	const uint8_t *cells = p_cells.ptr();
	// The lowest cell of the part per column (h = none).
	std::vector<int> low(size_t(plan), h);
	int64_t sx = 0, sz = 0;
	for (int64_t k = 0; k < p_part.size(); k++) {
		const int i = idx[k];
		const int col = i % plan;
		low[col] = std::min(low[col], i / plan);
		sx += 2 * (col % w) + 1;
		sz += 2 * (col / w) + 1;
	}
	int least = h;
	std::vector<int> gap(size_t(plan), 0);
	for (int col = 0; col < plan; col++) {
		if (low[col] >= h) continue;
		gap[col] = low[col] - column_top(cells, w, d, h, col % w, col / w, low[col]) - 1;
		least = std::min(least, gap[col]);
	}
	int x0 = 0, z0 = 0, x1 = 0, z1 = 0;
	bool any = false;
	int lands = h;
	for (int col = 0; col < plan; col++) {
		if (low[col] >= h || gap[col] != least) continue;
		const int x = col % w, z = col / w;
		if (!any) {
			x0 = x, z0 = z, x1 = x + 1, z1 = z + 1;
			any = true;
		} else {
			x0 = std::min(x0, x), z0 = std::min(z0, z);
			x1 = std::max(x1, x + 1), z1 = std::max(z1, z + 1);
		}
		lands = std::min(lands, low[col] - least);
	}
	int64_t *o = out.ptrw();
	o[0] = sx;
	o[1] = sz;
	o[2] = p_part.size();
	o[3] = x0;
	o[4] = z0;
	o[5] = x1;
	o[6] = z1;
	o[7] = lands;
	o[8] = least;
	return out;
}

PackedInt32Array KaijuSettle::chunk_counts(const PackedByteArray &p_cells, const PackedInt32Array &p_cx,
		const PackedInt32Array &p_cz, const PackedInt32Array &p_fy, const PackedInt32Array &p_geo,
		int p_chunks) const {
	PackedInt32Array out;
	out.resize(std::max(0, p_chunks));
	out.fill(0);
	if (p_geo.size() < 5) return out;
	const int w = p_geo[0], d = p_geo[1], h = p_geo[2], bw = p_geo[3], bd = p_geo[4];
	if (p_cells.size() != int64_t(w) * d * h || p_cx.size() < w || p_cz.size() < d || p_fy.size() < h)
		return out;
	const uint8_t *cells = p_cells.ptr();
	const int32_t *cx = p_cx.ptr(), *cz = p_cz.ptr(), *fy = p_fy.ptr();
	int32_t *o = out.ptrw();
	for (int64_t i = 0; i < p_cells.size(); i++) {
		if (cells[i] == 0) continue;
		const int ci = chunk_of(int(i), w, d, bw, bd, cx, cz, fy);
		if (ci >= 0 && ci < p_chunks) o[ci] += 1;
	}
	return out;
}

Array KaijuSettle::part_info(const PackedInt32Array &p_index, const PackedByteArray &p_cells,
		const PackedInt32Array &p_cx, const PackedInt32Array &p_cz, const PackedInt32Array &p_fy,
		const PackedInt32Array &p_geo, const PackedInt32Array &p_live) const {
	Array out;
	const int w = p_geo[0], d = p_geo[1], h = p_geo[2], bw = p_geo[3], bd = p_geo[4];
	const int plan = w * d;
	PackedInt32Array live = p_live;
	PackedInt32Array info;
	info.resize(11);
	int32_t *lv = live.ptrw();
	int32_t *o = info.ptrw();
	const int32_t *idx = p_index.ptr();
	const int32_t *cx = p_cx.ptr(), *cz = p_cz.ptr(), *fy = p_fy.ptr();
	const uint8_t *cells = p_cells.ptr();
	int lo[3] = { w, h, d }, hi[3] = { -1, -1, -1 };
	for (int64_t k = 0; k < p_index.size(); k++) {
		const int i = idx[k];
		lv[chunk_of(i, w, d, bw, bd, cx, cz, fy)] -= 1;
		const int c[3] = { i % w, i / plan, (i / w) % d };
		for (int a = 0; a < 3; a++) {
			lo[a] = std::min(lo[a], c[a]);
			hi[a] = std::max(hi[a], c[a]);
		}
	}
	// The footprint of its lowest layer (Rect2i(-1, -1, 0, 0) when none), and whether anything
	// stands under it.
	int x0 = -1, z0 = -1, x1 = -1, z1 = -1;
	bool under = false;
	for (int64_t k = 0; k < p_index.size(); k++) {
		const int i = idx[k];
		if (i / plan != lo[1]) continue;
		const int x = i % w, z = (i / w) % d;
		if (x0 < 0) {
			x0 = x, z0 = z, x1 = x + 1, z1 = z + 1;
		} else {
			x0 = std::min(x0, x), z0 = std::min(z0, z);
			x1 = std::max(x1, x + 1), z1 = std::max(z1, z + 1);
		}
		under = under || column_top(cells, w, d, h, x, z, lo[1]) >= 0;
	}
	for (int a = 0; a < 3; a++) {
		o[a] = lo[a];
		o[3 + a] = hi[a];
	}
	o[6] = x0;
	o[7] = z0;
	o[8] = x1;
	o[9] = z1;
	o[10] = under ? 1 : 0;
	out.push_back(live);
	out.push_back(info);
	return out;
}

Array KaijuSettle::wear(const PackedByteArray &p_cells, const PackedFloat32Array &p_wear,
		const PackedFloat32Array &p_at, const PackedFloat32Array &p_amounts, const PackedInt32Array &p_spans,
		const PackedFloat32Array &p_strength, const PackedFloat64Array &p_nums,
		const PackedInt32Array &p_ints, const PackedInt32Array &p_cx, const PackedInt32Array &p_cz,
		const PackedInt32Array &p_fy, const PackedInt32Array &p_live) const {
	const int w = p_ints[0], d = p_ints[1], h = p_ints[2], bw = p_ints[3], bd = p_ints[4];
	const int floors = p_ints[5], offset_y = p_ints[6], res = p_ints[7];
	const double damage = p_nums[0], mult = p_nums[1], hp = p_nums[2], weakest = p_nums[3];
	const int plan = w * d;
	PackedByteArray cells = p_cells;
	PackedFloat32Array worn = p_wear;
	PackedInt32Array live = p_live;
	std::vector<int32_t> removed;
	std::vector<uint8_t> mats;
	uint8_t *c = cells.ptrw();
	float *wr = worn.ptrw();
	int32_t *lv = live.ptrw();
	const float *at = p_at.ptr();
	const float *amounts = p_amounts.ptr();
	const bool even = p_at.size() == 0;
	if (even && p_amounts.size() * 5 < p_spans.size()) return Array();
	const float *strength = p_strength.ptr();
	const int32_t *sp = p_spans.ptr();
	const int32_t *cx = p_cx.ptr(), *cz = p_cz.ptr(), *fy = p_fy.ptr();
	for (int64_t s = 0; s + 4 < p_spans.size(); s += 5) {
		const int floor_y = sp[s + 4];
		int row0, row1;
		span(floor_y, floors, offset_y, h, res, row0, row1);
		for (int gz = sp[s + 2]; gz < sp[s + 3]; gz++)
			for (int gx = sp[s]; gx < sp[s + 1]; gx++) {
				const int col = gx + gz * w;
				if (!even && !(double(at[col]) > 0.0)) continue;
				// Carving.wear_column, its float steps as GDScript takes them (a float32 store,
				// doubles in between).
				const double amount = even ? double(amounts[s / 5]) * mult : damage * double(at[col]) * mult;
				const int64_t wi = col + int64_t(floor_y) * plan;
				wr[wi] = float(double(wr[wi]) + amount);
				const double level = double(wr[wi]) / hp;
				if (level < weakest) continue;
				for (int gy = row0; gy < row1; gy++) {
					const int i = col + gy * plan;
					const uint8_t m = c[i];
					if (m != 0 && level >= double(strength[m])) {
						c[i] = 0;
						removed.push_back(i);
						mats.push_back(m);
						lv[chunk_of(i, w, d, bw, bd, cx, cz, fy)] -= 1;
					}
				}
			}
	}
	PackedInt32Array rem;
	rem.resize(int64_t(removed.size()));
	std::copy(removed.begin(), removed.end(), rem.ptrw());
	PackedByteArray mt;
	mt.resize(int64_t(mats.size()));
	std::copy(mats.begin(), mats.end(), mt.ptrw());
	Array out;
	out.push_back(cells);
	out.push_back(worn);
	out.push_back(live);
	out.push_back(rem);
	out.push_back(mt);
	return out;
}

PackedFloat32Array KaijuSettle::beam_at(const PackedInt32Array &p_spans, const PackedInt32Array &p_ints,
		const PackedFloat64Array &p_nums) const {
	const int w = p_ints[0], d = p_ints[1], off_x = p_ints[2], off_z = p_ints[3], res = p_ints[4];
	const double x0 = p_nums[0], z0 = p_nums[1], length = p_nums[6], half = p_nums[7];
	// The Vector2s are float32 in GDScript; their products and sums stay float32 (Vector2.dot).
	const float ox = float(p_nums[2]), oy = float(p_nums[3]), dx = float(p_nums[4]), dy = float(p_nums[5]);
	const double r = 0.5 / res;
	PackedFloat32Array at;
	at.resize(int64_t(w) * d);
	float *a = at.ptrw();
	std::fill(a, a + int64_t(w) * d, -1.0f);
	const int32_t *sp = p_spans.ptr();
	for (int64_t s = 0; s + 4 < p_spans.size(); s += 5)
		for (int gz = sp[s + 2]; gz < sp[s + 3]; gz++)
			for (int gx = sp[s]; gx < sp[s + 1]; gx++) {
				const int col = gx + gz * w;
				if (a[col] >= 0.0f) continue;
				// Vector3(gx + offset + 0.5, ...) / res, then local_to_world: float32 stores, doubles between.
				const float lx = float(double(gx + off_x) + 0.5) / float(res);
				const float lz = float(double(gz + off_z) + 0.5) / float(res);
				const float px = float(x0 + double(lx)), pz = float(z0 + double(lz));
				const float rx = px - ox, rz = pz - oy;
				const float t = rx * dx + rz * dy;
				const float side = std::fabs(rx * -dy + rz * dx);
				a[col] = (double(t) >= -r && double(t) <= length + r && double(side) <= half + r) ? 1.0f : 0.0f;
			}
	return at;
}
