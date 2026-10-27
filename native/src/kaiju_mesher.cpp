#include "kaiju_mesher.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/hashfuncs.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <vector>

using namespace godot;

static const int REGION = 16;
// BuildingMesher.NEIGHBOURS: LEFT, RIGHT, UP, DOWN, FORWARD (-z), BACK (+z).
static const int DIRS[6][3] = { { -1, 0, 0 }, { 1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, -1 }, { 0, 0, 1 } };
// VoxelAO (scenes/voxel_ao.gd): per corner (c-u-v, c+u-v, c+u+v, c-u+v) its ring bits [side,
// side, corner]; the AO by level; the two quad splits; the flip bit.
static const int CORNER_BITS[4][3] = { { 0, 2, 4 }, { 1, 2, 5 }, { 1, 3, 6 }, { 0, 3, 7 } };
static const float LEVEL_VALUE[4] = { 0.0f, float(1.0 / 3.0), float(2.0 / 3.0), 1.0f };
static const int SPLIT_02[6] = { 0, 2, 1, 0, 3, 2 };
static const int SPLIT_13[6] = { 0, 3, 1, 1, 3, 2 };
static const int FLIP = 256;

// VoxelAO.level: both sides closed = 0, else 3 - sides - corner.
static inline int ao_level(bool side1, bool side2, bool corner) {
	if (side1 && side2) return 0;
	return 3 - int(side1) - int(side2) - int(corner);
}

static inline int sign_of(real_t x) {
	return x > 0 ? 1 : (x < 0 ? -1 : 0);
}

void KaijuMesher::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "dims", "offset", "origin", "voxel", "salt", "noise", "looks", "palette"),
			&KaijuMesher::setup);
	ClassDB::bind_method(D_METHOD("set_finish", "finish"), &KaijuMesher::set_finish);
	ClassDB::bind_method(D_METHOD("mesh_region", "cells", "region"), &KaijuMesher::mesh_region);
}

bool KaijuMesher::set_finish(const PackedByteArray &p_finish) {
	if (p_finish.size() != 256) {
		return false;
	}
	finish = p_finish;
	return true;
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
		// VoxelAO.ring_of: U, V = the signs of u and v; bits -U, +U, -V, +V, -U-V, +U-V, +U+V, -U+V.
		const Vector3i U(sign_of(u.x), sign_of(u.y), sign_of(u.z));
		const Vector3i V(sign_of(v.x), sign_of(v.y), sign_of(v.z));
		const Vector3i steps[8] = { -U, U, -V, V, -U - V, U - V, U + V, -U + V };
		for (int s = 0; s < 8; s++) {
			ring[k][s] = steps[s];
		}
	}
	for (int bits = 0; bits < 256; bits++) {
		int lv[4];
		for (int q = 0; q < 4; q++) {
			lv[q] = ao_level(bits & (1 << CORNER_BITS[q][0]), bits & (1 << CORNER_BITS[q][1]),
					bits & (1 << CORNER_BITS[q][2]));
		}
		const int packed = lv[0] | (lv[1] << 2) | (lv[2] << 4) | (lv[3] << 6);
		ao_table[bits] = uint16_t(packed | (lv[1] + lv[3] > lv[0] + lv[2] ? FLIP : 0));
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

// A region's arrays while it is meshed.
struct RegionArrays {
	std::vector<Vector3> verts;
	std::vector<Vector3> normals;
	std::vector<Color> colors;
	std::vector<int32_t> index;
	std::vector<Vector2> uv;
};

template <typename P, typename T>
static P packed(const std::vector<T> &src) {
	P out;
	out.resize(int64_t(src.size()));
	if (!src.empty()) {
		memcpy(out.ptrw(), src.data(), src.size() * sizeof(T));
	}
	return out;
}

// The five arrays, in the order the GDScript path returns them.
static Array pack(const RegionArrays &a) {
	Array out;
	out.append(packed<PackedVector3Array>(a.verts));
	out.append(packed<PackedVector3Array>(a.normals));
	out.append(packed<PackedColorArray>(a.colors));
	out.append(packed<PackedInt32Array>(a.index));
	out.append(packed<PackedVector2Array>(a.uv));
	return out;
}

Array KaijuMesher::mesh_region(const PackedByteArray &p_cells, const Vector3i &p_region) const {
	RegionArrays out;
	if (!ready || p_cells.size() != looks.size()) {
		return pack(out);
	}
	std::vector<Vector3> &verts = out.verts;
	std::vector<Vector3> &normals = out.normals;
	std::vector<Color> &colors = out.colors;
	std::vector<int32_t> &index = out.index;
	std::vector<Vector2> &uv = out.uv;
	verts.reserve(4096);
	normals.reserve(4096);
	colors.reserve(4096);
	index.reserve(6144);
	uv.reserve(4096);
	const uint8_t *g = p_cells.ptr();
	const uint8_t *lk = looks.ptr();
	const Color *pal = palette.ptr();
	const uint8_t *fin = finish.size() == 256 ? finish.ptr() : nullptr;
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
				const float finish_class = fin ? float(fin[lk[i]]) : 0.0f;
				Color color;
				bool coloured = false;
				for (int k = 0; k < 6; k++) {
					const int ax = x + DIRS[k][0], ay = y + DIRS[k][1], az = z + DIRS[k][2];
					if (!open(ax, ay, az)) continue;
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
					int bits = 0;
					for (int s = 0; s < 8; s++) {
						const Vector3i &st = ring[k][s];
						if (!open(ax + st.x, ay + st.y, az + st.z)) bits |= 1 << s;
					}
					const int ao = ao_table[bits];
					const int at = int(verts.size());
					const Vector3 nf(DIRS[k][0], DIRS[k][1], DIRS[k][2]);
					for (int q = 0; q < 4; q++) {
						verts.push_back(centre + corners[k][q]);
						normals.push_back(nf);
						colors.push_back(color);
						uv.push_back(Vector2(LEVEL_VALUE[(ao >> (q * 2)) & 3], finish_class));
					}
					const int *split = (ao & FLIP) ? SPLIT_13 : SPLIT_02;
					for (int s = 0; s < 6; s++) {
						index.push_back(at + split[s]);
					}
				}
			}
	return pack(out);
}
