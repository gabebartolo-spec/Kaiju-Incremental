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
