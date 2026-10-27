class_name BuildingLayout
extends RefCounted
## One building's fine layout, shared by the sim's destruction grid (BuildingCells) and the
## view's voxels (BuildingVoxels), so the two can never drift apart: `cells` maps each cell
## (RES cells per sim unit, local to the footprint) to its key, in the order the parts are laid.
## Facades have depth: windows sit one cell back in their reveals behind proud sills and
## lintels; piers, spandrels, mullions and transoms frame them. Four archetypes: office (ribbon
## windows over spandrel bands, AC plant), brick (punched windows, balconies, a solar water
## heater or a wooden water tower: RoofTank), glass (flush curtain wall on a structural frame,
## mast with beacon), stone (pilasters, cornices and string courses, stepped roof). Ground floors
## are shopfronts under a sign band and an awning; some shops hang a vertical neon sign off a
## street face. Hollow shell plus a slab per floor.
## Keys are materials (data/materials.json) except the lit windows the view asks for: with
## lit_chance 0 (the sim) no "lit" or "shop_lit" key is laid. Layout rolls hash the cell with the
## building's position: no RNG stream, no clock. The bay patterns are drawn for an 8-cell bay.

const OFFICE := 0
const BRICK := 1
const GLASS := 2
const STONE := 3
const NEON_COUNT := 4
const SIGN_CHANCE := 0.3
## Sides, as the outward step in cells: -x, +x, -z, +z.
const SIDES: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

## Cell -> key, in the order laid (a cell laid twice keeps its first place and the last key).
var cells: Dictionary = {}
var b: RampageSim.Building
var res: int
var _w: int
var _d: int
var _h: int
var _party: Dictionary
var _lit_chance: float


## party: side (SIDES) -> floors of that side a touching neighbour covers (no sign hangs off
## that side). lit_chance: the share of windows the view lights (0 in the sim).
func _init(
	p_building: RampageSim.Building, p_res: int, party: Dictionary = {}, lit_chance: float = 0.0
) -> void:
	b = p_building
	res = p_res
	_party = party
	_lit_chance = lit_chance
	_w = b.w * res
	_d = b.d * res
	_h = b.height * res
	for side: Vector2i in SIDES:
		_face(side)
	_frame()
	_slabs()
	_roof()
	_sign()


func archetype() -> int:
	return b.style % 4


func _put(cell: Vector3i, key: String) -> void:
	cells[cell] = key


func _box(a: Vector3i, c: Vector3i, key: String) -> void:
	for x: int in range(mini(a.x, c.x), maxi(a.x, c.x) + 1):
		for y: int in range(mini(a.y, c.y), maxi(a.y, c.y) + 1):
			for z: int in range(mini(a.z, c.z), maxi(a.z, c.z) + 1):
				cells[Vector3i(x, y, z)] = key


func _roll(cell: Vector3i, mod: int) -> int:
	return roll_for(b, cell, mod)


## The roll for building `of` at `cell`: a hash of the cell and the building's position.
static func roll_for(of: RampageSim.Building, cell: Vector3i, mod: int) -> int:
	return absi(hash(Vector4i(cell.x, cell.y, cell.z, roundi(of.x * 13.0 + of.z)))) % mod


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
				_put(_at(side, p, y, 0), "pillar")
				continue
			var spec := _ground(y, p) if y < res else _upper(y, p)
			if spec[0] == "recess":
				_put(_at(side, p, y, 1), _lit_or(spec[1], side, p, y))
			else:
				_put(_at(side, p, y, 0), spec[0])
			if spec[2] != "":
				_put(_at(side, p, y, -1), spec[2])
			if spec[3] != "":
				_put(_at(side, p, y, -2), spec[3])


## A window lights as a whole: one roll per window (its bay and floor).
func _lit_or(key: String, side: Vector2i, p: int, y: int) -> String:
	if _lit_chance <= 0.0:
		return key
	var window := Vector3i(floori(float(p) / res), floori(float(y) / res), side.x * 3 + side.y)
	if _roll(window, 1000) < _lit_chance * 1000.0:
		return "shop_lit" if key == "shop" else "lit"
	return key


## Ground floor, as [plane, recessed key, proud, further proud]: shop windows between piers,
## a sign band, an awning reaching out over the pavement.
func _ground(y: int, p: int) -> Array[String]:
	if y == res - 1:
		return ["trim", "", "awning", "awning"]
	if y == res - 2:
		return ["band", "", "band", ""]
	if p % res == 0 or y == 0:
		return ["pillar", "", "", ""]  # a pier, or the stall riser under the glass
	return ["recess", "shop", "", ""]


## Upper floors by archetype, as [plane, recessed key, proud, further proud].
## r: row within the floor (0 = the slab line), q: column within the bay.
func _upper(y: int, p: int) -> Array[String]:
	var r := y % res
	var q := p % res
	var top_row := y >= _h - 2
	match archetype():
		OFFICE:
			return _office(r, q, top_row)
		BRICK:
			return _brick(r, q, floori(float(y) / res))
		GLASS:
			if q == 0 or r == 0:
				return ["mullion", "", "", ""]
			if r == 4:
				return ["frame", "", "", ""]  # transom
			return ["lit" if _lit_panel(p, y) else "glass", "", "", ""]
	return _stone(r, q, top_row or (r == 0 and floori(float(y) / res) % 5 == 0), top_row)


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
func _lit_panel(p: int, y: int) -> bool:
	if _lit_chance <= 0.0:
		return false
	var panel := Vector3i(floori(float(p) / (res * 2)), floori(float(y) / (res / 2.0)), 77)
	return _roll(panel, 1000) < _lit_chance * 1000.0


## A glass building's structural frame (GlassFrame).
func _frame() -> void:
	if archetype() != GLASS:
		return
	var frame := GlassFrame.cells(_w, _d, _h, res)
	for cell: Vector3i in frame:
		_put(cell, str(frame[cell]))


## A slab per floor inside the shell, and the roof deck.
func _slabs() -> void:
	for floor_y: int in range(0, _h, res):
		for x: int in range(1, _w - 1):
			for z: int in range(1, _d - 1):
				if not cells.has(Vector3i(x, floor_y, z)):
					_put(Vector3i(x, floor_y, z), "slab")
	for x: int in range(1, _w - 1):
		for z: int in range(1, _d - 1):
			_put(Vector3i(x, _h - 1, z), "roof")


func _roof() -> void:
	var top := _h
	for x: int in _w:  # parapet, two cells high
		for z: int in _d:
			if x == 0 or z == 0 or x == _w - 1 or z == _d - 1:
				_box(Vector3i(x, top, z), Vector3i(x, top + 1, z), "trim")
	_stair_hut(top)
	match archetype():
		OFFICE:
			_ac_units(top)
		BRICK:
			RoofTank.new(cells, _w, _d).lay(b, top)
		GLASS:
			_mast(top)
		_:  # stepped stone roof
			for step: int in 3:
				for x: int in range(2 + step * 4, _w - 2 - step * 4):
					for z: int in range(2 + step * 4, _d - 2 - step * 4):
						_box(
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
		_box(at, at + Vector3i(0, 3, 0), "vent")


## Air-conditioning units with fan grilles, ducts between them.
func _ac_units(top: int) -> void:
	for i: int in clampi(b.w, 1, 4):
		var at := Vector3i(
			4 + _roll(Vector3i(i, 1, 0), maxi(1, _w - 12)),
			top,
			4 + _roll(Vector3i(i, 2, 0), maxi(1, _d - 12))
		)
		_box(at, at + Vector3i(4, 3, 3), "gear")
		_box(at + Vector3i(1, 4, 1), at + Vector3i(3, 4, 2), "vent")
		_box(at + Vector3i(5, 1, 1), at + Vector3i(8, 1, 1), "pipe")


## A mast with a red beacon on the tall towers.
func _mast(top: int) -> void:
	if b.tier < 2:
		return
	var mast := Vector3i(_w >> 1, top, _d >> 1)
	var mast_h := 16 + b.tier * 8
	_box(mast, mast + Vector3i(0, mast_h, 0), "gear")
	_box(mast + Vector3i(-2, 0, -2), mast + Vector3i(2, 4, 2), "gear")
	for ring: int in range(8, mast_h, 8):
		_box(mast + Vector3i(-1, ring, -1), mast + Vector3i(1, ring, 1), "pipe")
	_put(mast + Vector3i(0, mast_h + 1, 0), "beacon")


## The stair and lift housing at a corner of the roof, with a door.
func _stair_hut(top: int) -> void:
	if _w < 20 or _d < 20:
		return
	var at := Vector3i(3, top, 3)
	_box(at, at + Vector3i(7, 6, 6), "wall")
	_box(at + Vector3i(2, 0, 7), at + Vector3i(4, 4, 7), "frame")


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
	var top := mini(_h - 6, res * 5)
	var colour := _roll(Vector3i(5, 9, 2), NEON_COUNT)
	var length := _d if side.x != 0 else _w
	var along := 4 if _roll(Vector3i(1, 2, 3), 2) == 0 else length - 8
	for y: int in range(res + 2, top):
		for a: int in 4:
			for out: int in range(-3, -1):
				var edge := a == 0 or a == 3 or y == res + 2 or y == top - 1
				var band := floori((y - res) / 3.0) % 4
				var key := (
					"sign_frame" if edge or band == 3 else "neon%d" % ((colour + band) % NEON_COUNT)
				)
				_put(_at(side, along + a, y, out), key)
		# An office face has nothing proud for the sign to touch: a bracket at each frame
		# edge, on every spandrel row, holds it to the wall.
		if archetype() == OFFICE and y % res == 1:
			for a: int in [0, 3]:
				_put(_at(side, along + a, y, -1), "sign_frame")
