class_name BuildingVoxels
extends RefCounted
## Builds one building's fine voxels from its sim footprint: RES cells per sim unit, so each
## sim layer (one floor) is RES cells tall: a slab line, two window rows, a lintel. Four
## archetypes give the facades their read: office (ribbon windows, spandrel bands, AC units),
## brick residential (punched windows, balconies, water tank), glass tower (curtain wall,
## antenna with beacon), stone classic (deep-set windows with sills, cornices, stepped roof).
## Hollow shell plus a floor slab per floor, so a broken building shows its floors.

const RES := 4
const VOXEL := 1.0 / RES
const OFFICE := 0
const BRICK := 1
const GLASS := 2
const STONE := 3
const AWNINGS: Array[Color] = [Color("7d4636"), Color("3f5a4a"), Color("6a5a3a"), Color("4a4f66")]

var vox := VoxelBuilder.new()
var palette: Dictionary = {}
var b: RampageSim.Building
var _w: int
var _d: int
var _h: int
var _lit_chance: float


func _init(p_building: RampageSim.Building, base: Color) -> void:
	b = p_building
	_w = b.w * RES
	_d = b.d * RES
	_h = b.height * RES
	_lit_chance = Look.value("window_lit")
	_make_palette(base)
	_shell()
	_slabs()
	_roof()


func archetype() -> int:
	return b.style % 4


## World position of cell (0, 0, 0)'s centre column.
func origin() -> Vector3:
	return Vector3(b.x - b.w * 0.5 + VOXEL * 0.5, 0.0, b.z - b.d * 0.5 + VOXEL * 0.5)


## Instances to draw while `layers` sim layers stand (roof gear goes with the top floor).
func visible_for(layers: int) -> int:
	if layers >= b.height:
		return vox.sorted_y.size()
	return vox.count_below(layers * RES)


## World positions of lit windows (for real lights) on the building's lower floors.
func lit_windows() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for cell: Vector3i in vox.cells:
		if vox.key_at(cell) == "lit":
			out.append(origin() + Vector3(cell) * VOXEL)
	return out


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
		"shop": Color("1e2429"),
		"shop_lit": shop_lit,
		"awning": AWNINGS[posmod(roundi(b.x + b.z * 3.0), AWNINGS.size())],
		"slab": Color("55585a"),
		"roof": Look.color("roof"),
		"gear": Color("a9aaa4"),
		"vent": Color("3a3c3e"),
		"tank": Color("6a5040"),
		"beacon": Color(1.0, 0.25, 0.2, 0.0),
	}


func _roll(cell: Vector3i, mod: int) -> int:
	return absi(hash(Vector4i(cell.x, cell.y, cell.z, roundi(b.x * 13.0 + b.z)))) % mod


func _maybe_lit(cell: Vector3i, key: String) -> String:
	if _roll(Vector3i(cell.x >> 1, cell.y >> 2, cell.z >> 1), 1000) < _lit_chance * 1000.0:
		return "lit"
	return key


## Facade key for a perimeter cell; p runs along the face, y up the building.
func _facade(cell: Vector3i, p: int, corner: bool) -> String:
	if corner:
		return "pillar"
	if cell.y < RES:  # ground floor: shopfronts between piers, awning on top
		if cell.y == RES - 1:
			return "awning"
		return "pillar" if p % 5 == 0 else ("shop_lit" if _roll(cell, 4) == 0 else "shop")
	var key := _upper_facade(cell.y, p)
	if key == "window" or key == "glass":
		key = _maybe_lit(cell, key)
	return key


## Upper floors by archetype. row 0 is the slab line, 1-2 the windows, 3 the lintel.
func _upper_facade(y: int, p: int) -> String:
	var row := y % RES
	var in_window := row == 1 or row == 2
	var key := "wall"
	match archetype():
		OFFICE:
			if row == 0:
				key = "trim"
			elif in_window and p % 4 != 0:
				key = "window"
		BRICK:
			if in_window and p % 3 != 0:
				key = "window"
			elif row == 3 and p % 3 != 0:
				key = "frame"
		GLASS:
			key = "mullion" if p % 4 == 0 or row == 0 else "glass"
		_:
			if y % (RES * 5) == 0:
				key = "trim"
			elif in_window and p % 4 in [1, 2]:
				key = "window"
	return key


func _shell() -> void:
	for y: int in _h:
		for x: int in _w:
			for z: int in _d:
				var edge_x := x == 0 or x == _w - 1
				var edge_z := z == 0 or z == _d - 1
				if not edge_x and not edge_z:
					continue
				var p := x if edge_z else z
				vox.put(Vector3i(x, y, z), _facade(Vector3i(x, y, z), p, edge_x and edge_z))
	_outside_details()


## Things that stand proud of the wall: awnings, balconies, sills, cornices.
func _outside_details() -> void:
	for y: int in _h:
		for x: int in range(-1, _w + 1):
			for z: int in range(-1, _d + 1):
				var out_x := x == -1 or x == _w
				var out_z := z == -1 or z == _d
				if out_x == out_z:  # skip the inside and the outer corners
					continue
				var p := x if out_z else z
				var inner := Vector3i(clampi(x, 0, _w - 1), y, clampi(z, 0, _d - 1))
				var key := _proud(y, p, vox.key_at(inner))
				if key != "":
					vox.put(Vector3i(x, y, z), key)


func _proud(y: int, p: int, behind: String) -> String:
	if y == RES - 1 and behind == "awning":
		return "awning"
	if y < RES:
		return ""
	var row := y % RES
	match archetype():
		BRICK:  # balconies every other floor
			if row == 0 and floori(float(y) / RES) % 2 == 0 and p % 6 in [1, 2, 3, 4]:
				return "trim"
		STONE:  # sills under windows, a cornice every five floors and at the top
			if row == 0 and p % 4 in [1, 2]:
				return "sill"
			if y % (RES * 5) == 0 or y == _h - 1:
				return "trim"
	return ""


func _slabs() -> void:
	for floor_y: int in range(0, _h, RES):
		for x: int in range(1, _w - 1):
			for z: int in range(1, _d - 1):
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
	match archetype():
		OFFICE:  # air-conditioning units with fan grilles
			for i: int in clampi(b.w, 1, 4):
				var at := Vector3i(
					2 + _roll(Vector3i(i, 1, 0), maxi(1, _w - 6)),
					top,
					2 + _roll(Vector3i(i, 2, 0), maxi(1, _d - 6))
				)
				vox.box(at, at + Vector3i(2, 2, 2), "gear")
				vox.put(at + Vector3i(1, 3, 1), "vent")
		BRICK:  # a water tank on legs, and a stair hut
			var c := Vector3(_w * 0.65, top + 6.0, _d * 0.4)
			for leg: Vector3i in [
				Vector3i(-2, 0, -2), Vector3i(2, 0, -2), Vector3i(-2, 0, 2), Vector3i(2, 0, 2)
			]:
				var foot := Vector3i(roundi(c.x), top, roundi(c.z)) + leg
				vox.box(foot, foot + Vector3i(0, 3, 0), "gear")
			vox.blob(c, Vector3(2.8, 3.0, 2.8), "tank")
			vox.box(Vector3i(2, top, 2), Vector3i(4, top + 3, 4), "wall")
		GLASS:  # an antenna with a red beacon on the tall towers
			if b.tier >= 2:
				var mast := Vector3i(_w >> 1, top, _d >> 1)
				var mast_h := 8 + b.tier * 4
				vox.box(mast, mast + Vector3i(0, mast_h, 0), "gear")
				vox.box(mast + Vector3i(-1, 0, -1), mast + Vector3i(1, 2, 1), "gear")
				vox.put(mast + Vector3i(0, mast_h + 1, 0), "beacon")
		_:  # stepped stone roof
			for step: int in 3:
				for x: int in range(1 + step * 2, _w - 1 - step * 2):
					for z: int in range(1 + step * 2, _d - 1 - step * 2):
						vox.put(Vector3i(x, top + step, z), "trim")
