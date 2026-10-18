// SPIKE (throwaway). Same algorithm as carve_grid.gd + CarveView._remesh, in plain C++, to
// measure what a GDExtension would cost: carve a sphere, flood from the ground, split islands,
// count the faces of every dirty 16^3 region (the mesher's vertex work). Same paths and layout
// as carve_spike.gd. Build: cl /O2 /EHsc /std:c++17 native_bench.cpp
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <set>
#include <vector>

struct V3 { float x, y, z; };
static float lerp(float a, float b, float t) { return a + (b - a) * t; }

static V3 path(V3 c, float t) {
	if (t < 3.0f) return {c.x + lerp(-6, 6, t / 3.0f), 9.0f, c.z};
	if (t < 5.5f) return {c.x + lerp(6, -6, (t - 3.0f) / 2.5f), 1.6f, c.z - 1.6f};
	if (t < 8.0f) return {c.x + lerp(-6, 6, (t - 5.5f) / 2.5f), 1.6f, c.z + 1.6f};
	return {c.x + 6 + (t - 8) * 4, 1.6f + (t - 8) * 6, c.z + 1.6f};
}

struct Grid {
	int res, w, d, h;
	V3 origin;
	std::vector<uint8_t> cells;
	Grid(int r, int ux, int uy, int uz, V3 o) : res(r), w(ux * r), d(uz * r), h(uy * r), origin(o) {
		cells.assign(size_t(w) * d * h, 0);
		for (int y = 0; y < h; y++)
			for (int z = 0; z < d; z++)
				for (int x = 0; x < w; x++) {
					bool edge = x == 0 || z == 0 || x == w - 1 || z == d - 1;
					uint8_t m = 0;
					if (y % res == 0) m = 2;
					else if (edge) m = ((y % res >= 2) && ((x + z) % res) != 0 && y >= res) ? 3 : 1;
					else if (x % (2 * res) == res && z % (2 * res) == res) m = 4;
					cells[x + z * w + size_t(y) * w * d] = m;
				}
	}
	int idx(int x, int y, int z) const { return x + z * w + y * w * d; }

	// returns removed count; fills islands; dirty regions
	int carve(V3 c, float r, std::vector<std::vector<int>>& islands, std::set<int>& dirty,
	          double& flood_ms) {
		std::vector<int> removed;
		float cx = (c.x - origin.x) * res, cy = (c.y - origin.y) * res, cz = (c.z - origin.z) * res;
		float rr = r * res;
		int x0 = std::max(0, int(std::floor(cx - rr))), x1 = std::min(w - 1, int(std::ceil(cx + rr)));
		int y0 = std::max(0, int(std::floor(cy - rr))), y1 = std::min(h - 1, int(std::ceil(cy + rr)));
		int z0 = std::max(0, int(std::floor(cz - rr))), z1 = std::min(d - 1, int(std::ceil(cz + rr)));
		for (int y = y0; y <= y1; y++)
			for (int z = z0; z <= z1; z++)
				for (int x = x0; x <= x1; x++) {
					int i = idx(x, y, z);
					if (!cells[i]) continue;
					float dx = x + 0.5f - cx, dy = y + 0.5f - cy, dz = z + 0.5f - cz;
					if (dx * dx + dy * dy + dz * dz <= rr * rr) { cells[i] = 0; removed.push_back(i); }
				}
		if (removed.empty()) return 0;
		auto t0 = std::chrono::high_resolution_clock::now();
		int plan = w * d;
		std::vector<uint8_t> seen(cells.size(), 0);
		std::vector<int> stack;
		stack.reserve(cells.size());
		for (int i = 0; i < plan; i++) if (cells[i]) { seen[i] = 1; stack.push_back(i); }
		auto visit = [&](int n) { if (!seen[n] && cells[n]) { seen[n] = 1; stack.push_back(n); } };
		while (!stack.empty()) {
			int i = stack.back(); stack.pop_back();
			int x = i % w, z = (i / w) % d, y = i / plan;
			if (x > 0) visit(i - 1);
			if (x < w - 1) visit(i + 1);
			if (z > 0) visit(i - w);
			if (z < d - 1) visit(i + w);
			if (y > 0) visit(i - plan);
			if (y < h - 1) visit(i + plan);
		}
		for (int s = 0; s < int(cells.size()); s++) {
			if (!cells[s] || seen[s]) continue;
			std::vector<int> part{s};
			seen[s] = 1;
			for (size_t k = 0; k < part.size(); k++) {
				int i = part[k];
				int x = i % w, z = (i / w) % d, y = i / plan;
				auto add = [&](int n) { if (!seen[n] && cells[n]) { seen[n] = 1; part.push_back(n); } };
				if (x > 0) add(i - 1);
				if (x < w - 1) add(i + 1);
				if (z > 0) add(i - w);
				if (z < d - 1) add(i + w);
				if (y > 0) add(i - plan);
				if (y < h - 1) add(i + plan);
			}
			islands.push_back(part);
		}
		for (auto& p : islands) for (int i : p) { cells[i] = 0; removed.push_back(i); }
		flood_ms = std::chrono::duration<double, std::milli>(std::chrono::high_resolution_clock::now() - t0).count();
		int rw = (w + 15) / 16, rd = (d + 15) / 16;
		for (int i : removed) {
			int x = i % w, z = (i / w) % d, y = i / plan;
			dirty.insert(x / 16 + (z / 16) * rw + (y / 16) * rw * rd);
		}
		return int(removed.size());
	}

	// the mesher's work for one region: visible faces -> 4 verts each written to a buffer
	size_t mesh_region(int key, std::vector<float>& verts) const {
		int rw = (w + 15) / 16, rd = (d + 15) / 16;
		int rx = key % rw, rz = (key / rw) % rd, ry = key / (rw * rd);
		size_t faces = 0;
		for (int y = ry * 16; y < std::min(h, ry * 16 + 16); y++)
			for (int z = rz * 16; z < std::min(d, rz * 16 + 16); z++)
				for (int x = rx * 16; x < std::min(w, rx * 16 + 16); x++) {
					if (!cells[idx(x, y, z)]) continue;
					const int nb[6][3] = {{-1,0,0},{1,0,0},{0,-1,0},{0,1,0},{0,0,-1},{0,0,1}};
					for (auto& n : nb) {
						int qx = x + n[0], qy = y + n[1], qz = z + n[2];
						bool solid = qx >= 0 && qy >= 0 && qz >= 0 && qx < w && qy < h && qz < d && cells[idx(qx, qy, qz)];
						if (solid) continue;
						faces++;
						for (int v = 0; v < 4; v++) { verts.push_back(float(x)); verts.push_back(float(y)); verts.push_back(float(z)); }
					}
				}
		return faces;
	}
};

int main(int argc, char** argv) {
	int res = argc > 1 ? atoi(argv[1]) : 8;
	bool block = argc > 2;
	std::vector<V3> centres;
	if (block) for (int row = 0; row < 2; row++) for (int col = 0; col < 3; col++) centres.push_back({(col - 1) * 9.0f, 0, (row - 0.5f) * 10.0f});
	else centres.push_back({0, 0, 0});
	std::vector<Grid> grids;
	for (size_t n = 0; n < centres.size(); n++) {
		int hy = block ? 12 + (int(n) * 5) % 9 : 16;
		grids.emplace_back(res, 6, hy, 6, V3{centres[n].x - 3, 0, centres[n].z - 3});
	}
	std::vector<double> tick_ms, flood_all, mesh_all;
	size_t island_cells = 0, max_faces = 0;
	for (int tick = 1; tick <= 300; tick++) {
		auto t0 = std::chrono::high_resolution_clock::now();
		double flood = 0, mesh = 0;
		for (size_t n = 0; n < grids.size(); n++) {
			float t = tick / 30.0f - n * 0.25f;
			if (t < 0) continue;
			std::vector<std::vector<int>> islands;
			std::set<int> dirty;
			double f = 0;
			grids[n].carve(path(centres[n], t), 2.4f, islands, dirty, f);
			flood += f;
			auto m0 = std::chrono::high_resolution_clock::now();
			std::vector<float> verts;
			size_t faces = 0;
			for (int key : dirty) faces += grids[n].mesh_region(key, verts);
			max_faces = std::max(max_faces, faces);
			mesh += std::chrono::duration<double, std::milli>(std::chrono::high_resolution_clock::now() - m0).count();
			for (auto& p : islands) island_cells += p.size();
		}
		tick_ms.push_back(std::chrono::duration<double, std::milli>(std::chrono::high_resolution_clock::now() - t0).count());
		flood_all.push_back(flood);
		mesh_all.push_back(mesh);
	}
	auto rep = [](const char* k, std::vector<double> a) {
		double s = 0; for (double x : a) s += x;
		std::sort(a.begin(), a.end());
		printf("  %-6s avg %7.3f  p95 %7.3f  max %7.3f ms\n", k, s / a.size(), a[size_t(a.size() * 0.95)], a.back());
	};
	printf("NATIVE res=%d block=%d buildings=%zu island_cells=%zu max_faces_tick=%zu\n", res, int(block), grids.size(), island_cells, max_faces);
	rep("tick", tick_ms);
	rep("flood", flood_all);
	rep("mesh", mesh_all);
	return 0;
}
