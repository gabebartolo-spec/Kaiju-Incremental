class_name RailLayout
extends RefCounted
## The railway's viaduct and station as voxel structures (D-247; the director 2026-10-25 "it needs
## to be destroyed with the same logic as all other buildings", 2026-10-26 "carve is a universal
## feature for all buildings"). The line is cut into pieces of piece_bays bays, each a building in
## the city's list (RampageSim.Building with `rail` set): column bents every bay_length under a
## concrete deck slab with parapets, ballast, sleepers and two rails per track; the pieces round
## the station also carry its platforms, canopy on posts, a sign and stairs to the street. The
## cells are laid here once, for the sim's grid (BuildingCells) and the view's voxels
## (RailVoxels) alike, in building-local cells (RES per sim unit), so they carve, settle, fall and
## pay by the very rules every building does (Carving, VoxelFrame, Collapse). Pure sim; sizes:
## tuning rail.structure.

## Laid pieces by key: [cells (Vector3i -> material name), chunk layers].
static var _cache: Dictionary = {}
static var _lock := Mutex.new()


## The line's north and south ends (world z).
static func ends(city: Dictionary, cfg: Dictionary) -> Vector2:
	var half := CityGen.half_extent(city)
	var span: Array = cfg["span"]
	return Vector2(half * Num.f(span[0]), half * Num.f(span[1]))


## The station's platforms along the line (world z): a train's length and a little, round the
## station stop (the north-bound stop; both tracks share the platforms).
static func station_z(city: Dictionary, cfg: Dictionary) -> Vector2:
	var line := ends(city, cfg)
	var at := line.x + (line.y - line.x) * Num.f(cfg["station_share"])
	var long := Num.i(cfg["cars"]) * (Num.f(cfg["car_length"]) + 0.3) + 2.0
	return Vector2(at - long * 0.5, at + long * 0.5)


## The layout entries (CityGen's shape, plus "chunks" and "rail") of the line's pieces, north to
## south: whole pieces aligned to multiples of piece_bays x bay_length on z, covering the line.
static func pieces(city: Dictionary, cfg: Dictionary) -> Array[Dictionary]:
	var s: Dictionary = cfg["structure"]
	var line := ends(city, cfg)
	var long := Num.f(cfg["bay_length"]) * Num.i(cfg["piece_bays"])
	var st := station_z(city, cfg)
	var deck := Num.f(cfg["deck_width"])
	var plat := Num.f(s["platform"]) + Num.f(s["stair"])
	var parapet: Array = s["parapet"]
	var out: Array[Dictionary] = []
	for k: int in range(floori(line.x / long), ceili(line.y / long)):
		var a := k * long
		var station := minf(st.y, a + long) - maxf(st.x, a) >= 1.0  # a sliver carries none
		var top := Num.f(cfg["deck_y"]) + (Num.f(s["canopy"]) if station else Num.f(parapet[0]))
		var entry := {
			"x": Rail.avenue_x(city),
			"z": a + long * 0.5,
			"w": ceili(deck + plat * 2.0) if station else ceili(deck),
			"d": roundi(long),
			"h": ceili(top + 0.25),
			"tier": Num.i(s["tier"]),
			"style": 0,
			"rail": {"piece": k, "station": [st.x, st.y] if station else []},
		}
		entry["chunks"] = laid(_building(entry), cfg, CellGrid.cell_res())[1]
		out.append(entry)
	return out


## Appends the railway's pieces to the sim's buildings (the viaduct is built like the city); returns the first index.
static func add_pieces(buildings: Array[RampageSim.Building], city: Dictionary, cfg: Dictionary) -> int:
	var first := buildings.size()
	for entry: Dictionary in pieces(city, cfg):
		var b := Landmarks.building(entry, Num.f(city["chunk_hp"]))
		b.rail = entry["rail"]
		b.start_chunks = b.frame.alive_count
		b.in_arena = false  # it breaks and pays, but the city's fall is its lots (CityBand's rule)
		buildings.append(b)
	return first


static func _building(entry: Dictionary) -> RampageSim.Building:
	var b := RampageSim.Building.new()
	b.x = Num.f(entry["x"])
	b.z = Num.f(entry["z"])
	b.w = Num.i(entry["w"])
	b.d = Num.i(entry["d"])
	b.height = Num.i(entry["h"])
	b.rail = entry["rail"]
	return b


## Where along the line (from its north end) piece b's deck is gone under a track: every
## stretch (one sim unit) whose deck chunk under either track has left the chunk mirror (Carving:
## at most chunk_alive_share of its cells are left).
static func deck_gaps(b: RampageSim.Building, rail: Rail) -> Array[float]:
	var out: Array[float] = []
	var deck_floor := floori(Num.f(rail.cfg["deck_y"]))
	var north := rail.point(0.0, 1).y
	for dir: int in [1, -1]:
		var cx := clampi(floori(rail.track_x(dir) - (b.x - b.w * 0.5)), 0, b.w - 1)
		for cz: int in b.d:
			var s := b.z - b.d * 0.5 + cz + 0.5 - north
			if s >= 0.0 and s <= rail.length and not b.frame.alive(Vector3i(cx, deck_floor, cz)):
				out.append(s)
	return out


## A piece's cells (building-local, `res` per sim unit) -> material name, and the chunk layers
## its Structure keeps (Structure.keep's shape: a "1" per chunk holding any cell). Laid once per
## piece and shared: callers must not change them.
static func laid(b: RampageSim.Building, cfg: Dictionary, res: int) -> Array:
	var key := "%s|%s|%d|%d|%d|%s|%d" % [b.x, b.z, b.w, b.d, b.height, str(b.rail), res]
	_lock.lock()
	var kept: Array = _cache.get(key, [])
	_lock.unlock()
	if not kept.is_empty():
		return kept
	var cells := _lay(b, cfg, res)
	var layers: Array = []
	for y: int in b.height:
		var row := "0".repeat(b.w * b.d)
		layers.append(row)
	for c: Vector3i in cells:
		var y := c.y / res
		var k := c.x / res + (c.z / res) * b.w
		var row: String = layers[y]
		if row[k] != "1":
			layers[y] = row.substr(0, k) + "1" + row.substr(k + 1)
	kept = [cells, layers]
	_lock.lock()
	_cache[key] = kept
	_lock.unlock()
	return kept


static func _lay(b: RampageSim.Building, cfg: Dictionary, res: int) -> Dictionary:
	var g := _Geometry.new(b, cfg, res)
	var out := {}
	for cz: int in g.nz:
		var zw := g.z_cell0 + cz
		var bent := g.bent_at(cz)
		var in_station := g.station(cz)
		for cx: int in g.nx:
			var dx := cx + 0.5 - g.mid
			var ax := absf(dx)
			if ax <= g.deck_half:
				_deck_column(g, out, Vector2i(cx, cz), dx, zw, in_station)
				if bent:
					_bent_column(g, out, Vector2i(cx, cz), ax)
			elif in_station and ax <= g.deck_half + g.platform + g.stair:
				_station_column(g, out, Vector2i(cx, cz), ax, cz)
	return out


## One column of the deck: the slab (seams across it), parapets at the edges outside the
## station, ballast with sleepers and two rails per track on top.
static func _deck_column(
	g: _Geometry, out: Dictionary, at: Vector2i, dx: float, zw: int, in_station: bool
) -> void:
	var seam := posmod(zw, g.seam_every) == 0
	for y: int in range(g.top - g.slab + 1, g.top + 1):
		out[Vector3i(at.x, y, at.y)] = "viaduct_seam" if seam else "viaduct_concrete"
	var ax := absf(dx)
	if ax > g.deck_half - g.parapet_w:
		if not in_station:
			for y: int in range(g.top + 1, g.top + 1 + g.parapet_h):
				out[Vector3i(at.x, y, at.y)] = "viaduct_parapet"
		return
	for t: float in [-g.track, g.track]:
		var e := absf(dx - t)
		if e > g.ballast:
			continue
		var sleeper := posmod(zw, g.sleeper_every) == 0
		out[Vector3i(at.x, g.top + 1, at.y)] = "viaduct_sleeper" if sleeper else "viaduct_ballast"
		if absf(e - g.rail) < 0.5:
			out[Vector3i(at.x, g.top + 2, at.y)] = "viaduct_rail"


## A bent under the deck: a cap beam across it and two square columns down to the street.
static func _bent_column(g: _Geometry, out: Dictionary, at: Vector2i, ax: float) -> void:
	var cap_lo := g.top - g.slab + 1 - g.cap
	if ax <= g.deck_half - g.parapet_w:
		for y: int in range(cap_lo, cap_lo + g.cap):
			out[Vector3i(at.x, y, at.y)] = "viaduct_column"
	if absf(ax - g.column_x) < g.column * 0.5:
		for y: int in cap_lo:
			out[Vector3i(at.x, y, at.y)] = "viaduct_seam" if y % g.res == 0 else "viaduct_column"


## Beside the deck at the station: a platform (its edge by the tracks), the canopy over it on
## posts along its outer edge, the sign under the canopy at the middle, the stairs at its end.
static func _station_column(
	g: _Geometry, out: Dictionary, at: Vector2i, ax: float, cz: int
) -> void:
	var w := ax - g.deck_half
	if w <= g.platform:
		var edge := w < 1.0
		for y: int in range(g.top - 1, g.top + 1):
			var pave := "station_platform" if posmod(cz + int(w), 4) != 0 else "viaduct_seam"
			out[Vector3i(at.x, y, at.y)] = "station_edge" if edge and y == g.top else pave
		var rib := posmod(g.z_cell0 + cz, g.res) == 0
		out[Vector3i(at.x, g.canopy, at.y)] = "station_rib" if rib else "station_canopy"
		var outer := w > g.platform - 1.0
		if outer and posmod(g.z_cell0 + cz, g.post_every) == 0:
			for y: int in range(g.top + 1, g.canopy):
				out[Vector3i(at.x, y, at.y)] = "viaduct_column"
		elif outer and absf(cz - g.station_mid) <= g.res:
			for y: int in range(g.canopy - 2, g.canopy):
				out[Vector3i(at.x, y, at.y)] = "station_sign"
		return
	# The stairs, past the platform at the station's south end: two cells per step so each
	# touches the next by a face (the support flood is face-connected).
	var rise := g.station_end - cz
	for y: int in [rise - 1, rise]:
		if y >= 0 and y <= g.top:
			out[Vector3i(at.x, y, at.y)] = "station_stair"


## A piece's sizes in cells.
class _Geometry:
	var res: int
	var nx: int
	var nz: int
	var mid: float
	var z_cell0: int
	var deck_half: float
	var top: int
	var slab: int
	var parapet_h: int
	var parapet_w: float
	var track: float
	var ballast: float
	var rail: float
	var sleeper_every: int
	var seam_every: int
	var column: float
	var column_x: float
	var cap: int
	var platform: float
	var stair: float
	var canopy: int
	var post_every: int
	## Bent z ranges in local cells ([from, to) pairs), the station's local z range and middle,
	## and its south end (local cells; past nz when it ends beyond this piece).
	var bents := PackedInt32Array()
	var station_lo := 0
	var station_hi := -1
	var station_mid := -1000.0
	var station_end := -1000

	func _init(b: RampageSim.Building, cfg: Dictionary, p_res: int) -> void:
		var s: Dictionary = cfg["structure"]
		res = p_res
		var r := float(res)
		nx = b.w * res
		nz = b.d * res
		mid = nx * 0.5
		var z0 := b.z - b.d * 0.5
		z_cell0 = roundi(z0 * r)
		deck_half = Num.f(cfg["deck_width"]) * 0.5 * r
		top = roundi(Num.f(cfg["deck_y"]) * r) + 1
		slab = roundi(Num.f(s["slab"]) * r)
		var parapet: Array = s["parapet"]
		parapet_h = roundi(Num.f(parapet[0]) * r)
		parapet_w = Num.f(parapet[1]) * r
		track = Num.f(cfg["track_gap"]) * 0.5 * r
		ballast = Num.f(s["ballast_half"]) * r
		rail = Num.f(s["rail_offset"]) * r
		sleeper_every = maxi(1, roundi(Num.f(s["sleeper_every"]) * r))
		seam_every = maxi(1, roundi(Num.f(s["seam_every"]) * r))
		column = Num.f(s["column"]) * r
		column_x = deck_half - Num.f(s["column_inset"]) * r
		cap = roundi(Num.f(s["cap"]) * r)
		platform = Num.f(s["platform"]) * r
		stair = Num.f(s["stair"]) * r
		canopy = roundi((Num.f(cfg["deck_y"]) + Num.f(s["canopy"])) * r)
		post_every = maxi(1, roundi(Num.f(s["post_every"]) * r))
		var bay := Num.f(cfg["bay_length"])
		var col := roundi(Num.f(s["column"]) * r)
		for j: int in range(ceili(z0 / bay - 0.001), floori((z0 + b.d) / bay + 0.001) + 1):
			var at := roundi((j * bay - z0) * r)
			var lo := clampi(at - col / 2, 0, nz - col)
			bents.append_array([lo, lo + col])
		var st: Array = b.rail.get("station", [])
		if not st.is_empty():
			station_lo = roundi((Num.f(st[0]) - z0) * r)
			station_hi = roundi((Num.f(st[1]) - z0) * r)
			station_mid = (station_lo + station_hi) * 0.5
			station_end = station_hi - 1

	func bent_at(cz: int) -> bool:
		for i: int in range(0, bents.size(), 2):
			if cz >= bents[i] and cz < bents[i + 1]:
				return true
		return false

	func station(cz: int) -> bool:
		return cz >= station_lo and cz < station_hi
