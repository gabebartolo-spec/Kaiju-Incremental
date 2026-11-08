// The game's C++ destruction core with Godot taken out: carve, support, the settle rule, the
// topple scan and the region mesher. Same algorithms and scan orders as native/src/kaiju_carve.cpp,
// kaiju_settle.cpp, kaiju_mesher.cpp and sim/voxel_topple.gd, checked against Godot's own results by
// tools/unity/check_core.py. Every function is thread-safe on distinct grids; a mesher is read-only
// once created, and its scratch is thread-local.
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <vector>

#define KC_API extern "C" __declspec(dllexport)

namespace {

struct V3 {
	float x, y, z;
	V3 operator+(const V3 &o) const { return { x + o.x, y + o.y, z + o.z }; }
	V3 operator-(const V3 &o) const { return { x - o.x, y - o.y, z - o.z }; }
	V3 operator*(const V3 &o) const { return { x * o.x, y * o.y, z * o.z }; }
	V3 operator*(float s) const { return { x * s, y * s, z * s }; }
};

inline V3 cross(const V3 &a, const V3 &b) {
	return { a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x };
}

inline V3 normalized(const V3 &a) {
	const float l2 = a.x * a.x + a.y * a.y + a.z * a.z;
	if (l2 == 0.0f) return a;
	const float l = std::sqrt(l2);
	return { a.x / l, a.y / l, a.z / l };
}

inline int sign_of(float x) { return x > 0 ? 1 : (x < 0 ? -1 : 0); }

const int REGION = 16;
const int DIRS[6][3] = { { -1, 0, 0 }, { 1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, -1 }, { 0, 0, 1 } };
const int CORNER_BITS[4][3] = { { 0, 2, 4 }, { 1, 2, 5 }, { 1, 3, 6 }, { 0, 3, 7 } };
const float LEVEL_VALUE[4] = { 0.0f, float(1.0 / 3.0), float(2.0 / 3.0), 1.0f };
const int SPLIT_02[6] = { 0, 2, 1, 0, 3, 2 };
const int SPLIT_13[6] = { 0, 3, 1, 1, 3, 2 };
const int FLIP = 256;
const int AXES[6][3] = { { 0, 1, 2 }, { 0, 1, 2 }, { 1, 0, 2 }, { 1, 0, 2 }, { 2, 0, 1 }, { 2, 0, 1 } };

inline int ao_level(bool s1, bool s2, bool c) {
	if (s1 && s2) return 0;
	return 3 - int(s1) - int(s2) - int(c);
}

inline int plane_at(int k, int d, int u, int v) { return ((k * REGION + d) * REGION + v) * REGION + u; }

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

#pragma pack(push, 1)
struct KcVertex {
	float px, py, pz;
	float nx, ny, nz;
	uint8_t r, g, b, a;
	float u, v;
};
struct KcTip {
	int32_t part, level, dir_x, dir_z;
	float pivot_x, pivot_z; // cells, in the grid
};
struct KcParticle {
	float px, py, pz;
	uint32_t color;
	float vx, vy, vz;
	uint32_t seed;
};
#pragma pack(pop)

struct KcMesher {
	int w, h, d;
	int ox, oy, oz;
	V3 origin;
	float voxel;
	std::vector<uint8_t> looks;
	uint8_t palette[256 * 4];
	uint8_t finish[256];
	bool mirror;
	V3 corners[6][4];
	int ring[6][8][3];
	uint16_t ao_table[256];
};

KC_API int kc_version() { return 1; }

// KaijuCarve.carve_sphere: cell (x,y,z) goes when its centre is within r of c (cell units). Clears
// `cells` and, when given, `drawn`; writes up to `cap` removed indices; returns how many went.
KC_API int kc_carve_sphere(uint8_t *cells, uint8_t *drawn, int w, int h, int d, float cx, float cy, float cz, float r,
		int32_t *out, int cap) {
	const int x0 = std::max(0, int(std::floor(cx - r))), x1 = std::min(w - 1, int(std::ceil(cx + r)));
	const int y0 = std::max(0, int(std::floor(cy - r))), y1 = std::min(h - 1, int(std::ceil(cy + r)));
	const int z0 = std::max(0, int(std::floor(cz - r))), z1 = std::min(d - 1, int(std::ceil(cz + r)));
	const int plan = w * d;
	const float r2 = r * r;
	int removed = 0;
	for (int y = y0; y <= y1; y++)
		for (int z = z0; z <= z1; z++)
			for (int x = x0; x <= x1; x++) {
				const float dx = x + 0.5f - cx, dy = y + 0.5f - cy, dz = z + 0.5f - cz;
				if (dx * dx + dy * dy + dz * dz > r2) continue;
				const int i = x + z * w + y * plan;
				if (cells[i] == 0) continue;
				cells[i] = 0;
				if (drawn) drawn[i] = 0;
				if (out && removed < cap) out[removed] = i;
				removed++;
			}
	return removed;
}

// KaijuSettle.label: per cell the grounded part's label (1, 2, ... in scan order of its first ground
// cell), 0 not grounded; returns the count of parts.
KC_API int kc_label(const uint8_t *cells, const uint8_t *fix, int has_fixtures, int w, int h, int d, int32_t *lab) {
	const int plan = w * d;
	const int64_t n = int64_t(w) * h * d;
	std::memset(lab, 0, size_t(n) * sizeof(int32_t));
	int count = 0;
	thread_local std::vector<int> stack;
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
	if (has_fixtures) {
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
	return count;
}

// KaijuSettle.islands: the ungrounded parts in scan order, each in flood order, packed into `out`
// with `sizes` per part. Returns the parts written; `total` receives all cells written.
KC_API int kc_islands(const int32_t *lab, const uint8_t *cells, const uint8_t *fix, int has_fixtures, int w, int h,
		int d, int32_t *out, int out_cap, int32_t *sizes, int size_cap, int32_t *total) {
	const int plan = w * d;
	const int64_t n = int64_t(w) * h * d;
	thread_local std::vector<uint8_t> taken;
	taken.assign(size_t(n), 0);
	auto open = [&](int j) { return lab[j] == 0 && !taken[j] && cells[j] != 0; };
	Ring ring;
	int parts = 0;
	int at = 0;
	for (int start = 0; start < n; start++) {
		if (!open(start)) continue;
		if (parts >= size_cap || at >= out_cap) break;
		const int first = at;
		out[at++] = start;
		taken[start] = 1;
		for (int k = first; k < at; k++) {
			const int i = out[k];
			if (has_fixtures) {
				const bool loose = fix[cells[i]] != 0;
				ring_of(i, w, d, h, plan, ring);
				for (int r = 0; r < ring.n && at < out_cap; r++) {
					const int j = ring.idx[r];
					if (!open(j)) continue;
					if (loose || ring.face[r] || fix[cells[j]] != 0) {
						taken[j] = 1;
						out[at++] = j;
					}
				}
				continue;
			}
			const int x = i % w, z = (i / w) % d, y = i / plan;
			auto visit = [&](int j) {
				if (open(j) && at < out_cap) {
					taken[j] = 1;
					out[at++] = j;
				}
			};
			if (x > 0) visit(i - 1);
			if (x < w - 1) visit(i + 1);
			if (z > 0) visit(i - w);
			if (z < d - 1) visit(i + w);
			if (y > 0) visit(i - plan);
			if (y < h - 1) visit(i + plan);
		}
		sizes[parts++] = at - first;
	}
	if (total) *total = at;
	return parts;
}

// KaijuSettle.floors + VoxelTopple.scan_levels + tip_of: per grounded part the lowest level whose
// load has its centre of mass outside the box of the cells standing on a structural cell there.
KC_API int kc_topple(const int32_t *lab, const uint8_t *cells, const uint8_t *fix, int w, int h, int d, int count,
		KcTip *out, int cap) {
	if (count <= 0) return 0;
	const int plan = w * d;
	const int64_t n = int64_t(w) * h * d;
	thread_local std::vector<int64_t> ms, xs, zs;
	thread_local std::vector<int32_t> bx;
	ms.assign(size_t(int64_t(count) * (h + 1)), 0);
	xs.assign(ms.size(), 0);
	zs.assign(ms.size(), 0);
	bx.assign(size_t(int64_t(count) * h * 4), -1);
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
			int32_t *b = bx.data() + (int64_t(k) * h + y) * 4;
			const bool fresh = b[2] < 0;
			b[0] = fresh ? x : std::min(b[0], x);
			b[1] = fresh ? z : std::min(b[1], z);
			b[2] = fresh ? x + 1 : std::max(b[2], x + 1);
			b[3] = fresh ? z + 1 : std::max(b[3], z + 1);
		}
	}
	for (int k = 0; k < count; k++)
		for (int y = h - 1; y >= 0; y--) {
			const int64_t at = int64_t(k) * (h + 1) + y;
			ms[at] += ms[at + 1];
			xs[at] += xs[at + 1];
			zs[at] += zs[at + 1];
		}
	auto over = [](int64_t s, int64_t mass, int lo, int hi) -> int64_t {
		if (s > 2 * hi * mass) return s - 2 * hi * mass;
		if (s < 2 * lo * mass) return s - 2 * lo * mass;
		return 0;
	};
	int found = 0;
	for (int k = 0; k < count && found < cap; k++)
		for (int level = 1; level < h; level++) {
			const int64_t at = int64_t(k) * (h + 1) + level;
			const int64_t mass = ms[at];
			if (mass == 0) break;
			const int32_t *b = bx.data() + (int64_t(k) * h + level) * 4;
			if (b[2] < 0) continue;
			const int64_t ox = over(xs[at], mass, b[0], b[2]);
			const int64_t oz = over(zs[at], mass, b[1], b[3]);
			if (ox == 0 && oz == 0) continue;
			int dx = ox > 0 ? 1 : (ox < 0 ? -1 : 0), dz = 0;
			if (std::llabs(oz) > std::llabs(ox)) {
				dx = 0;
				dz = oz > 0 ? 1 : -1;
			}
			const float cx = float(xs[at]) / float(2 * mass), cz = float(zs[at]) / float(2 * mass);
			KcTip &t = out[found++];
			t.part = k + 1;
			t.level = level;
			t.dir_x = dx;
			t.dir_z = dz;
			t.pivot_x = dx > 0 ? float(b[2]) : (dx < 0 ? float(b[0]) : cx);
			t.pivot_z = dz > 0 ? float(b[3]) : (dz < 0 ? float(b[1]) : cz);
			break;
		}
	return found;
}

// A region's solid cells and their box (lo inclusive, hi exclusive, in cells).
KC_API int kc_region_bbox(const uint8_t *cells, int w, int h, int d, int rx, int ry, int rz, int32_t *lo, int32_t *hi) {
	const int plan = w * d;
	const int x0 = rx * REGION, y0 = ry * REGION, z0 = rz * REGION;
	const int x1 = std::min(w, x0 + REGION), y1 = std::min(h, y0 + REGION), z1 = std::min(d, z0 + REGION);
	int n = 0;
	int a[3] = { x1, y1, z1 }, b[3] = { x0, y0, z0 };
	for (int y = y0; y < y1; y++)
		for (int z = z0; z < z1; z++)
			for (int x = x0; x < x1; x++) {
				if (!cells[x + z * w + y * plan]) continue;
				n++;
				a[0] = std::min(a[0], x);
				a[1] = std::min(a[1], y);
				a[2] = std::min(a[2], z);
				b[0] = std::max(b[0], x + 1);
				b[1] = std::max(b[1], y + 1);
				b[2] = std::max(b[2], z + 1);
			}
	for (int i = 0; i < 3; i++) {
		lo[i] = a[i];
		hi[i] = b[i];
	}
	return n;
}

// The box of a list of cells (lo inclusive, hi exclusive).
KC_API void kc_cells_bounds(const int32_t *index, int n, int w, int d, int32_t *lo, int32_t *hi) {
	const int plan = w * d;
	lo[0] = lo[1] = lo[2] = 2147483647;
	hi[0] = hi[1] = hi[2] = -2147483647;
	for (int k = 0; k < n; k++) {
		const int i = index[k];
		const int x = i % w, z = (i / w) % d, y = i / plan;
		lo[0] = std::min(lo[0], x);
		lo[1] = std::min(lo[1], y);
		lo[2] = std::min(lo[2], z);
		hi[0] = std::max(hi[0], x + 1);
		hi[1] = std::max(hi[1], y + 1);
		hi[2] = std::max(hi[2], z + 1);
	}
}

// Moves a list of cells out of a grid into a smaller one at `lo`: cells and drawn are cleared at the
// source. dst grids are nw x nh x nd, zero-filled by the caller.
KC_API void kc_cells_move(uint8_t *cells, uint8_t *drawn, const uint8_t *looks, const int32_t *index, int n, int w,
		int d, const int32_t *lo, int nw, int nd, uint8_t *dst_cells, uint8_t *dst_drawn, uint8_t *dst_looks) {
	const int plan = w * d, nplan = nw * nd;
	for (int k = 0; k < n; k++) {
		const int i = index[k];
		const int x = i % w, z = (i / w) % d, y = i / plan;
		const int j = (x - lo[0]) + (z - lo[2]) * nw + (y - lo[1]) * nplan;
		dst_cells[j] = cells[i];
		dst_drawn[j] = drawn[i];
		dst_looks[j] = looks[i];
		cells[i] = 0;
		drawn[i] = 0;
	}
}

KC_API KcMesher *kc_mesher_create(int w, int h, int d, int ox, int oy, int oz, float fx, float fy, float fz, float voxel,
		const uint8_t *looks, const uint8_t *palette_rgba, const uint8_t *finish, int mirror) {
	KcMesher *m = new KcMesher();
	m->w = w;
	m->h = h;
	m->d = d;
	m->ox = ox;
	m->oy = oy;
	m->oz = oz;
	m->origin = { fx, fy, fz };
	m->voxel = voxel;
	m->looks.assign(looks, looks + int64_t(w) * h * d);
	std::memcpy(m->palette, palette_rgba, sizeof(m->palette));
	std::memcpy(m->finish, finish, sizeof(m->finish));
	m->mirror = mirror != 0;
	const float half = voxel * 0.5f;
	for (int k = 0; k < 6; k++) {
		const V3 nf = { float(DIRS[k][0]), float(DIRS[k][1]), float(DIRS[k][2]) };
		const V3 a = DIRS[k][1] == 0 ? V3{ 0, 1, 0 } : V3{ 1, 0, 0 };
		const V3 u = cross(a, nf) * half;
		const V3 v = cross(nf, normalized(u)) * half;
		const V3 c = nf * half;
		m->corners[k][0] = c - u - v;
		m->corners[k][1] = c + u - v;
		m->corners[k][2] = c + u + v;
		m->corners[k][3] = c - u + v;
		const int U[3] = { sign_of(u.x), sign_of(u.y), sign_of(u.z) };
		const int V[3] = { sign_of(v.x), sign_of(v.y), sign_of(v.z) };
		const int su[8] = { -1, 1, 0, 0, -1, 1, 1, -1 };
		const int sv[8] = { 0, 0, -1, 1, -1, -1, 1, 1 };
		for (int s = 0; s < 8; s++)
			for (int e = 0; e < 3; e++) m->ring[k][s][e] = su[s] * U[e] + sv[s] * V[e];
	}
	for (int bits = 0; bits < 256; bits++) {
		int lv[4];
		for (int q = 0; q < 4; q++) {
			lv[q] = ao_level(bits & (1 << CORNER_BITS[q][0]), bits & (1 << CORNER_BITS[q][1]),
					bits & (1 << CORNER_BITS[q][2]));
		}
		const int packed = lv[0] | (lv[1] << 2) | (lv[2] << 4) | (lv[3] << 6);
		m->ao_table[bits] = uint16_t(packed | (lv[1] + lv[3] > lv[0] + lv[2] ? FLIP : 0));
	}
	return m;
}

KC_API void kc_mesher_destroy(KcMesher *m) { delete m; }

namespace {
thread_local std::vector<KcVertex> tl_verts;
thread_local std::vector<uint32_t> tl_index;
thread_local std::vector<int32_t> tl_planes;
} // namespace

// KaijuMesher.mesh_region. Meshes into this thread's buffers and returns the counts; kc_mesh_copy,
// on the same thread, copies them out. (Two calls, so MeshData can be sized between them.)
KC_API void kc_mesh_region(const KcMesher *m, const uint8_t *g, int rx, int ry, int rz, int32_t *out_verts,
		int32_t *out_index) {
	auto &verts = tl_verts;
	auto &index = tl_index;
	auto &planes = tl_planes;
	verts.clear();
	index.clear();
	if (planes.empty()) planes.assign(size_t(6) * REGION * REGION * REGION, -1);
	const uint8_t *lk = m->looks.data();
	const uint8_t *pal = m->palette;
	const uint8_t *fin = m->finish;
	const int w = m->w, h = m->h, d = m->d;
	const int64_t plan = int64_t(w) * d;
	const int x0 = rx * REGION, y0 = ry * REGION, z0 = rz * REGION;
	const int x1 = std::min(w, x0 + REGION), y1 = std::min(h, y0 + REGION), z1 = std::min(d, z0 + REGION);
	const int oy = m->oy;
	const float zs = m->mirror ? -1.0f : 1.0f;
	auto open = [&](int x, int y, int z) -> bool {
		if (y + oy < 0) return false;
		if (x < 0 || y < 0 || z < 0 || x >= w || y >= h || z >= d) return true;
		return g[x + z * int64_t(w) + y * plan] == 0;
	};
	auto face = [&](const V3 &centre, int k, int look, int ao, const V3 &span) {
		const uint32_t at = uint32_t(verts.size());
		const float finish_class = float(fin[look]);
		for (int q = 0; q < 4; q++) {
			const V3 p = centre + m->corners[k][q] * span;
			KcVertex vtx;
			vtx.px = p.x;
			vtx.py = p.y;
			vtx.pz = p.z * zs;
			vtx.nx = float(DIRS[k][0]);
			vtx.ny = float(DIRS[k][1]);
			vtx.nz = float(DIRS[k][2]) * zs;
			vtx.r = pal[look * 4];
			vtx.g = pal[look * 4 + 1];
			vtx.b = pal[look * 4 + 2];
			vtx.a = pal[look * 4 + 3];
			vtx.u = LEVEL_VALUE[(ao >> (q * 2)) & 3];
			vtx.v = finish_class;
			verts.push_back(vtx);
		}
		const int *split = (ao & FLIP) ? SPLIT_13 : SPLIT_02;
		// Winding stays as is when mirrored: Godot and Unity both call clockwise the front, and z negated
		// with the handedness swapped is the same picture on screen.
		for (int s = 0; s < 6; s++) index.push_back(at + split[s]);
	};
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
						const int *st = m->ring[k][s];
						if (!open(ax + st[0], ay + st[1], az + st[2])) bits |= 1 << s;
					}
					const int ao = m->ao_table[bits];
					if ((ao & 255) == (ao & 3) * 0x55) {
						planes[plane_at(k, l[AXES[k][0]], l[AXES[k][1]], l[AXES[k][2]])] = int32_t(lk[i]) * 1024 + ao;
					} else {
						const V3 at_cell = V3{ float(x), float(y), float(z) } * m->voxel;
						face(m->origin + at_cell, k, lk[i], ao, V3{ 1, 1, 1 });
					}
				}
			}
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
					float mid[3] = { float(x0), float(y0), float(z0) };
					mid[AXES[k][0]] = float(double(mid[AXES[k][0]]) + dd);
					mid[AXES[k][1]] = float(double(mid[AXES[k][1]]) + (u + (nu - 1) * 0.5));
					mid[AXES[k][2]] = float(double(mid[AXES[k][2]]) + (v + (nv - 1) * 0.5));
					float span[3] = { 1, 1, 1 };
					span[AXES[k][1]] = float(nu);
					span[AXES[k][2]] = float(nv);
					const V3 at_cell = V3{ mid[0], mid[1], mid[2] } * m->voxel;
					face(m->origin + at_cell, k, key >> 10, key & 1023, V3{ span[0], span[1], span[2] });
				}
	*out_verts = int32_t(verts.size());
	*out_index = int32_t(index.size());
}

KC_API void kc_mesh_copy(KcVertex *dst_verts, uint32_t *dst_index) {
	if (!tl_verts.empty()) std::memcpy(dst_verts, tl_verts.data(), tl_verts.size() * sizeof(KcVertex));
	if (!tl_index.empty()) std::memcpy(dst_index, tl_index.data(), tl_index.size() * sizeof(uint32_t));
}

// Carved cells to debris particles. Positions in the world through the body's matrix (column-major,
// Unity axes); velocity: the body's linear velocity, plus a seeded burst away from `centre`.
KC_API int kc_debris(const KcMesher *m, const int32_t *index, int n, const float *mat, const float *velocity,
		const float *centre, float burst, float up, float scatter, uint32_t tick, KcParticle *out, int cap) {
	const int w = m->w, d = m->d, plan = w * d;
	const float zs = m->mirror ? -1.0f : 1.0f;
	const int count = std::min(n, cap);
	for (int k = 0; k < count; k++) {
		const int i = index[k];
		const int x = i % w, z = (i / w) % d, y = i / plan;
		const uint8_t *c = m->palette + m->looks[i] * 4;
		const float lx = m->origin.x + x * m->voxel;
		const float ly = m->origin.y + y * m->voxel;
		const float lz = (m->origin.z + z * m->voxel) * zs;
		const float px = mat[0] * lx + mat[4] * ly + mat[8] * lz + mat[12];
		const float py = mat[1] * lx + mat[5] * ly + mat[9] * lz + mat[13];
		const float pz = mat[2] * lx + mat[6] * ly + mat[10] * lz + mat[14];
		uint32_t h = uint32_t(i) * 2654435761u ^ (tick * 2246822519u + uint32_t(k));
		h ^= h >> 15;
		h *= 2221713035u;
		h ^= h >> 13;
		const float r0 = float(h & 1023) / 1023.0f, r1 = float((h >> 10) & 1023) / 1023.0f,
					r2 = float((h >> 20) & 1023) / 1023.0f;
		float ax = px - centre[0], ay = py - centre[1], az = pz - centre[2];
		const float al = std::sqrt(ax * ax + ay * ay + az * az) + 1e-4f;
		ax /= al;
		ay /= al;
		az /= al;
		const float speed = burst * (0.35f + 0.65f * r0);
		KcParticle &p = out[k];
		p.px = px;
		p.py = py;
		p.pz = pz;
		p.color = uint32_t(c[0]) | uint32_t(c[1]) << 8 | uint32_t(c[2]) << 16 | 255u << 24;
		p.vx = velocity[0] + ax * speed + (r1 - 0.5f) * scatter;
		p.vy = velocity[1] + ay * speed + up * r2;
		p.vz = velocity[2] + az * speed + (r2 - 0.5f) * scatter;
		p.seed = h;
	}
	return count;
}
