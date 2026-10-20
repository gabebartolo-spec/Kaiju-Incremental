class_name BuildingVoxels
extends RefCounted
## Builds one building's fine voxels from its sim footprint: RES cells per sim unit, so each
## sim layer (one floor) is RES cells tall and each unit of facade is one bay RES cells wide.
## Facades have depth: windows sit one cell back in their reveals behind proud sills and
## lintels; piers, spandrels, mullions and transoms frame them. Four archetypes: office
## (ribbon windows over spandrel bands, AC plant), brick residential (punched windows, balconies
## with railings, water tank), glass tower (flush curtain wall, mast with beacon), stone classic
## (pilasters, cornices and string courses, stepped roof). Ground floors are shopfronts under a
## sign band and an awning. A side shared with a neighbour is a blank party wall; some shops hang
## a vertical neon sign off a street face (Tokyo). Hollow shell plus a floor slab per floor, so a
## broken building shows its floors.

const RES := 8
const VOXEL := 1.0 / RES
const OFFICE := 0
const BRICK := 1
const GLASS := 2
const STONE := 3
const AWNINGS: Array[Color] = [Color("7d4636"), Color("3f5a4a"), Color("6a5a3a"), Color("4a4f66")]
const NEON: Array[Color] = [Color("ff4f8b"), Color("4fd8ff"), Color("ffb347"), Color("8dff6a")]
const SIGN_BANDS: Array[Color] = [
	Color("2a2f3a"), Color("5a2a26"), Color("2e4a3a"), Color("3a3a3a")
]
const SIGN_CHANCE := 0.3
## Sides, as the outward step in cells: -x, +x, -z, +z.
const SIDES: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

var vox := VoxelBuilder.new()
var palette: Dictionary = {}
var b: RampageSim.Building
var _w: int
var _d: int
var _h: int
var _lit_chance: float
## Side -> floors of it a neighbour covers: blank party wall up to there, facade above.
var _party: Dictionary = {}


## party: side (from SIDES) -> floors of that side a touching neighbour covers. facade: false
## leaves `vox` empty for a subclass to fill (LandmarkVoxels).
func _init(
	p_building: RampageSim.Building, base: Color, party: Dictionary = {}, facade: bool = true
) -> void:
	b = p_building
	_party = party
	_w = b.w * RES
	_d = b.d * RES
	_h = b.height * RES
	_lit_chance = Look.value("window_lit")
	_make_palette(base)
	if not facade:
		return
	for side: Vector2i in SIDES:
		_face(side)
	_frame()
	_slabs()
	_roof()
	_sign()


## Which faces of `cell` BuildingMesher draws, one bit per BuildingMesher.NEIGHBOURS entry; -1:
## any face open to air, with the standing building's hollow counted as solid.
func face_mask(_cell: Vector3i) -> int:
	return -1


func archetype() -> int:
	return b.style % 4


## World position of cell (0, 0, 0)'s centre column.
func origin() -> Vector3:
	return Vector3(b.x - b.w * 0.5 + VOXEL * 0.5, 0.0, b.z - b.d * 0.5 + VOXEL * 0.5)


func _make_palette(base: Color) -> void:
	var lit := Look.color("window_lit_color")
	lit.a = 0.0 if Look.value("window_glow") > 0.0 else 1.0
	var shop_lit := Color("ffd9a0")
	shop_lit.a = lit.a
	palette = {
		"wall": base,
		"pillar": base.darkened(0.1),
		"trim": base.lightened(0.16),
		"sill": base.lightened(0.28),
		"window": Look.color("window"),
		"frame": base.darkened(0.3),
		"lit": lit,
		"glass": Look.color("window").lerp(base, 0.3).lightened(0.1),
		"mullion": base.darkened(0.45),
		"spandrel": base.darkened(0.18),
		"party": base.darkened(0.06),
		"shop": Color("1e2429"),
		"shop_lit": shop_lit,
		"awning": AWNINGS[posmod(roundi(b.x + b.z * 3.0), AWNINGS.size())],
		"band": SIGN_BANDS[posmod(roundi(b.x * 7.0 + b.z), SIGN_BANDS.size())],
		"rail": Color("2a2c2e"),
		"slab": Color("8a8780"),
		"roof": Look.color("roof"),
		"gear": Color("a9aaa4"),
		"vent": Color("3a3c3e"),
		"pipe": Color("6b6f72"),
		"tank": Color("6a5040"),
		"beacon": Color(1.0, 0.25, 0.2, 0.0),
		"sign_frame": Color("1c1e22"),
	}
	for i: int in NEON.size():
		var neon := NEON[i]
		neon.a = 0.0
		palette["neon%d" % i] = neon


func _roll(cell: Vector3i, mod: int) -> int:
	return absi(hash(Vector4i(cell.x, cell.y, cell.z, roundi(b.x * 13.0 + b.z)))) % mod


## The cell `layer` cells in from the face (0 = the wall plane, -1 proud, 1 recessed) at
## position p along the face and height y.
func _at(side: Vector2i, p: int, y: int, layer: int) -> Vector3i:
	if side.x < 0:
		return Vector3i(layer, y, p)
	if side.x > 0:
		return Vector3i(_w - 1 - layer, y, p)
	if side.y < 0:
		return Vector3i(p, y, layer)
	return Vector3i(p, y, _d - 1 - layer)


## One face: the wall plane, recessed glass, and what stands proud of it.
func _face(side: Vector2i) -> void:
	var length := _d if side.x != 0 else _w
	for y: int in _h:
		for p: int in length:
			if p == 0 or p == length - 1:  # corner piers are shared by two faces
				vox.put(_at(side, p, y, 0), "pillar")
				continue
			var spec := _ground(y, p) if y < RES else _upper(y, p)
			var plane: String = spec[0]
			if plane == "recess":
				vox.put(_at(side, p, y, 1), _lit_or(spec[1], side, p, y))
			else:
				vox.put(_at(side, p, y, 0), plane)
			var proud: String = spec[2]
			if proud != "":
				vox.put(_at(side, p, y, -1), proud)
			var further: String = spec[3]
			if further != "":
				vox.put(_at(side, p, y, -2), further)


## A window lights as a whole: one roll per window (its bay and floor).
func _lit_or(key: String, side: Vector2i, p: int, y: int) -> String:
	var window := Vector3i(floori(float(p) / RES), floori(float(y) / RES), side.x * 3 + side.y)
	if _roll(window, 1000) < _lit_chance * 1000.0:
		return "shop_lit" if key == "shop" else "lit"
	return key


## Ground floor, as [plane, recessed key, proud, further proud]: shop windows between piers,
## a sign band, an awning reaching out over the pavement.
func _ground(y: int, p: int) -> Array[String]:
	var q := p % RES
	if y == RES - 1:
		return ["trim", "", "awning", "awning"]
	if y == RES - 2:
		return ["band", "", "band", ""]
	if q == 0:
		return ["pillar", "", "", ""]
	if y == 0:
		return ["pillar", "", "", ""]  # the stall riser under the glass
	return ["recess", "shop", "", ""]


## Upper floors by archetype, as [plane, recessed key, proud, further proud].
## r: row within the floor (0 = the slab line), q: column within the bay.
func _upper(y: int, p: int) -> Array[String]:
	var r := y % RES
	var q := p % RES
	var top_row := y >= _h - 2
	match archetype():
		OFFICE:
			return _office(r, q, top_row)
		BRICK:
			return _brick(r, q, floori(float(y) / RES))
		GLASS:
			if q == 0 or r == 0:
				return ["mullion", "", "", ""]
			if r == 4:
				return ["frame", "", "", ""]  # transom
			return ["lit" if _lit_cell(p, y) else "glass", "", "", ""]
	return _stone(r, q, top_row or (r == 0 and floori(float(y) / RES) % 5 == 0), top_row)


## Ribbon windows over spandrels, slim mullions, a transom.
func _office(r: int, q: int, top_row: bool) -> Array[String]:
	if r <= 1:
		return ["spandrel" if r == 1 else "trim", "", "", ""]
	if top_row:
		return ["trim", "", "trim", ""]
	if q == 0:
		return ["pillar", "", "", ""]
	if r == 7:
		return ["frame", "", "", ""]
	return ["recess", "mullion" if q == 4 or r == 5 else "window", "", ""]


## Punched windows with sills and lintels; a balcony with a railing every other floor.
func _brick(r: int, q: int, floor_n: int) -> Array[String]:
	var balcony := floor_n % 2 == 0 and q >= 1 and q <= 6
	if q >= 2 and q <= 5 and r >= 2 and r <= 6:
		return ["recess", "mullion" if r == 4 else "window", "", ""]
	if r == 7 and q >= 2 and q <= 5:
		return ["frame", "", "frame", ""]  # lintel
	if r == 1 and q >= 1 and q <= 6:
		return ["wall", "", "rail" if balcony else "sill", "rail" if balcony else ""]
	if r == 0 and balcony:
		return ["wall", "", "slab", "slab"]
	return ["wall", "", "", ""]


## Pilasters, deep windows with sills and keystones, string courses and a cornice.
func _stone(r: int, q: int, course: bool, top_row: bool) -> Array[String]:
	if course:
		return ["trim", "", "trim", "trim" if top_row else ""]
	if q == 0:
		return ["pillar", "", "pillar", ""]
	if q >= 2 and q <= 5 and r >= 2 and r <= 6:
		return ["recess", "window", "", ""]
	if r == 1 and q >= 2 and q <= 5:
		return ["wall", "", "sill", ""]
	if r == 7 and q >= 3 and q <= 4:
		return ["trim", "", "trim", ""]  # keystone
	return ["wall", "", "", ""]


## Curtain walls light per panel (two bays wide, half a floor tall).
func _lit_cell(p: int, y: int) -> bool:
	var panel := Vector3i(floori(float(p) / (RES * 2)), floori(float(y) / (RES / 2.0)), 77)
	return _roll(panel, 1000) < _lit_chance * 1000.0


## A glass building's structural frame (GlassFrame).
func _frame() -> void:
	if archetype() != GLASS:
		return
	var frame := GlassFrame.cells(_w, _d, _h, RES)
	for cell: Vector3i in frame:
		vox.put(cell, str(frame[cell]))


func _slabs() -> void:
	for floor_y: int in range(0, _h, RES):
		for x: int in range(1, _w - 1):
			for z: int in range(1, _d - 1):
				if not vox.has(Vector3i(x, floor_y, z)):
					vox.put(Vector3i(x, floor_y, z), "slab")
	for x: int in range(1, _w - 1):  # the roof deck
		for z: int in range(1, _d - 1):
			vox.put(Vector3i(x, _h - 1, z), "roof")


func _roof() -> void:
	var top := _h
	for x: int in _w:  # parapet, two cells high
		for z: int in _d:
			if x == 0 or z == 0 or x == _w - 1 or z == _d - 1:
				vox.box(Vector3i(x, top, z), Vector3i(x, top + 1, z), "trim")
	_stair_hut(top)
	match archetype():
		OFFICE:  # air-conditioning units with fan grilles, ducts between them
			for i: int in clampi(b.w, 1, 4):
				var at := Vector3i(
					4 + _roll(Vector3i(i, 1, 0), maxi(1, _w - 12)),
					top,
					4 + _roll(Vector3i(i, 2, 0), maxi(1, _d - 12))
				)
				vox.box(at, at + Vector3i(4, 3, 3), "gear")
				vox.box(at + Vector3i(1, 4, 1), at + Vector3i(3, 4, 2), "vent")
				vox.box(at + Vector3i(5, 1, 1), at + Vector3i(8, 1, 1), "pipe")
		BRICK:  # a water tank on legs, a riser pipe under its middle holding it to the roof
			var c := Vector3(_w * 0.65, top + 11.0, _d * 0.4)
			for leg: Vector3i in [
				Vector3i(-4, 0, -4), Vector3i(4, 0, -4), Vector3i(-4, 0, 4), Vector3i(4, 0, 4)
			]:
				var foot := Vector3i(roundi(c.x), top, roundi(c.z)) + leg
				vox.box(foot, foot + Vector3i(0, 6, 0), "gear")
			var riser := Vector3i(roundi(c.x), top, roundi(c.z))
			vox.box(riser, riser + Vector3i(0, 5, 0), "pipe")
			vox.blob(c, Vector3(5.2, 5.6, 5.2), "tank")
			vox.box(
				Vector3i(roundi(c.x), roundi(c.y) + 6, roundi(c.z)),
				Vector3i(roundi(c.x), roundi(c.y) + 7, roundi(c.z)),
				"tank"
			)
		GLASS:  # a mast with a red beacon on the tall towers
			if b.tier >= 2:
				var mast := Vector3i(_w >> 1, top, _d >> 1)
				var mast_h := 16 + b.tier * 8
				vox.box(mast, mast + Vector3i(0, mast_h, 0), "gear")
				vox.box(mast + Vector3i(-2, 0, -2), mast + Vector3i(2, 4, 2), "gear")
				for ring: int in range(8, mast_h, 8):
					vox.box(mast + Vector3i(-1, ring, -1), mast + Vector3i(1, ring, 1), "pipe")
				vox.put(mast + Vector3i(0, mast_h + 1, 0), "beacon")
		_:  # stepped stone roof
			for step: int in 3:
				for x: int in range(2 + step * 4, _w - 2 - step * 4):
					for z: int in range(2 + step * 4, _d - 2 - step * 4):
						vox.box(
							Vector3i(x, top + step * 2, z),
							Vector3i(x, top + step * 2 + 1, z),
							"trim"
						)
	for v: int in clampi(b.d, 1, 3):  # vent stacks
		var at := Vector3i(
			2 + _roll(Vector3i(v, 5, 1), maxi(1, _w - 4)),
			top,
			2 + _roll(Vector3i(v, 5, 2), maxi(1, _d - 4))
		)
		vox.box(at, at + Vector3i(0, 3, 0), "vent")


## The stair and lift housing at a corner of the roof, with a door.
func _stair_hut(top: int) -> void:
	if _w < 20 or _d < 20:
		return
	var at := Vector3i(3, top, 3)
	vox.box(at, at + Vector3i(7, 6, 6), "wall")
	vox.box(at + Vector3i(2, 0, 7), at + Vector3i(4, 4, 7), "frame")


## A vertical neon sign hung off a street face near a corner: a dark frame round glowing
## bands, three cells wide, two deep, from above the awning up to five floors.
func _sign() -> void:
	if b.height < 3 or archetype() == GLASS or _roll(Vector3i(7, 7, 7), 1000) >= SIGN_CHANCE * 1000:
		return
	var open: Array[Vector2i] = []
	for side: Vector2i in SIDES:
		if not _party.has(side):  # signs hang only off faces with no neighbour at all
			open.append(side)
	if open.is_empty():
		return
	var side := open[_roll(Vector3i(3, 1, 4), open.size())]
	var top := mini(_h - 6, RES * 5)
	var colour := _roll(Vector3i(5, 9, 2), NEON.size())
	var length := _d if side.x != 0 else _w
	var along := 4 if _roll(Vector3i(1, 2, 3), 2) == 0 else length - 8
	for y: int in range(RES + 2, top):
		for a: int in 4:
			for out: int in range(-3, -1):
				var edge := a == 0 or a == 3 or y == RES + 2 or y == top - 1
				var band := floori((y - RES) / 3.0) % 4
				var key := (
					"sign_frame"
					if edge or band == 3
					else "neon%d" % ((colour + band) % NEON.size())
				)
				vox.put(_at(side, along + a, y, out), key)
		# An office face has nothing proud for the sign to touch: a bracket at each frame
		# edge, on every spandrel row, holds it to the wall (BuildingCells does the same).
		if archetype() == OFFICE and y % RES == 1:
			for a: int in [0, 3]:
				vox.put(_at(side, along + a, y, -1), "sign_frame")
