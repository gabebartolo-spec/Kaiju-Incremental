#include "kaiju_carve.h"
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
#include <cmath>
#include <vector>

using namespace godot;

void KaijuCarve::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_grid", "grid", "dims"), &KaijuCarve::set_grid);
	ClassDB::bind_method(D_METHOD("get_grid"), &KaijuCarve::get_grid);
	ClassDB::bind_method(D_METHOD("carve_sphere", "centre", "radius"), &KaijuCarve::carve_sphere);
	ClassDB::bind_method(D_METHOD("ground_flood"), &KaijuCarve::ground_flood);
	ClassDB::bind_method(D_METHOD("region_boxes", "grid", "dims", "region", "bricks", "res", "sparse"),
			&KaijuCarve::region_boxes);
}

namespace {

// The cell box round the solid cells of the block at (lx, ly, lz), n cells a side, clamped to the
// grid: box[0..2] its lower cell, box[3..5] its size. Returns the solid count (0: no box).
int solid_span(const uint8_t *g, int w, int h, int d, int lx, int ly, int lz, int n, int *box) {
	int ax = w, ay = h, az = d, bx = -1, by = -1, bz = -1, count = 0;
	const int x1 = std::min(w, lx + n), y1 = std::min(h, ly + n), z1 = std::min(d, lz + n);
	for (int y = std::max(0, ly); y < y1; y++)
		for (int z = std::max(0, lz); z < z1; z++) {
			const uint8_t *row = g + size_t(z) * w + size_t(y) * w * d;
			for (int x = std::max(0, lx); x < x1; x++) {
				if (!row[x]) continue;
				ax = std::min(ax, x);
				ay = std::min(ay, y);
				az = std::min(az, z);
				bx = std::max(bx, x);
				by = std::max(by, y);
				bz = std::max(bz, z);
				count++;
			}
		}
	if (count == 0) return 0;
	box[0] = ax;
	box[1] = ay;
	box[2] = az;
	box[3] = bx - ax + 1;
	box[4] = by - ay + 1;
	box[5] = bz - az + 1;
	return count;
}

} // namespace

PackedInt32Array KaijuCarve::region_boxes(const PackedByteArray &p_grid, const Vector3i &p_dims,
		const Vector3i &p_region, int p_bricks, int p_res, double p_sparse) const {
	PackedInt32Array out;
	const int gw = p_dims.x, gh = p_dims.y, gd = p_dims.z;
	if (gw <= 0 || gh <= 0 || gd <= 0 || p_res <= 0 || p_bricks <= 0 ||
			int64_t(gw) * gh * gd != p_grid.size())
		return out;
	const uint8_t *g = p_grid.ptr();
	const int half = p_res >> 1;
	std::vector<int32_t> boxes;
	int box[6];
	for (int y = 0; y < p_bricks; y++)
		for (int z = 0; z < p_bricks; z++)
			for (int x = 0; x < p_bricks; x++) {
				const int lx = (p_region.x * p_bricks + x) * p_res;
				const int ly = (p_region.y * p_bricks + y) * p_res;
				const int lz = (p_region.z * p_bricks + z) * p_res;
				const int count = solid_span(g, gw, gh, gd, lx, ly, lz, p_res, box);
				if (count == 0) continue;
				const double volume = double(box[3]) * box[4] * box[5];
				if (double(count) / volume >= p_sparse || p_res < 2) {
					boxes.insert(boxes.end(), box, box + 6);
					continue;
				}
				for (int sy = 0; sy < 2; sy++)
					for (int sz = 0; sz < 2; sz++)
						for (int sx = 0; sx < 2; sx++)
							if (solid_span(g, gw, gh, gd, lx + sx * half, ly + sy * half, lz + sz * half,
										half, box))
								boxes.insert(boxes.end(), box, box + 6);
			}
	out.resize(int64_t(boxes.size()));
	if (!boxes.empty()) std::copy(boxes.begin(), boxes.end(), out.ptrw());
	return out;
}

bool KaijuCarve::set_grid(const PackedByteArray &p_grid, const Vector3i &p_dims) {
	if (p_dims.x <= 0 || p_dims.y <= 0 || p_dims.z <= 0 ||
			int64_t(p_dims.x) * p_dims.y * p_dims.z != p_grid.size()) {
		cells = PackedByteArray();
		w = h = d = 0;
		return false;
	}
	cells = p_grid;
	w = p_dims.x;
	h = p_dims.y;
	d = p_dims.z;
	return true;
}

PackedByteArray KaijuCarve::get_grid() const {
	return cells;
}

int KaijuCarve::carve_sphere(const Vector3 &p_centre, float p_radius) {
	if (cells.is_empty()) return 0;
	uint8_t *g = cells.ptrw();
	const float cx = p_centre.x, cy = p_centre.y, cz = p_centre.z;
	const float rr = p_radius * p_radius;
	const int x0 = std::max(0, int(std::floor(cx - p_radius)));
	const int x1 = std::min(w - 1, int(std::ceil(cx + p_radius)));
	const int y0 = std::max(0, int(std::floor(cy - p_radius)));
	const int y1 = std::min(h - 1, int(std::ceil(cy + p_radius)));
	const int z0 = std::max(0, int(std::floor(cz - p_radius)));
	const int z1 = std::min(d - 1, int(std::ceil(cz + p_radius)));
	int removed = 0;
	for (int y = y0; y <= y1; y++)
		for (int z = z0; z <= z1; z++)
			for (int x = x0; x <= x1; x++) {
				const size_t i = size_t(x) + size_t(z) * w + size_t(y) * w * d;
				if (!g[i]) continue;
				const float dx = x + 0.5f - cx, dy = y + 0.5f - cy, dz = z + 0.5f - cz;
				if (dx * dx + dy * dy + dz * dz <= rr) {
					g[i] = 0;
					removed++;
				}
			}
	return removed;
}

int KaijuCarve::ground_flood() {
	if (cells.is_empty()) return 0;
	uint8_t *g = cells.ptrw();
	const int plan = w * d;
	const size_t n = cells.size();
	std::vector<uint8_t> seen(n, 0);
	std::vector<int> stack;
	stack.reserve(n);
	for (int i = 0; i < plan; i++)
		if (g[i]) {
			seen[i] = 1;
			stack.push_back(i);
		}
	auto visit = [&](int j) {
		if (!seen[j] && g[j]) {
			seen[j] = 1;
			stack.push_back(j);
		}
	};
	while (!stack.empty()) {
		const int i = stack.back();
		stack.pop_back();
		const int x = i % w, z = (i / w) % d, y = i / plan;
		if (x > 0) visit(i - 1);
		if (x < w - 1) visit(i + 1);
		if (z > 0) visit(i - w);
		if (z < d - 1) visit(i + w);
		if (y > 0) visit(i - plan);
		if (y < h - 1) visit(i + plan);
	}
	int removed = 0;
	for (size_t i = 0; i < n; i++)
		if (g[i] && !seen[i]) {
			g[i] = 0;
			removed++;
		}
	return removed;
}
