class_name BridgeLayout
extends RefCounted
## The river bridges as voxel structures (D-389; the director 2026-10-30: carve is universal,
## "Carve, spans drop", "Keep deck, add piers"). Each cross street's deck over the river
## (CityRiver.bridges) is cut along the river into pieces about span long, each a building in
## the city's list (RampageSim.Building with `bridge` set): an asphalt deck slab with its top at
## street level, a stone parapet along each side, and a stone pier wall down to the riverbed at
## each end (half a pier where two pieces meet, an abutment at each bank). Below the street: a
## piece's local floor 0 is the riverbed, `bed` whole floors under the street (Building.base), so
## its grid stands on layer 0 like any building's (VoxelFrame's ground), the piers are what
## holds it there, and whatever falls lands on the riverbed, under the water. A deck stretch cut
## off its piers is a part with nothing under it: it drops, or tips off the pier it still hangs
## from, into the river (VoxelSupport's rules, as for any building). The cells are laid here once,
## for the sim's grid (BuildingCells) and the view's voxels (BridgeVoxels) alike, in
## building-local cells (RES per sim unit) over a box on whole world units. Pure sim; sizes:
## tuning bridge.

## Laid pieces by key: [cells (Vector3i -> material name), chunk layers].
static var _cache: Dictionary = {}
static var _lock := Mutex.new()


## The layout entries (CityGen's shape, plus "chunks" and "bridge") of every bridge's pieces,
## west to east, each north to south. A piece's box is its deck's on whole world units; "x" and
## "z" in `bridge` are the deck's own edges, which its cells fill.
static func pieces(city: Dictionary, cfg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not city.get("river", false):
		return out
	var parapet: Array = cfg["parapet"]
	var bed := Num.i(cfg["bed"])
	for deck: Rect2 in CityRiver.bridges(CityGen.map(city), city):
		var n := maxi(1, roundi(deck.size.y / Num.f(cfg["span"])))
		var long := deck.size.y / n
		var x0 := floorf(deck.position.x)
		var w := ceili(deck.end.x) - roundi(x0)
		for k: int in n:
			var za := deck.position.y + long * k
			var zb := za + long
			var z0 := floorf(za)
			var d := ceili(zb) - roundi(z0)
			var entry := {
				"x": x0 + w * 0.5,
				"z": z0 + d * 0.5,
				"w": w,
				"d": d,
				"h": ceili(bed + Num.f(parapet[0])),
				"tier": Num.i(cfg["tier"]),
				"style": 0,
				"bridge":
				{
					"piece": k,
					"of": n,
					"x": [deck.position.x, deck.end.x],
					"z": [za, zb],
				},
			}
			entry["chunks"] = laid(_building(entry, bed), cfg, CellGrid.cell_res())[1]
			out.append(entry)
	return out


## Appends the bridges' pieces to the sim's buildings (built like the city).
## Returns the index of the first piece.
static func add_pieces(
	buildings: Array[RampageSim.Building], city: Dictionary, cfg: Dictionary
) -> int:
	var first := buildings.size()
	for entry: Dictionary in pieces(city, cfg):
		var b := Landmarks.building(entry, Num.f(city["chunk_hp"]))
		b.bridge = entry["bridge"]
		b.base = -Num.i(cfg["bed"])
		b.start_chunks = b.frame.alive_count
		b.in_arena = false  # it breaks and pays, but the city's fall is its lots (CityBand's rule)
		buildings.append(b)
	return first


static func _building(entry: Dictionary, bed: int) -> RampageSim.Building:
	var b := RampageSim.Building.new()
	b.x = Num.f(entry["x"])
	b.z = Num.f(entry["z"])
	b.w = Num.i(entry["w"])
	b.d = Num.i(entry["d"])
	b.height = Num.i(entry["h"])
	b.bridge = entry["bridge"]
	b.base = -bed
	return b


## A piece's cells (building-local, `res` per sim unit) -> material name, and the chunk layers
## its Structure keeps (Structure.keep's shape: a "1" per chunk holding any cell). Laid once per
## piece and shared: callers must not change them.
static func laid(b: RampageSim.Building, cfg: Dictionary, res: int) -> Array:
	var key := "%s|%s|%d|%d|%d|%s|%d" % [b.x, b.z, b.w, b.d, b.height, str(b.bridge), res]
	_lock.lock()
	var kept: Array = _cache.get(key, [])
	_lock.unlock()
	if not kept.is_empty():
		return kept
	var cells := _lay(b, cfg, res)
	var layers: Array = []
	for y: int in b.height:
		layers.append("0".repeat(b.w * b.d))
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


## Every column whose centre lies on the deck: a pier (or abutment) column from the riverbed up
## at the piece's ends, else the slab under the street; the asphalt on top of both, a parapet
## over the deck's edges.
static func _lay(b: RampageSim.Building, cfg: Dictionary, res: int) -> Dictionary:
	var r := float(res)
	var xs: Array = b.bridge["x"]
	var zs: Array = b.bridge["z"]
	var left := b.x - b.w * 0.5
	var north := b.z - b.d * 0.5
	var x_span := Vector2(Num.f(xs[0]) - left, Num.f(xs[1]) - left) * r
	var z_lo := (Num.f(zs[0]) - north) * r
	var z_hi := (Num.f(zs[1]) - north) * r
	var piece := Num.i(b.bridge["piece"])
	var last := Num.i(b.bridge["of"]) - 1
	var half_pier := Num.f(cfg["pier"]) * 0.5 * r
	var abut := Num.f(cfg["abutment"]) * r
	var ends := Vector2(abut if piece == 0 else half_pier, abut if piece == last else half_pier)
	var out := {}
	for cz: int in b.d * res:
		var z := cz + 0.5
		if z >= z_lo and z < z_hi:
			var pier := z < z_lo + ends.x or z >= z_hi - ends.y
			_row(out, Vector3i(cz, b.w * res, res), x_span, pier, cfg)
	return out


## One row across the deck at local z cell at.x (at.y cells wide, at.z cells a unit), the deck's
## own edges at x_span (local cells): every column on it, from the riverbed where a pier stands.
static func _row(
	out: Dictionary, at: Vector3i, x_span: Vector2, pier: bool, cfg: Dictionary
) -> void:
	var res := at.z
	var top := Num.i(cfg["bed"]) * res  # the street's level, in cells over the riverbed
	var slab := maxi(1, roundi(Num.f(cfg["slab"]) * res))
	var parapet: Array = cfg["parapet"]
	var rail_h := roundi(Num.f(parapet[0]) * res)
	var rail_w := Num.f(parapet[1]) * res
	for cx: int in at.y:
		var x := cx + 0.5
		if x < x_span.x or x >= x_span.y:
			continue
		for y: int in range(0 if pier else top - slab, top):
			out[Vector3i(cx, y, at.x)] = "bridge_deck" if y == top - 1 else "bridge_pier"
		if x < x_span.x + rail_w or x >= x_span.y - rail_w:
			for y: int in range(top, top + rail_h):
				out[Vector3i(cx, y, at.x)] = "bridge_parapet"
