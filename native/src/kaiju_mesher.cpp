#include "kaiju_mesher.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/hashfuncs.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <vector>

using namespace godot;

static const int REGION = 16;
// BuildingMesher.NEIGHBOURS: LEFT, RIGHT, UP, DOWN, FORWARD (-z), BACK (+z).
static const int DIRS[6][3] = { { -1, 0, 0 }, { 1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, -1 }, { 0, 0, 1 } };

void KaijuMesher::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "dims", "offset", "origin", "voxel", "salt", "noise", "looks", "palette"),
			&KaijuMesher::setup);
	ClassDB::bind_method(D_METHOD("mesh_region", "cells", "region"), &KaijuMesher::mesh_region);
}

bool KaijuMesher::setup(const Vector3i &p_dims, const Vector3i &p_offset, const Vector3 &p_origin, float p_voxel,
		int64_t p_salt, double p_noise, const PackedByteArray &p_looks, const PackedColorArray &p_palette) {
	ready = false;
	if (p_dims.x <= 0 || p_dims.y <= 0 || p_dims.z <= 0 ||
			int64_t(p_dims.x) * p_dims.y * p_dims.z != p_looks.size() || p_palette.size() != 256) {
		return false;
	}
	dims = p_dims;
	offset = p_offset;
	origin = p_origin;
	voxel = p_voxel;
	salt = p_salt;
	noise = p_noise;
	looks = p_looks;
	palette = p_palette;
	// The oracle's corners: c = nf*half, u = a x nf * half, v = nf x u.normalized() * half.
	const float half = voxel * 0.5f;
	for (int k = 0; k < 6; k++) {
		const Vector3 nf(DIRS[k][0], DIRS[k][1], DIRS[k][2]);
		const Vector3 a = DIRS[k][1] == 0 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
		const Vector3 u = a.cross(nf) * half;
		const Vector3 v = nf.cross(u.normalized()) * half;
		const Vector3 c = nf * half;
		corners[k][0] = c - u - v;
		corners[k][1] = c + u - v;
		corners[k][2] = c + u + v;
		corners[k][3] = c - u + v;
	}
	ready = true;
	return true;
}

// Godot's Variant hash of a Vector4i (GDScript hash()).
static inline uint32_t hash_vector4i(int32_t x, int32_t y, int32_t z, int32_t w) {
	uint32_t h = hash_murmur3_one_32(uint32_t(x));
	h = hash_murmur3_one_32(uint32_t(y), h);
	h = hash_murmur3_one_32(uint32_t(z), h);
	h = hash_murmur3_one_32(uint32_t(w), h);
	return hash_fmix32(h);
}

// The four arrays, in the order the GDScript path returns them.
static Array pack(const std::vector<Vector3> &verts, const std::vector<Vector3> &normals,
		const std::vector<Color> &colors, const std::vector<int32_t> &index) {
	PackedVector3Array pv, pn;
	PackedColorArray pc;
	PackedInt32Array pi;
	pv.resize(int64_t(verts.size()));
	pn.resize(int64_t(normals.size()));
	pc.resize(int64_t(colors.size()));
	pi.resize(int64_t(index.size()));
	if (!verts.empty()) {
		memcpy(pv.ptrw(), verts.data(), verts.size() * sizeof(Vector3));
		memcpy(pn.ptrw(), normals.data(), normals.size() * sizeof(Vector3));
		memcpy(pc.ptrw(), colors.data(), colors.size() * sizeof(Color));
		memcpy(pi.ptrw(), index.data(), index.size() * sizeof(int32_t));
	}
	Array out;
	out.append(pv);
	out.append(pn);
	out.append(pc);
	out.append(pi);
	return out;
}

Array KaijuMesher::mesh_region(const PackedByteArray &p_cells, const Vector3i &p_region) const {
	std::vector<Vector3> verts;
	std::vector<Vector3> normals;
	std::vector<Color> colors;
	std::vector<int32_t> index;
	if (!ready || p_cells.size() != looks.size()) {
		return pack(verts, normals, colors, index);
	}
	verts.reserve(4096);
	normals.reserve(4096);
	colors.reserve(4096);
	index.reserve(6144);
	const uint8_t *g = p_cells.ptr();
	const uint8_t *lk = looks.ptr();
	const Color *pal = palette.ptr();
	const int w = dims.x, h = dims.y, d = dims.z;
	const int64_t plan = int64_t(w) * d;
	const int x0 = p_region.x * REGION, y0 = p_region.y * REGION, z0 = p_region.z * REGION;
	const int x1 = std::min(w, x0 + REGION), y1 = std::min(h, y0 + REGION), z1 = std::min(d, z0 + REGION);
	auto open = [&](int x, int y, int z) -> bool {
		if (y + offset.y < 0) return false;
		if (x < 0 || y < 0 || z < 0 || x >= w || y >= h || z >= d) return true;
		return g[x + z * int64_t(w) + y * plan] == 0;
	};
	for (int y = y0; y < y1; y++)
		for (int z = z0; z < z1; z++)
			for (int x = x0; x < x1; x++) {
				const int64_t i = x + z * int64_t(w) + y * plan;
				if (!g[i]) continue;
				const Vector3 centre = origin + Vector3(float(x), float(y), float(z)) * voxel;
				Color color;
				bool coloured = false;
				for (int k = 0; k < 6; k++) {
					if (!open(x + DIRS[k][0], y + DIRS[k][1], z + DIRS[k][2])) continue;
					if (!coloured) {
						// Look.jitter: t in [-1, 1) from the cell's hash, brightness * (1 + t * noise).
						const Color base = pal[lk[i]];
						color = base;
						if (noise > 0.0) {
							const uint32_t hv = hash_vector4i(x + offset.x, y + offset.y, z + offset.z, int32_t(salt));
							const double t = double(int64_t(hv) % 1000) / 1000.0 * 2.0 - 1.0;
							color = Color(float(double(base.r) * (1.0 + t * noise)), float(double(base.g) * (1.0 + t * noise)),
									float(double(base.b) * (1.0 + t * noise)), base.a);
						}
						coloured = true;
					}
					const int at = int(verts.size());
					const Vector3 nf(DIRS[k][0], DIRS[k][1], DIRS[k][2]);
					for (int q = 0; q < 4; q++) {
						verts.push_back(centre + corners[k][q]);
						normals.push_back(nf);
						colors.push_back(color);
					}
					index.push_back(at);
					index.push_back(at + 2);
					index.push_back(at + 1);
					index.push_back(at);
					index.push_back(at + 3);
					index.push_back(at + 2);
				}
			}
	return pack(verts, normals, colors, index);
}
