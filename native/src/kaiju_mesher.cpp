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
	ClassDB::bind_method(D_METHOD("pack_surface", "arrays"), &KaijuMesher::pack_surface);
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

// Per DIRS direction: (normal axis, u axis, v axis) of its plane (CellMesher.AXES).
static const int AXES[6][3] = { { 0, 1, 2 }, { 0, 1, 2 }, { 1, 0, 2 }, { 1, 0, 2 }, { 2, 0, 1 }, { 2, 0, 1 } };

static inline int plane_at(int k, int d, int u, int v) {
	return ((k * REGION + d) * REGION + v) * REGION + u;
}

// CellMesher.mesh_region_gd, byte for byte: flat-lit faces (all four AO corners alike) are merged per
// plane into larger quads of one look; the rest are drawn one per cell side. Colours are the look's
// palette colour (building_baked.gdshader jitters per voxel).
Array KaijuMesher::mesh_region(const PackedByteArray &p_cells, const Vector3i &p_region) const {
	RegionArrays out;
	if (!ready || p_cells.size() != looks.size()) {
		return pack(out);
	}
	out.verts.reserve(2048);
	out.normals.reserve(2048);
	out.colors.reserve(2048);
	out.index.reserve(3072);
	out.uv.reserve(2048);
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
	// One face of direction k centred on `centre`, spanning `span` cells (CellMesher._face).
	auto face = [&](const Vector3 &centre, int k, int look, int ao, const Vector3 &span) {
		const int at = int(out.verts.size());
		const Vector3 nf(DIRS[k][0], DIRS[k][1], DIRS[k][2]);
		const float finish_class = fin ? float(fin[look]) : 0.0f;
		for (int q = 0; q < 4; q++) {
			out.verts.push_back(centre + corners[k][q] * span);
			out.normals.push_back(nf);
			out.colors.push_back(pal[look]);
			out.uv.push_back(Vector2(LEVEL_VALUE[(ao >> (q * 2)) & 3], finish_class));
		}
		const int *split = (ao & FLIP) ? SPLIT_13 : SPLIT_02;
		for (int s = 0; s < 6; s++) {
			out.index.push_back(at + split[s]);
		}
	};
	std::vector<int32_t> planes(size_t(6) * REGION * REGION * REGION, -1);
	for (int y = y0; y < y1; y++)
		for (int z = z0; z < z1; z++)
			for (int x = x0; x < x1; x++) {
				const int64_t i = x + z * int64_t(w) + y * plan;
				if (!g[i]) continue;
				const int l[3] = { x - x0, y - y0, z - z0 };
				for (int k = 0; k < 6; k++) {
					const int ax = x + DIRS[k][0], ay = y + DIRS[k][1], az = z + DIRS[k][2];
					if (!open(ax, ay, az)) continue;
					int bits = 0;
					for (int s = 0; s < 8; s++) {
						const Vector3i &st = ring[k][s];
						if (!open(ax + st.x, ay + st.y, az + st.z)) bits |= 1 << s;
					}
					const int ao = ao_table[bits];
					if ((ao & 255) == (ao & 3) * 0x55) {
						planes[plane_at(k, l[AXES[k][0]], l[AXES[k][1]], l[AXES[k][2]])] = int32_t(lk[i]) * 1024 + ao;
					} else {
						face(origin + Vector3(float(x), float(y), float(z)) * voxel, k, lk[i], ao, Vector3(1, 1, 1));
					}
				}
			}
	// CellMesher._merge: from the lowest (v, u) still free, a run along u of one key, grown along v
	// while every row matches.
	for (int k = 0; k < 6; k++)
		for (int dd = 0; dd < REGION; dd++)
			for (int v = 0; v < REGION; v++)
				for (int u = 0; u < REGION; u++) {
					const int32_t key = planes[plane_at(k, dd, u, v)];
					if (key < 0) continue;
					int nu = 1;
					while (u + nu < REGION && planes[plane_at(k, dd, u + nu, v)] == key) nu++;
					int nv = 1;
					for (;;) {
						if (v + nv >= REGION) break;
						bool row = true;
						for (int i = 0; i < nu && row; i++) row = planes[plane_at(k, dd, u + i, v + nv)] == key;
						if (!row) break;
						nv++;
					}
					for (int j = 0; j < nv; j++)
						for (int i = 0; i < nu; i++) planes[plane_at(k, dd, u + i, v + j)] = -1;
					Vector3 mid(float(x0), float(y0), float(z0));
					mid[AXES[k][0]] = float(double(mid[AXES[k][0]]) + dd);
					mid[AXES[k][1]] = float(double(mid[AXES[k][1]]) + (u + (nu - 1) * 0.5));
					mid[AXES[k][2]] = float(double(mid[AXES[k][2]]) + (v + (nv - 1) * 0.5));
					Vector3 span(1, 1, 1);
					span[AXES[k][1]] = float(nu);
					span[AXES[k][2]] = float(nv);
					face(origin + mid * voxel, k, key >> 10, key & 1023, span);
				}
	return pack(out);
}
