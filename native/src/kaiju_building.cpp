#include "kaiju_building.h"
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3i.hpp>
#include <godot_cpp/variant/vector4i.hpp>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <unordered_map>
#include <vector>

using namespace godot;

void KaijuBuilding::_bind_methods() {
	ClassDB::bind_method(D_METHOD("bake", "cells", "colors", "palette", "finish", "dims", "origin", "noise", "face_u",
								 "face_v", "axes", "rings", "ao"),
			&KaijuBuilding::bake);
}

namespace {

const Vector3i NEIGHBOURS[6] = { Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, -1), Vector3i(0, 0, 1) };
const int SAMPLES_PER_CHUNK = 12;
const int SPLIT_02[6] = { 0, 2, 1, 0, 3, 2 };
const int SPLIT_13[6] = { 0, 3, 1, 1, 3, 2 };
const int FLIP = 256;
const double LEVEL_VALUE[4] = { 0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0 };
const double VOXEL = 1.0 / 8.0;
const int64_t MAX_GRID = 64 * 1024 * 1024;
const uint16_t OUTSIDE = 0x8000; // a slab proud of the hollow: hides nothing in the shell bake

uint32_t bits_of(float f) {
	if (f == 0.0f) f = 0.0f; // -0 matches 0, as the GDScript key's == does
	uint32_t u;
	std::memcpy(&u, &f, 4);
	return u;
}

// What two flat faces must share to merge (BuildingMesher._queue's key).
struct MergeKey {
	int chunk;
	uint32_t r, g, b, a;
	int finish;
	int ao;
	bool operator==(const MergeKey &o) const {
		return chunk == o.chunk && r == o.r && g == o.g && b == o.b && a == o.a && finish == o.finish && ao == o.ao;
	}
};

struct MergeKeyHash {
	size_t operator()(const MergeKey &k) const {
		uint64_t h = 1469598103934665603ull;
		const uint32_t parts[7] = { (uint32_t)k.chunk, k.r, k.g, k.b, k.a, (uint32_t)k.finish, (uint32_t)k.ao };
		for (uint32_t p : parts) h = (h ^ p) * 1099511628211ull;
		return (size_t)h;
	}
};

struct Face {
	Vector2i p;
	int id;
};

struct Plane {
	int k;
	int depth;
	std::vector<Face> faces;
};

struct Baker {
	// The grid: key id + 1 per cell (0 empty), OUTSIDE set on the slabs proud of the hollow.
	std::vector<uint16_t> grid;
	Vector3i lo, size;
	int w = 0, h = 0, d = 0, bw = 1, bh = 1, bd = 1, res = 8;
	bool shell = true; // the bake under way: the shell (OUTSIDE cells hide nothing) or the slabs
	const int32_t *axes = nullptr;
	const int32_t *rings = nullptr;
	const int32_t *ao_table = nullptr;
	Vector3 face_u[6], face_v[6];
	// The cell or merged run being meshed.
	Color base;
	int chunk = 0;
	int finish_class = 0;
	std::vector<Vector3> verts, normals;
	std::vector<Color> colors;
	std::vector<Vector2> uv, uv2;
	std::vector<int32_t> index;
	std::unordered_map<MergeKey, int, MergeKeyHash> merge_ids;
	std::vector<MergeKey> merge_info;
	std::vector<Color> merge_color;
	std::unordered_map<int64_t, int> plane_ids;
	std::vector<Plane> planes;

	uint16_t at(const Vector3i &c) const {
		const int x = c.x - lo.x, y = c.y - lo.y, z = c.z - lo.z;
		if (x < 0 || y < 0 || z < 0 || x >= size.x || y >= size.y || z >= size.z) return 0;
		return grid[((int64_t)y * size.z + z) * size.x + x];
	}

	bool inside(const Vector3i &c) const {
		return c.x >= 1 && c.x <= w - 2 && c.z >= 1 && c.z <= d - 2 && c.y >= 0 && c.y < h - 1;
	}

	bool solid(const Vector3i &n, bool hollow) const {
		const uint16_t g = at(n);
		const bool has = g != 0 && !(shell && (g & OUTSIDE));
		return has || (hollow && inside(n)) || n.y < 0;
	}

	int chunk_index(const Vector3i &c) const {
		// floori(float(c) / res) on whole numbers: exact in double.
		const int cx = std::clamp((int)std::floor((double)c.x / res), 0, bw - 1);
		const int cy = std::clamp((int)std::floor((double)c.y / res), 0, bh - 1);
		const int cz = std::clamp((int)std::floor((double)c.z / res), 0, bd - 1);
		return cx + cz * bw + cy * bw * bd;
	}

	void quad(const Vector3 &centre, int k, int ao, const Vector3 &span) {
		const int32_t start = (int32_t)verts.size();
		const Vector3 nf = Vector3(NEIGHBOURS[k]);
		const Vector3 u = face_u[k] * span;
		const Vector3 v = face_v[k] * span;
		const Vector3 c = centre + nf * (real_t)(VOXEL * 0.5);
		verts.push_back(c - u - v);
		verts.push_back(c + u - v);
		verts.push_back(c + u + v);
		verts.push_back(c - u + v);
		const Vector2 tag((real_t)chunk, 0.0f);
		for (int q = 0; q < 4; q++) {
			normals.push_back(nf);
			colors.push_back(base);
			uv.push_back(Vector2((real_t)LEVEL_VALUE[(ao >> (q * 2)) & 3], (real_t)finish_class));
			uv2.push_back(tag);
		}
		const int *split = (ao & FLIP) != 0 ? SPLIT_13 : SPLIT_02;
		for (int i = 0; i < 6; i++) index.push_back(start + split[i]);
	}

	void queue(const Vector3i &cell, int k, int ao) {
		const MergeKey key{ chunk, bits_of(base.r), bits_of(base.g), bits_of(base.b), bits_of(base.a), finish_class, ao };
		auto found = merge_ids.find(key);
		int id;
		if (found == merge_ids.end()) {
			id = (int)merge_info.size();
			merge_ids.emplace(key, id);
			merge_info.push_back(key);
			merge_color.push_back(base);
		} else {
			id = found->second;
		}
		const int32_t *ax = axes + k * 3;
		const int depth = cell[ax[0]];
		const int64_t plane_key = ((int64_t)k << 40) ^ (int64_t)(uint32_t)depth;
		auto pf = plane_ids.find(plane_key);
		int pi;
		if (pf == plane_ids.end()) {
			pi = (int)planes.size();
			plane_ids.emplace(plane_key, pi);
			planes.push_back(Plane{ k, depth, {} });
		} else {
			pi = pf->second;
		}
		planes[pi].faces.push_back(Face{ Vector2i(cell[ax[2]], cell[ax[1]]), id });
	}

	// BuildingMesher._merge: plane by plane in the order first queued, faces in sorted order, each grows
	// along u then v while the faces match.
	void merge(const Vector3 &origin) {
		std::vector<int> grid2;
		for (Plane &plane : planes) {
			std::vector<Face> &faces = plane.faces;
			std::sort(faces.begin(), faces.end(), [](const Face &a, const Face &b) {
				return a.p.x != b.p.x ? a.p.x < b.p.x : a.p.y < b.p.y;
			});
			int x0 = faces[0].p.x, x1 = x0, y0 = faces[0].p.y, y1 = y0;
			for (const Face &f : faces) {
				x0 = std::min(x0, f.p.x);
				x1 = std::max(x1, f.p.x);
				y0 = std::min(y0, f.p.y);
				y1 = std::max(y1, f.p.y);
			}
			const int nx = x1 - x0 + 1, ny = y1 - y0 + 1;
			grid2.assign((size_t)nx * ny, -1);
			auto get = [&](int x, int y) -> int {
				if (x < x0 || x > x1 || y < y0 || y > y1) return -1;
				return grid2[(size_t)(x - x0) * ny + (y - y0)];
			};
			for (const Face &f : faces) grid2[(size_t)(f.p.x - x0) * ny + (f.p.y - y0)] = f.id;
			const int k = plane.k;
			const int32_t *ax = axes + k * 3;
			for (const Face &f : faces) {
				const Vector2i p = f.p;
				const int id = get(p.x, p.y);
				if (id < 0) continue;
				int nu = 1;
				while (get(p.x, p.y + nu) == id) nu++;
				int nv = 1;
				for (;;) {
					bool row = true;
					for (int i = 0; i < nu; i++) {
						if (get(p.x + nv, p.y + i) != id) {
							row = false;
							break;
						}
					}
					if (!row) break;
					nv++;
				}
				for (int j = 0; j < nv; j++) {
					for (int i = 0; i < nu; i++) grid2[(size_t)(p.x + j - x0) * ny + (p.y + i - y0)] = -1;
				}
				Vector3 mid;
				mid[ax[0]] = (real_t)plane.depth;
				mid[ax[1]] = (real_t)(p.y + (nu - 1) * 0.5);
				mid[ax[2]] = (real_t)(p.x + (nv - 1) * 0.5);
				Vector3 span(1, 1, 1);
				span[ax[1]] = (real_t)nu;
				span[ax[2]] = (real_t)nv;
				const MergeKey &info = merge_info[id];
				chunk = info.chunk;
				base = merge_color[id];
				finish_class = info.finish;
				quad(origin + mid * (real_t)VOXEL, k, info.ao, span);
			}
		}
		planes.clear();
		plane_ids.clear();
		merge_ids.clear();
		merge_info.clear();
		merge_color.clear();
	}

	Array arrays() {
		Array out;
		if (!verts.empty()) {
			out.resize(Mesh::ARRAY_MAX);
			const int64_t n = (int64_t)verts.size();
			PackedVector3Array pv, pn;
			PackedColorArray pc;
			PackedVector2Array pu, pu2;
			PackedInt32Array pi;
			pv.resize(n);
			pn.resize(n);
			pc.resize(n);
			pu.resize(n);
			pu2.resize(n);
			pi.resize((int64_t)index.size());
			std::memcpy(pv.ptrw(), verts.data(), sizeof(Vector3) * n);
			std::memcpy(pn.ptrw(), normals.data(), sizeof(Vector3) * n);
			std::memcpy(pc.ptrw(), colors.data(), sizeof(Color) * n);
			std::memcpy(pu.ptrw(), uv.data(), sizeof(Vector2) * n);
			std::memcpy(pu2.ptrw(), uv2.data(), sizeof(Vector2) * n);
			std::memcpy(pi.ptrw(), index.data(), sizeof(int32_t) * index.size());
			out[Mesh::ARRAY_VERTEX] = pv;
			out[Mesh::ARRAY_NORMAL] = pn;
			out[Mesh::ARRAY_COLOR] = pc;
			out[Mesh::ARRAY_TEX_UV] = pu;
			out[Mesh::ARRAY_TEX_UV2] = pu2;
			out[Mesh::ARRAY_INDEX] = pi;
		}
		verts.clear();
		normals.clear();
		colors.clear();
		uv.clear();
		uv2.clear();
		index.clear();
		return out;
	}
};

struct Samples {
	std::vector<int> order; // chunks in the order first sampled
	std::unordered_map<int, int> slot;
	std::vector<std::vector<Vector3>> at;
	std::vector<std::vector<Color>> tint;
};

} // namespace

Variant KaijuBuilding::bake(const Dictionary &p_cells, const Dictionary &p_colors, const Dictionary &p_palette,
		const Dictionary &p_finish, const PackedInt32Array &p_dims, const Vector3 &p_origin, double p_noise,
		const PackedVector3Array &p_face_u, const PackedVector3Array &p_face_v, const PackedInt32Array &p_axes,
		const PackedInt32Array &p_rings, const PackedInt32Array &p_ao) {
	ERR_FAIL_COND_V_MSG(p_dims.size() != 8 || p_face_u.size() != 6 || p_face_v.size() != 6 || p_axes.size() != 18 ||
					p_rings.size() != 144 || p_ao.size() != 256,
			Variant(), "KaijuBuilding.bake: tables of the wrong size");
	Baker bk;
	bk.w = p_dims[0];
	bk.h = p_dims[1];
	bk.d = p_dims[2];
	bk.bw = p_dims[3];
	bk.bh = p_dims[4];
	bk.bd = p_dims[5];
	bk.res = p_dims[6];
	const int style = p_dims[7];
	bk.axes = p_axes.ptr();
	bk.rings = p_rings.ptr();
	bk.ao_table = p_ao.ptr();
	for (int k = 0; k < 6; k++) {
		bk.face_u[k] = p_face_u[k];
		bk.face_v[k] = p_face_v[k];
	}

	// The cells in the dictionary's order, their keys interned (a building has a handful).
	const Array keys = p_cells.keys();
	const Array vals = p_cells.values();
	const int64_t n = keys.size();
	std::vector<Vector3i> cells((size_t)n);
	std::vector<uint16_t> kid((size_t)n);
	std::vector<String> names;
	int last = -1;
	Vector3i lo, hi;
	for (int64_t i = 0; i < n; i++) {
		const Vector3i c = keys[i];
		cells[i] = c;
		const String s = vals[i];
		if (last < 0 || names[last] != s) {
			last = -1;
			for (int j = 0; j < (int)names.size(); j++) {
				if (names[j] == s) {
					last = j;
					break;
				}
			}
			if (last < 0) {
				ERR_FAIL_COND_V_MSG(names.size() >= 0x7ffe, Variant(), "KaijuBuilding.bake: too many keys");
				last = (int)names.size();
				names.push_back(s);
			}
		}
		kid[i] = (uint16_t)last;
		if (i == 0) {
			lo = c;
			hi = c;
		} else {
			lo = Vector3i(std::min(lo.x, c.x), std::min(lo.y, c.y), std::min(lo.z, c.z));
			hi = Vector3i(std::max(hi.x, c.x), std::max(hi.y, c.y), std::max(hi.z, c.z));
		}
	}
	if (n == 0) lo = hi = Vector3i();
	bk.lo = lo;
	bk.size = hi - lo + Vector3i(1, 1, 1);
	const int64_t volume = (int64_t)bk.size.x * bk.size.y * bk.size.z;
	if (volume > MAX_GRID) return Variant();
	bk.grid.assign((size_t)volume, 0);

	// Per key: palette colour, finish class, whether it is a slab or a DIRECT colour.
	const int nk = (int)names.size();
	std::vector<Color> key_color(nk);
	std::vector<int> key_finish(nk);
	std::vector<char> key_slab(nk), key_direct(nk);
	for (int j = 0; j < nk; j++) {
		key_color[j] = p_palette.get(names[j], Color(1, 0, 1, 1));
		key_finish[j] = (int)(int64_t)(double)p_finish.get(names[j], 0);
		key_slab[j] = names[j] == String("slab");
		key_direct[j] = names[j] == String("#");
	}

	// BuildingMesher._init's split: shell cells, slab cells in the footprint, slabs outside the hollow.
	std::vector<int64_t> shell_cells, slab_cells;
	for (int64_t i = 0; i < n; i++) {
		const Vector3i c = cells[i];
		uint16_t g = (uint16_t)(kid[i] + 1);
		if (key_slab[kid[i]]) {
			if (!bk.inside(c)) g |= OUTSIDE;
			if (c.x >= 0 && c.x < bk.w && c.z >= 0 && c.z < bk.d) slab_cells.push_back(i);
		} else {
			shell_cells.push_back(i);
		}
		bk.grid[((int64_t)(c.y - lo.y) * bk.size.z + (c.z - lo.z)) * bk.size.x + (c.x - lo.x)] = g;
	}

	Samples samples;
	Array out;
	for (int pass = 0; pass < 2; pass++) {
		const bool shell = pass == 0;
		bk.shell = shell;
		const bool hollow = shell;
		const std::vector<int64_t> &list = shell ? shell_cells : slab_cells;
		for (int64_t i : list) {
			const Vector3i cell = cells[i];
			int mask = 0;
			for (int k = 0; k < 6; k++) {
				if (!bk.solid(cell + NEIGHBOURS[k], hollow)) mask |= 1 << k;
			}
			if (mask == 0) continue;
			const Vector3 centre = p_origin + Vector3(cell) * (real_t)VOXEL;
			const int key = kid[i];
			Color base = key_color[key];
			if (key_direct[key]) base = p_colors[cell];
			bk.base = base;
			bk.chunk = bk.chunk_index(cell);
			bk.finish_class = key_finish[key];
			for (int k = 0; k < 6; k++) {
				if ((mask & (1 << k)) == 0) continue;
				const Vector3i air = cell + NEIGHBOURS[k];
				const int32_t *steps = bk.rings + k * 24;
				int bits = 0;
				for (int s = 0; s < 8; s++) {
					const Vector3i step(steps[s * 3], steps[s * 3 + 1], steps[s * 3 + 2]);
					if (bk.solid(air + step, hollow)) bits |= 1 << s;
				}
				const int ao = bk.ao_table[bits];
				if ((ao & 255) == (ao & 3) * 0x55) {
					bk.queue(cell, k, ao);
				} else {
					bk.quad(centre, k, ao, Vector3(1, 1, 1));
				}
			}
			if (shell) {
				// BuildingMesher._sample, with Look.jitter_by's colour made only when it is kept.
				const int ch = bk.chunk;
				auto f = samples.slot.find(ch);
				int si;
				if (f == samples.slot.end()) {
					si = (int)samples.order.size();
					samples.slot.emplace(ch, si);
					samples.order.push_back(ch);
					samples.at.emplace_back();
					samples.tint.emplace_back();
				} else {
					si = f->second;
				}
				std::vector<Vector3> &at = samples.at[si];
				std::vector<Color> &tint = samples.tint[si];
				int slot = -1;
				if ((int)at.size() < SAMPLES_PER_CHUNK) {
					at.push_back(centre);
					tint.push_back(Color());
					slot = (int)at.size() - 1;
				} else if ((int64_t)Variant(centre).hash() % 7 == 0) {
					slot = (int)((int64_t)Variant(centre * (real_t)3.0).hash() % SAMPLES_PER_CHUNK);
					at[slot] = centre;
				}
				if (slot >= 0) {
					Color col = base;
					if (p_noise > 0.0) {
						const int64_t hv = (int64_t)Variant(Vector4i(cell.x, cell.y, cell.z, style)).hash();
						const double t = (double)(hv % 1000) / 1000.0 * 2.0 - 1.0;
						col = Color((float)(base.r * (1.0 + t * p_noise)), (float)(base.g * (1.0 + t * p_noise)),
								(float)(base.b * (1.0 + t * p_noise)), base.a);
					}
					tint[slot] = col;
				}
			}
		}
		bk.merge(p_origin);
		out.push_back(bk.arrays());
	}
	Dictionary dict;
	for (size_t s = 0; s < samples.order.size(); s++) {
		PackedVector3Array at;
		PackedColorArray tint;
		at.resize((int64_t)samples.at[s].size());
		tint.resize((int64_t)samples.tint[s].size());
		std::memcpy(at.ptrw(), samples.at[s].data(), sizeof(Vector3) * samples.at[s].size());
		std::memcpy(tint.ptrw(), samples.tint[s].data(), sizeof(Color) * samples.tint[s].size());
		Array pair;
		pair.push_back(at);
		pair.push_back(tint);
		dict[samples.order[s]] = pair;
	}
	out.push_back(dict);
	return out;
}
