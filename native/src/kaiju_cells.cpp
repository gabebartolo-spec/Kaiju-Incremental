// KaijuSettle.cells (b2-3 part 4): BuildingLayout's generation (sim/building_layout.gd, packed by
// BuildingCells, with GlassFrame's columns), which costs a big building 100-170 ms in GDScript.
// Every face, slab, roof and sign mark below is the GDScript's, in the same order, so the last
// write wins the same way; the layout rolls hash the same Vector4i through the engine's Variant
// hash, and the water tower's rings are whole-cell squared distances, exact in both. The GDScript
// stays the reference:
// tests/run_cells_tests.gd (_check_native_cells) holds the two to the same bytes. Marks go into a
// flat grid with a margin round the shell; the result is cropped to the box BuildingCells._pack
// gives. A mark outside the margin returns an empty Array and the caller uses the GDScript.
#include "kaiju_settle.h"
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector4i.hpp>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <vector>

using namespace godot;

namespace {

// Material keys, in BuildingCellsNative.KEYS order (the ids argument).
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
		const int64_t hv = (int64_t)Variant(Vector4i(x, y, z, (int32_t)pos)).hash();
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

} // namespace

Array KaijuSettle::cells(const PackedInt32Array &p_ints, const PackedFloat64Array &p_nums,
		const PackedInt32Array &p_ids) const {
	Array result;
	if (p_ints.size() < 9 || p_nums.size() < 3) return result;
	const int32_t *in = p_ints.ptr();
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
	if (g.res <= 0 || g.bw <= 0 || g.bd <= 0 || g.bh <= 0 || g.neon <= 0 || p_ids.size() < KEY_COUNT + g.neon - 1)
		return result;
	g.w = g.bw * g.res;
	g.d = g.bd * g.res;
	g.h = g.bh * g.res;
	g.pos = (int64_t)std::round(p_nums[0] * 13.0 + p_nums[1]);
	g.sign_chance = p_nums[2];
	g.ids = p_ids.ptr();
	g.nids = (int)p_ids.size();
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
	if (g.out) return result;
	const Vector3i offset(g.lo[0], g.lo[1], g.lo[2]);
	const Vector3i dims(g.hi[0] - g.lo[0] + 1, g.hi[1] - g.lo[1] + 1, g.hi[2] - g.lo[2] + 1);
	PackedByteArray cells;
	cells.resize((int64_t)dims.x * dims.y * dims.z);
	uint8_t *dst = cells.ptrw();
	for (int y = 0; y < dims.y; y++) {
		const int ly = y + offset.y;
		for (int z = 0; z < dims.z; z++) {
			const int az = z + offset.z + g.mz;
			const uint8_t *src = g.grid.data() + (size_t)(offset.x + g.mx) + (size_t)az * g.gx +
					(size_t)ly * g.gx * g.gz;
			std::copy(src, src + dims.x, dst + (size_t)z * dims.x + (size_t)y * dims.x * dims.z);
		}
	}
	result.append(offset);
	result.append(dims);
	result.append(cells);
	return result;
}
