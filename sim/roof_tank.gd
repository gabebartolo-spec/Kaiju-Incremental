class_name RoofTank
extends RefCounted
## The rooftop water tank on a BRICK roof (director 2026-10-27, D-348, D-352), laid into a
## BuildingLayout's cells: one roof in WOODEN_ONE_IN (by a hash of the building) a wooden water
## tower, the rest a white solar water heater, both on the same spot. In cells (RES 8: a storey
## is 8). Keys are materials (data/materials.json); a cell past the footprint is not laid.

const WOODEN_ONE_IN := 4
## The tower is 12 tall (1.5 storeys): TOWER_LEGS steel legs TOWER_LEG_AT cells from its axis
## under a platform, a barrel of straight staves taller than wide (TOWER_BARREL layers, squared
## radius TOWER_BARREL_R2) with a flush hoop at each TOWER_HOOPS layer above its foot (the ring
## outside squared radius TOWER_HOOP_INNER_R2), and a cone roof at TOWER_ROOF_R2 (one squared
## radius per layer, the eave first, to a point).
const TOWER_LEGS := 2
const TOWER_LEG_AT := 2
const TOWER_PLATFORM_R2 := 8
const TOWER_BARREL := 6
const TOWER_BARREL_R2 := 5
const TOWER_HOOPS: Array[int] = [1, 4]
const TOWER_HOOP_INNER_R2 := 2
const TOWER_ROOF_R2: Array[int] = [10, 2, 0]
const TOWER_REACH := 3
## The heater: 9 cells along its tank and 8 deep, the tank lying on its side (2 cells across, 7
## long with its silver end caps) above the top edge of two panels that fall away in front of it
## in steps (a silver frame rail at each side and between them, a silver seam across).
const HEATER_W := 9
const HEATER_D := 8
const HEATER_ROWS := 7

var _cells: Dictionary
var _w: int
var _d: int


func _init(cells: Dictionary, w: int, d: int) -> void:
	_cells = cells
	_w = w
	_d = d


## Whether a BRICK roof carries the wooden tower (else the solar heater).
static func wooden(of: RampageSim.Building) -> bool:
	return wooden_at(of.x, of.z)


## The same roll for a roof centred at (x, z): the far skyline's stand-ins use it, so the whole city
## shares one mix.
static func wooden_at(x: float, z: float) -> bool:
	var seed := roundi(x * 13.0 + z)
	return absi(hash(Vector4i(4, 6, 8, seed))) % WOODEN_ONE_IN == 0


## The tank for building `of`, standing on a roof whose first free layer is `top`.
func lay(of: RampageSim.Building, top: int) -> void:
	if wooden(of):
		_tower(top)
	else:
		_heater(top)


## A wooden water tower (D-348; D-352 shrank it to 12 cells): a barrel of straight staves on four
## steel legs and a platform, two iron hoops round it, a cone roof to a point. Round in plan.
func _tower(top: int) -> void:
	var at := Vector3i(roundi(_w * 0.65), top, roundi(_d * 0.4))
	for lz: int in [-TOWER_LEG_AT, TOWER_LEG_AT]:
		for lx: int in [-TOWER_LEG_AT, TOWER_LEG_AT]:
			for y: int in TOWER_LEGS:
				_disc(at + Vector3i(lx, y, lz), "gear", 0)
	_disc(at + Vector3i(0, TOWER_LEGS, 0), "gear", TOWER_PLATFORM_R2)
	var base := at + Vector3i(0, TOWER_LEGS + 1, 0)
	for y: int in TOWER_BARREL:
		_disc(base + Vector3i(0, y, 0), "tank", TOWER_BARREL_R2)
	for y: int in TOWER_HOOPS:  # flush with the staves, the ring round the core
		_disc(base + Vector3i(0, y, 0), "vent", TOWER_BARREL_R2, TOWER_HOOP_INNER_R2)
	for k: int in TOWER_ROOF_R2.size():  # the eave first, then ever narrower to the tip
		_disc(base + Vector3i(0, TOWER_BARREL + k, 0), "tank", TOWER_ROOF_R2[k])


## The cells of layer `at.y` round `at` (x, z) whose squared distance from it is over `inner2` and
## at most `outer2` (`outer2` 0 is the one cell under `at`).
func _disc(at: Vector3i, key: String, outer2: int, inner2 := -1) -> void:
	for dx: int in range(-TOWER_REACH, TOWER_REACH + 1):
		for dz: int in range(-TOWER_REACH, TOWER_REACH + 1):
			var d2 := dx * dx + dz * dz
			if d2 > inner2 and d2 <= outer2:
				_put(at + Vector3i(dx, 0, dz), key)


## A white solar water heater (D-352, from the director's photo): two dark panels in silver frames
## that rise in steps from the roof toward the back (row hz 0 to 6, a step every second row, a
## frame rail at hx 0, 4 and 8, a seam across at hz 3), and above the panels' top edge the white
## tank lying on its side (hx 1 to 7 and hz 6 to 7, two cells across, silver end caps, a highlight
## along its top). A cross-member beneath each step joins the stairs face to face; the top edge
## stands on legs at the rails.
func _heater(top: int) -> void:
	var x0 := clampi(roundi(_w * 0.65) - 4, 1, maxi(1, _w - HEATER_W - 1))
	var z0 := clampi(roundi(_d * 0.4) - 4, 1, maxi(1, _d - HEATER_D - 1))
	for hx: int in HEATER_W:
		var rail := hx % 4 == 0
		for hz: int in HEATER_ROWS:
			var y := top + (hz >> 1)
			var frame := rail or hz == 0 or hz == 3 or hz == HEATER_ROWS - 1
			_put(Vector3i(x0 + hx, y, z0 + hz), "gear" if frame else "solar")
			if hz > 0 and hz % 2 == 0:  # a step: the cross-member beneath it
				_put(Vector3i(x0 + hx, y - 1, z0 + hz), "gear")
		if rail:  # the legs under the top edge
			for y: int in 3:
				_put(Vector3i(x0 + hx, top + y, z0 + HEATER_ROWS - 1), "gear")
	for hx: int in range(1, HEATER_W - 1):
		var cap := hx == 1 or hx == HEATER_W - 2
		for hz: int in range(HEATER_ROWS - 1, HEATER_D):
			_put(Vector3i(x0 + hx, top + 4, z0 + hz), "gear" if cap else "heater")
			_put(Vector3i(x0 + hx, top + 5, z0 + hz), "gear" if cap else "heater_hi")


func _put(cell: Vector3i, key: String) -> void:
	if cell.x >= 0 and cell.x < _w and cell.z >= 0 and cell.z < _d:
		_cells[cell] = key
