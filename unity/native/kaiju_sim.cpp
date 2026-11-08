// The sim's native calls with Godot taken out: KaijuSettle's per-cell passes and generation, and
// KaijuWater's step. Same algorithms, scan orders and float steps as native/src/kaiju_settle.cpp,
// kaiju_settle_parts.cpp, kaiju_cells.cpp and kaiju_water.cpp, held to Godot's own logs by
// unity/SimTests (the replay runs with this DLL and without it). Arrays belong to the caller; a
// result of unknown length waits in thread-local storage for its _copy call.
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <vector>

#define KC_API extern "C" __declspec(dllexport)

namespace {

// Variant(Vector4i).hash(): Godot's murmur3 steps (sim/ rolls layouts with it).
inline uint32_t rotl32(uint32_t x, int r) {
	return (x << r) | (x >> (32 - r));
}

inline uint32_t murmur_one(uint32_t value, uint32_t seed) {
	value *= 0xcc9e2d51U;
	value = rotl32(value, 15);
	value *= 0x1b873593U;
	seed ^= value;
	seed = rotl32(seed, 13);
	return seed * 5U + 0xe6546b64U;
}

inline uint32_t hash_vector4i(int32_t x, int32_t y, int32_t z, int32_t w) {
	uint32_t h = murmur_one(uint32_t(x), 0x7F07C65U);
	h = murmur_one(uint32_t(y), h);
	h = murmur_one(uint32_t(z), h);
	h = murmur_one(uint32_t(w), h);
	h ^= h >> 16;
	h *= 0x85ebca6bU;
	h ^= h >> 13;
	h *= 0xc2b2ae35U;
	h ^= h >> 16;
	return h;
}

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

inline double maxd(double a, double b) {
	return a > b ? a : b;
}

enum Key {
	K_NONE = -1,
	WALL,
	PILLAR,
	TRIM,
	BAND,
	AWNING,
	SHOP,
	MULLION,
	WINDOW,
	SPANDREL,
	FRAME,
	GLASS_K,
	RAIL,
	SILL,
	SLAB,
	ROOF,
	VENT,
	GEAR,
	PIPE,
	TANK,
	BEACON,
	SIGN_FRAME,
	HEATER,
	HEATER_HI,
	SOLAR,
	NEON0,
	KEY_COUNT = NEON0 + 1, // neon0 .. neon<n-1> follow
};

enum Arch { OFFICE = 0, BRICK = 1, GLASS = 2, STONE = 3 };

// RoofTank's constants (sim/roof_tank.gd): the wooden water tower and the white solar heater on
// a BRICK roof, in cells.
const int WOODEN_ONE_IN = 4;
const int TOWER_LEGS = 2;
const int TOWER_LEG_AT = 2;
const int TOWER_PLATFORM_R2 = 8;
const int TOWER_BARREL = 6;
const int TOWER_BARREL_R2 = 5;
const int TOWER_HOOPS[2] = { 1, 4 };
const int TOWER_HOOP_INNER_R2 = 2;
const int TOWER_ROOF_R2[3] = { 10, 2, 0 };
const int TOWER_REACH = 3;
const int HEATER_W = 9;
const int HEATER_D = 8;
const int HEATER_ROWS = 7;

const int SIDE_X[4] = { -1, 1, 0, 0 };
const int SIDE_Z[4] = { 0, 0, -1, 1 };

struct Spec {
	int plane, recess, proud, further;
};

struct Gen {
	int w, d, h, res, style, tier, bw, bd, bh, bay, party, neon;
	int64_t pos; // roundi(b.x * 13 + b.z)
	double sign_chance;
	const int32_t *ids;
	int nids;
	// Flat grid with a margin: local cell (x, y, z) at (x + mx, y, z + mz).
	int mx, mz, gx, gy, gz;
	std::vector<uint8_t> grid;
	int lo[3], hi[3];
	bool any = false;
	bool out = false;

	int arch() const { return style % 4; }

	void mark(int x, int y, int z, int key) {
		const int ax = x + mx, az = z + mz;
		if (ax < 0 || az < 0 || y < 0 || ax >= gx || az >= gz || y >= gy) {
			out = true;
			return;
		}
		const int id = key >= 0 && key < nids ? ids[key] : 0;
		grid[(size_t)ax + (size_t)az * gx + (size_t)y * gx * gz] = (uint8_t)id;
		const int c[3] = { x, y, z };
		for (int i = 0; i < 3; i++) {
			lo[i] = std::min(lo[i], c[i]);
			hi[i] = std::max(hi[i], c[i]);
		}
	}

	bool has(int x, int y, int z) const {
		const int ax = x + mx, az = z + mz;
		if (ax < 0 || az < 0 || y < 0 || ax >= gx || az >= gz || y >= gy) return false;
		return grid[(size_t)ax + (size_t)az * gx + (size_t)y * gx * gz] != 0;
	}

	void box(int ax, int ay, int az, int cx, int cy, int cz, int key) {
		for (int x = std::min(ax, cx); x <= std::max(ax, cx); x++)
			for (int y = std::min(ay, cy); y <= std::max(ay, cy); y++)
				for (int z = std::min(az, cz); z <= std::max(az, cz); z++) mark(x, y, z, key);
	}

	int64_t roll(int x, int y, int z, int64_t mod) const {
		const int64_t hv = (int64_t)hash_vector4i(x, y, z, (int32_t)pos);
		return std::llabs(hv) % mod;
	}

	// BuildingLayout._at.
	void at(int side, int p, int y, int layer, int &x, int &z) const {
		if (SIDE_X[side] < 0) {
			x = layer;
			z = p;
		} else if (SIDE_X[side] > 0) {
			x = w - 1 - layer;
			z = p;
		} else if (SIDE_Z[side] < 0) {
			x = p;
			z = layer;
		} else {
			x = p;
			z = d - 1 - layer;
		}
	}

	void mark_at(int side, int p, int y, int layer, int key) {
		int x, z;
		at(side, p, y, layer, x, z);
		mark(x, y, z, key);
	}

	Spec ground(int y, int p) const {
		if (y == res - 1) return { TRIM, K_NONE, AWNING, AWNING };
		if (y == res - 2) return { BAND, K_NONE, BAND, K_NONE };
		if (p % res == 0 || y == 0) return { PILLAR, K_NONE, K_NONE, K_NONE };
		return { -2, SHOP, K_NONE, K_NONE }; // -2: recess
	}

	Spec office(int r, int q, bool top_row) const {
		if (r <= 1) return { r == 1 ? SPANDREL : TRIM, K_NONE, K_NONE, K_NONE };
		if (top_row) return { TRIM, K_NONE, TRIM, K_NONE };
		if (q == 0) return { PILLAR, K_NONE, K_NONE, K_NONE };
		if (r == 7) return { FRAME, K_NONE, K_NONE, K_NONE };
		return { -2, (q == 4 || r == 5) ? MULLION : WINDOW, K_NONE, K_NONE };
	}

	Spec brick(int r, int q, int floor_n) const {
		const bool balcony = floor_n % 2 == 0 && q >= 1 && q <= 6;
		if (q >= 2 && q <= 5 && r >= 2 && r <= 6) return { -2, r == 4 ? MULLION : WINDOW, K_NONE, K_NONE };
		if (r == 7 && q >= 2 && q <= 5) return { FRAME, K_NONE, FRAME, K_NONE };
		if (r == 1 && q >= 1 && q <= 6) return { WALL, K_NONE, balcony ? RAIL : SILL, balcony ? RAIL : K_NONE };
		if (r == 0 && balcony) return { WALL, K_NONE, SLAB, SLAB };
		return { WALL, K_NONE, K_NONE, K_NONE };
	}

	Spec stone(int r, int q, bool course, bool top_row) const {
		if (course) return { TRIM, K_NONE, TRIM, top_row ? TRIM : K_NONE };
		if (q == 0) return { PILLAR, K_NONE, PILLAR, K_NONE };
		if (q >= 2 && q <= 5 && r >= 2 && r <= 6) return { -2, WINDOW, K_NONE, K_NONE };
		if (r == 1 && q >= 2 && q <= 5) return { WALL, K_NONE, SILL, K_NONE };
		if (r == 7 && q >= 3 && q <= 4) return { TRIM, K_NONE, TRIM, K_NONE };
		return { WALL, K_NONE, K_NONE, K_NONE };
	}

	Spec upper(int y, int p) const {
		const int r = y % res;
		const int q = p % res;
		const bool top_row = y >= h - 2;
		switch (arch()) {
			case OFFICE:
				return office(r, q, top_row);
			case BRICK:
				return brick(r, q, y / res);
			case GLASS:
				if (q == 0 || r == 0) return { MULLION, K_NONE, K_NONE, K_NONE };
				if (r == 4) return { FRAME, K_NONE, K_NONE, K_NONE };
				return { GLASS_K, K_NONE, K_NONE, K_NONE };
			default:
				return stone(r, q, top_row || (r == 0 && (y / res) % 5 == 0), top_row);
		}
	}

	void face(int side) {
		const int length = SIDE_X[side] != 0 ? d : w;
		for (int y = 0; y < h; y++)
			for (int p = 0; p < length; p++) {
				if (p == 0 || p == length - 1) {
					mark_at(side, p, y, 0, PILLAR);
					continue;
				}
				const Spec s = y < res ? ground(y, p) : upper(y, p);
				if (s.plane == -2)
					mark_at(side, p, y, 1, s.recess);
				else
					mark_at(side, p, y, 0, s.plane);
				if (s.proud != K_NONE) mark_at(side, p, y, -1, s.proud);
				if (s.further != K_NONE) mark_at(side, p, y, -2, s.further);
			}
	}

	// GlassFrame.cells, marked in its order (its cells never overlap with different names).
	void frame() {
		if (arch() != GLASS) return;
		for (int side = 0; side < 4; side++) {
			const int length = SIDE_X[side] != 0 ? d : w;
			for (int p = 1; p < length - 1; p++) {
				const bool column = p == 1 || p == length - 2 || p % bay == 0;
				for (int y = 0; y < h; y++) {
					if (!(column || (y >= res && y % res == 4))) continue;
					int x = 1, z = p;
					if (SIDE_X[side] > 0) {
						x = w - 2;
					} else if (SIDE_Z[side] < 0) {
						x = p;
						z = 1;
					} else if (SIDE_Z[side] > 0) {
						x = p;
						z = d - 2;
					}
					mark(x, y, z, column ? PILLAR : FRAME);
				}
			}
		}
	}

	void slabs() {
		for (int fy = 0; fy < h; fy += res)
			for (int x = 1; x < w - 1; x++)
				for (int z = 1; z < d - 1; z++)
					if (!has(x, fy, z)) mark(x, fy, z, SLAB);
		for (int x = 1; x < w - 1; x++)
			for (int z = 1; z < d - 1; z++) mark(x, h - 1, z, ROOF);
	}

	void ac_units(int top) {
		const int n = std::clamp(bw, 1, 4);
		for (int i = 0; i < n; i++) {
			const int ax = 4 + (int)roll(i, 1, 0, std::max(1, w - 12));
			const int az = 4 + (int)roll(i, 2, 0, std::max(1, d - 12));
			box(ax, top, az, ax + 4, top + 3, az + 3, GEAR);
			box(ax + 1, top + 4, az + 1, ax + 3, top + 4, az + 2, VENT);
			box(ax + 5, top + 1, az + 1, ax + 8, top + 1, az + 1, PIPE);
		}
	}

	// RoofTank._put: a cell, only when it is inside the footprint.
	void put(int x, int y, int z, int key) {
		if (x >= 0 && x < w && z >= 0 && z < d) mark(x, y, z, key);
	}

	// RoofTank._disc: layer y's cells round (ax, az) whose squared distance from it is over inner2
	// and at most outer2, kept inside the footprint (outer2 0 is the one cell under it).
	void disc(int ax, int az, int y, int outer2, int key, int inner2 = -1) {
		for (int dx = -TOWER_REACH; dx <= TOWER_REACH; dx++)
			for (int dz = -TOWER_REACH; dz <= TOWER_REACH; dz++) {
				const int d2 = dx * dx + dz * dz;
				if (d2 > inner2 && d2 <= outer2) put(ax + dx, y, az + dz, key);
			}
	}

	// RoofTank._tower: legs, platform, barrel, hoops, cone roof, laid in that order.
	void tower(int top) {
		const int cx = (int)std::round(w * 0.65);
		const int cz = (int)std::round(d * 0.4);
		for (const int lz : { -TOWER_LEG_AT, TOWER_LEG_AT })
			for (const int lx : { -TOWER_LEG_AT, TOWER_LEG_AT })
				for (int y = top; y < top + TOWER_LEGS; y++) disc(cx + lx, cz + lz, y, 0, GEAR);
		disc(cx, cz, top + TOWER_LEGS, TOWER_PLATFORM_R2, GEAR);
		const int base = top + TOWER_LEGS + 1;
		for (int y = base; y < base + TOWER_BARREL; y++) disc(cx, cz, y, TOWER_BARREL_R2, TANK);
		for (const int hoop : TOWER_HOOPS) disc(cx, cz, base + hoop, TOWER_BARREL_R2, VENT, TOWER_HOOP_INNER_R2);
		for (int k = 0; k < 3; k++) disc(cx, cz, base + TOWER_BARREL + k, TOWER_ROOF_R2[k], TANK);
	}

	// RoofTank._heater: the two stepped panels with their frame and legs, then the tank on its side.
	void heater(int top) {
		const int x0 = std::max(1, std::min((int)std::round(w * 0.65) - 4, std::max(1, w - HEATER_W - 1)));
		const int z0 = std::max(1, std::min((int)std::round(d * 0.4) - 4, std::max(1, d - HEATER_D - 1)));
		for (int hx = 0; hx < HEATER_W; hx++) {
			const bool rail = hx % 4 == 0;
			for (int hz = 0; hz < HEATER_ROWS; hz++) {
				const int y = top + (hz >> 1);
				const bool frame = rail || hz == 0 || hz == 3 || hz == HEATER_ROWS - 1;
				put(x0 + hx, y, z0 + hz, frame ? GEAR : SOLAR);
				if (hz > 0 && hz % 2 == 0) put(x0 + hx, y - 1, z0 + hz, GEAR);
			}
			if (rail)
				for (int y = 0; y < 3; y++) put(x0 + hx, top + y, z0 + HEATER_ROWS - 1, GEAR);
		}
		for (int hx = 1; hx < HEATER_W - 1; hx++) {
			const bool cap = hx == 1 || hx == HEATER_W - 2;
			for (int hz = HEATER_ROWS - 1; hz < HEATER_D; hz++) {
				put(x0 + hx, top + 4, z0 + hz, cap ? GEAR : HEATER);
				put(x0 + hx, top + 5, z0 + hz, cap ? GEAR : HEATER_HI);
			}
		}
	}

	void mast(int top) {
		if (tier < 2) return;
		const int mx0 = w >> 1, mz0 = d >> 1;
		const int mast_h = 16 + tier * 8;
		box(mx0, top, mz0, mx0, top + mast_h, mz0, GEAR);
		box(mx0 - 2, top, mz0 - 2, mx0 + 2, top + 4, mz0 + 2, GEAR);
		for (int ring = 8; ring < mast_h; ring += 8)
			box(mx0 - 1, top + ring, mz0 - 1, mx0 + 1, top + ring, mz0 + 1, PIPE);
		mark(mx0, top + mast_h + 1, mz0, BEACON);
	}

	void stair_hut(int top) {
		if (w < 20 || d < 20) return;
		box(3, top, 3, 10, top + 6, 9, WALL);
		box(5, top, 10, 7, top + 4, 10, FRAME);
	}

	void roof() {
		const int top = h;
		for (int x = 0; x < w; x++)
			for (int z = 0; z < d; z++)
				if (x == 0 || z == 0 || x == w - 1 || z == d - 1) box(x, top, z, x, top + 1, z, TRIM);
		stair_hut(top);
		switch (arch()) {
			case OFFICE:
				ac_units(top);
				break;
			case BRICK:
				if (roll(4, 6, 8, WOODEN_ONE_IN) == 0) tower(top);
				else heater(top);
				break;
			case GLASS:
				mast(top);
				break;
			default:
				for (int step = 0; step < 3; step++)
					for (int x = 2 + step * 4; x < w - 2 - step * 4; x++)
						for (int z = 2 + step * 4; z < d - 2 - step * 4; z++)
							box(x, top + step * 2, z, x, top + step * 2 + 1, z, TRIM);
		}
		const int vents = std::clamp(bd, 1, 3);
		for (int v = 0; v < vents; v++) {
			const int ax = 2 + (int)roll(v, 5, 1, std::max(1, w - 4));
			const int az = 2 + (int)roll(v, 5, 2, std::max(1, d - 4));
			box(ax, top, az, ax, top + 3, az, VENT);
		}
	}

	void sign() {
		if (bh < 3 || arch() == GLASS || (double)roll(7, 7, 7, 1000) >= sign_chance * 1000.0) return;
		int open[4];
		int n_open = 0;
		for (int s = 0; s < 4; s++)
			if (!(party & (1 << s))) open[n_open++] = s;
		if (n_open == 0) return;
		const int side = open[roll(3, 1, 4, n_open)];
		const int top = std::min(h - 6, res * 5);
		const int colour = (int)roll(5, 9, 2, neon);
		const int length = SIDE_X[side] != 0 ? d : w;
		const int along = roll(1, 2, 3, 2) == 0 ? 4 : length - 8;
		for (int y = res + 2; y < top; y++) {
			for (int a = 0; a < 4; a++)
				for (int o = -3; o < -1; o++) {
					const bool edge = a == 0 || a == 3 || y == res + 2 || y == top - 1;
					const int band = (int)std::floor((y - res) / 3.0) % 4;
					const int key = edge || band == 3 ? SIGN_FRAME : NEON0 + (colour + band) % neon;
					mark_at(side, along + a, y, o, key);
				}
			if (arch() == OFFICE && y % res == 1) {
				mark_at(side, along, y, -1, SIGN_FRAME);
				mark_at(side, along + 3, y, -1, SIGN_FRAME);
			}
		}
	}
};

thread_local std::vector<uint8_t> cells_out;
thread_local std::vector<int32_t> removed_out;
thread_local std::vector<uint8_t> mats_out;

} // namespace

// Present only in a DLL that has the sim's calls; the sim falls back to its C# passes without it.
KC_API int kc_sim_version() { return 1; }

// KaijuSettle.floors: mass and sx, sz are count * (h + 1) long, box is count * h * 4.
KC_API void kc_floors(const int32_t *lab, const uint8_t *cells, const uint8_t *fix, int w, int h, int d, int count,
		int64_t *ms, int64_t *xs, int64_t *zs, int32_t *bx) {
	const int plan = w * d;
	const int64_t n = int64_t(w) * h * d;
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
	for (int k = 0; k < count; k++)
		for (int y = h - 1; y >= 0; y--) {
			const int64_t at = int64_t(k) * (h + 1) + y;
			ms[at] += ms[at + 1];
			xs[at] += xs[at + 1];
			zs[at] += zs[at + 1];
		}
}

// KaijuSettle.gather: out null counts the cells; otherwise writes them.
KC_API int kc_gather(const int32_t *lab, const uint8_t *cells, int n, int from, int label, int32_t *out) {
	int k = 0;
	for (int i = from; i < n; i++)
		if (lab[i] == label && cells[i] != 0) {
			if (out) out[k] = i;
			k++;
		}
	return k;
}

// KaijuSettle.land: out is 9 long and starts zeroed.
KC_API void kc_land(const int32_t *idx, int count, const uint8_t *cells, int w, int h, int d, int64_t *o) {
	const int plan = w * d;
	std::vector<int> low(size_t(plan), h);
	int64_t sx = 0, sz = 0;
	for (int k = 0; k < count; k++) {
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
	o[0] = sx;
	o[1] = sz;
	o[2] = count;
	o[3] = x0;
	o[4] = z0;
	o[5] = x1;
	o[6] = z1;
	o[7] = lands;
	o[8] = least;
}

// KaijuSettle.chunk_counts: geo [w, d, h, bw, bd]; out is `chunks` long and starts zeroed.
KC_API void kc_chunk_counts(const uint8_t *cells, int64_t n, const int32_t *cx, const int32_t *cz, const int32_t *fy,
		const int32_t *geo, int chunks, int32_t *o) {
	const int w = geo[0], d = geo[1], bw = geo[3], bd = geo[4];
	for (int64_t i = 0; i < n; i++) {
		if (cells[i] == 0) continue;
		const int ci = chunk_of(int(i), w, d, bw, bd, cx, cz, fy);
		if (ci >= 0 && ci < chunks) o[ci] += 1;
	}
}

// KaijuSettle.part_info: lv (the caller's copy of live) is updated; o is 11 long.
KC_API void kc_part_info(const int32_t *idx, int count, const uint8_t *cells, const int32_t *cx, const int32_t *cz,
		const int32_t *fy, const int32_t *geo, int32_t *lv, int32_t *o) {
	const int w = geo[0], d = geo[1], h = geo[2], bw = geo[3], bd = geo[4];
	const int plan = w * d;
	int lo[3] = { w, h, d }, hi[3] = { -1, -1, -1 };
	for (int k = 0; k < count; k++) {
		const int i = idx[k];
		lv[chunk_of(i, w, d, bw, bd, cx, cz, fy)] -= 1;
		const int c[3] = { i % w, i / plan, (i / w) % d };
		for (int a = 0; a < 3; a++) {
			lo[a] = std::min(lo[a], c[a]);
			hi[a] = std::max(hi[a], c[a]);
		}
	}
	int x0 = -1, z0 = -1, x1 = -1, z1 = -1;
	bool under = false;
	for (int k = 0; k < count; k++) {
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
}

// KaijuSettle.wear: c, wr, lv are the caller's copies, updated. Returns the cells removed, which
// kc_wear_copy hands over. nums [damage, mult, hp, weakest], ints [w, d, h, bw, bd, floors,
// offset y, res]; `even`: amounts per span instead of `at` per column.
KC_API int kc_wear(uint8_t *c, float *wr, const float *at, const float *amounts, int even, const int32_t *sp,
		int n_spans, const float *strength, const double *nums, const int32_t *ints, const int32_t *cx,
		const int32_t *cz, const int32_t *fy, int32_t *lv) {
	const int w = ints[0], d = ints[1], h = ints[2], bw = ints[3], bd = ints[4];
	const int floors = ints[5], offset_y = ints[6], res = ints[7];
	const double damage = nums[0], mult = nums[1], hp = nums[2], weakest = nums[3];
	const int plan = w * d;
	removed_out.clear();
	mats_out.clear();
	for (int64_t s = 0; s + 4 < n_spans; s += 5) {
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
						removed_out.push_back(i);
						mats_out.push_back(m);
						lv[chunk_of(i, w, d, bw, bd, cx, cz, fy)] -= 1;
					}
				}
			}
	}
	return int(removed_out.size());
}

KC_API void kc_wear_copy(int32_t *removed, uint8_t *mats) {
	std::copy(removed_out.begin(), removed_out.end(), removed);
	std::copy(mats_out.begin(), mats_out.end(), mats);
}

// KaijuSettle.beam_at: ints [w, d, offset x, offset z, res], nums [world x0, world z0, origin x,
// origin y, dir x, dir y, length, half]; a is w * d long.
KC_API void kc_beam_at(const int32_t *sp, int n_spans, const int32_t *ints, const double *nums, float *a) {
	const int w = ints[0], d = ints[1], off_x = ints[2], off_z = ints[3], res = ints[4];
	const double x0 = nums[0], z0 = nums[1], length = nums[6], half = nums[7];
	// The Vector2s are float32 in GDScript; their products and sums stay float32 (Vector2.dot).
	const float ox = float(nums[2]), oy = float(nums[3]), dx = float(nums[4]), dy = float(nums[5]);
	const double r = 0.5 / res;
	std::fill(a, a + int64_t(w) * d, -1.0f);
	for (int64_t s = 0; s + 4 < n_spans; s += 5)
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
}

// KaijuSettle.cells: ints [w, d, floors, res, style, tier, column_bay, party side bits, neon count],
// nums [x, z, sign chance]. out6 receives offset then dims. Returns the bytes kc_cells_copy hands
// over, or -1 (the caller then uses its C# generation).
KC_API int64_t kc_cells(const int32_t *in, const double *nums, const int32_t *ids, int n_ids, int32_t *out6) {
	Gen g;
	g.bw = in[0];
	g.bd = in[1];
	g.bh = in[2];
	g.res = in[3];
	g.style = in[4];
	g.tier = in[5];
	g.bay = std::max(1, (int)in[6]);
	g.party = in[7];
	g.neon = in[8];
	if (g.res <= 0 || g.bw <= 0 || g.bd <= 0 || g.bh <= 0 || g.neon <= 0 || n_ids < KEY_COUNT + g.neon - 1) return -1;
	g.w = g.bw * g.res;
	g.d = g.bd * g.res;
	g.h = g.bh * g.res;
	g.pos = (int64_t)std::round(nums[0] * 13.0 + nums[1]);
	g.sign_chance = nums[2];
	g.ids = ids;
	g.nids = n_ids;
	// Margin: signs and awnings stand 3 proud, roof gear and the mast stand above the roof.
	const int margin = 16;
	g.mx = margin;
	g.mz = margin;
	g.gx = g.w + 2 * margin;
	g.gz = g.d + 2 * margin;
	g.gy = g.h + 32 + 8 * std::max(0, g.tier);
	g.grid.assign((size_t)g.gx * g.gy * g.gz, 0);
	// _pack's box starts as the shell.
	g.lo[0] = g.lo[1] = g.lo[2] = 0;
	g.hi[0] = g.w - 1;
	g.hi[1] = g.h - 1;
	g.hi[2] = g.d - 1;
	for (int side = 0; side < 4; side++) g.face(side);
	g.frame();
	g.slabs();
	g.roof();
	g.sign();
	if (g.out) return -1;
	const int dx = g.hi[0] - g.lo[0] + 1, dy = g.hi[1] - g.lo[1] + 1, dz = g.hi[2] - g.lo[2] + 1;
	for (int a = 0; a < 3; a++) out6[a] = g.lo[a];
	out6[3] = dx;
	out6[4] = dy;
	out6[5] = dz;
	cells_out.resize((size_t)dx * dy * dz);
	for (int y = 0; y < dy; y++) {
		const int ly = y + g.lo[1];
		for (int z = 0; z < dz; z++) {
			const int az = z + g.lo[2] + g.mz;
			const uint8_t *src = g.grid.data() + (size_t)(g.lo[0] + g.mx) + (size_t)az * g.gx + (size_t)ly * g.gx * g.gz;
			std::copy(src, src + dx, cells_out.data() + (size_t)z * dx + (size_t)y * dx * dz);
		}
	}
	return (int64_t)cells_out.size();
}

KC_API void kc_cells_copy(uint8_t *dst) {
	std::copy(cells_out.begin(), cells_out.end(), dst);
}

// KaijuWater.step: `subs` sub-steps over window (rx, ry, rw, rh); d and f are the caller's copies of
// depth and flow, updated. Returns stir. Sums and products in doubles, columns stored in floats.
KC_API double kc_water_step(const float *fl, float *d, const float *body, float *f, int64_t n, int64_t nx, int rx,
		int ry, int rw, int rh, int64_t subs, double h, double keep, double g, double cell, double rest, int open) {
	const int64_t nz = n / nx;
	const int64_t x0 = std::max<int64_t>(0, rx);
	const int64_t y0 = std::max<int64_t>(0, ry);
	const int64_t x1 = std::min<int64_t>(nx, int64_t(rx) + rw) - 1; // last column
	const int64_t y1 = std::min<int64_t>(nz, int64_t(ry) + rh) - 1;
	double stir = 0.0;
	if (x1 < x0 || y1 < y0) return stir;
	std::vector<float> top(fl, fl + n); // floor_y.duplicate()
	for (int64_t s = 0; s < subs; s++) {
		// _pipes: the surface over the window
		for (int64_t j = y0; j <= y1; j++)
			for (int64_t k = j * nx + x0; k <= j * nx + x1; k++)
				top[k] = (float)((double)fl[k] + ((double)d[k] + (double)body[k]));
		// _outflow: each column's four outflows
		for (int64_t j = y0; j <= y1; j++)
			for (int64_t i = x0; i <= x1; i++) {
				const int64_t k = j * nx + i;
				const int64_t e = k * 4;
				const double dk = d[k];
				if (dk <= 0.0) {
					f[e] = f[e + 1] = f[e + 2] = f[e + 3] = 0.0f;
					continue;
				}
				const double t = top[k];
				const double a = h * g / cell * dk;
				const double qr = i < x1 ? maxd(0.0, (double)f[e] * keep + a * (t - (double)top[k + 1])) : 0.0;
				const double ql = i > x0 ? maxd(0.0, (double)f[e + 1] * keep + a * (t - (double)top[k - 1])) : 0.0;
				const double qd = j < y1 ? maxd(0.0, (double)f[e + 2] * keep + a * (t - (double)top[k + nx])) : 0.0;
				const double qu = j > y0 ? maxd(0.0, (double)f[e + 3] * keep + a * (t - (double)top[k - nx])) : 0.0;
				const double out = (qr + ql + qd + qu) * h;
				double scale = 1.0;
				if (out > dk * cell) { // never more than it holds
					scale = dk * cell / out;
				}
				f[e] = (float)(qr * scale);
				f[e + 1] = (float)(ql * scale);
				f[e + 2] = (float)(qd * scale);
				f[e + 3] = (float)(qu * scale);
			}
		// _drain: the flows into the columns
		const double gain = h / cell;
		stir = 0.0;
		for (int64_t j = y0; j <= y1; j++)
			for (int64_t i = x0; i <= x1; i++) {
				const int64_t k = j * nx + i;
				const int64_t e = k * 4;
				double net = -((double)f[e] + (double)f[e + 1] + (double)f[e + 2] + (double)f[e + 3]);
				if (i > x0) net += (double)f[e - 4];
				if (i < x1) net += (double)f[e + 5];
				if (j > y0) net += (double)f[e - nx * 4 + 2];
				if (j < y1) net += (double)f[e + nx * 4 + 3];
				if (net == 0.0 && (double)d[k] <= 0.0) continue;
				d[k] = (float)maxd(0.0, (double)d[k] + gain * net);
				if ((double)d[k] > 0.0) stir = maxd(stir, std::fabs((double)fl[k] + (double)d[k] - rest));
			}
		// _open: the mouth row runs out to sea at the wave's own speed (sqrt(g d) x its lift)
		if (open && y0 == 0)
			for (int64_t k = x0; k <= x1; k++) {
				if ((double)d[k] <= 0.0) continue;
				const double lift = (double)fl[k] + (double)d[k] - rest;
				d[k] = (float)maxd(0.0, (double)d[k] - gain * std::sqrt(g * (double)d[k]) * lift);
			}
	}
	return stir;
}
