class_name HazardShape
extends RefCounted
## What a red-barrel site (CityHazards, Explosives; director comments #19) is made of, cell by cell
## on the destruction grid (`res` cells per sim unit, cells local to the footprint as in
## BuildingVoxels): a fuel silo is one to three round steel tanks on a pad with yellow and black
## hazard stripes, a ladder and a red lamp on the dome; a fireworks factory is a brick shed with a
## striped roof, a lit sign of starbursts and stacks of bright crates in its loading yard; a chem
## lab is a white block with green-lit window bands, green tanks and blue drums on its roof and a
## hazard-striped parapet. Each fills its whole footprint and every floor, so no structural chunk
## stands empty. The view (HazardVoxels) and the sim (HazardCells) both draw from this one map,
## so the carved grid is the drawn model. Keys are data/materials.json names. Pure: no RNG.
@warning_ignore_start("integer_division")

## Stripe period (cells) of the yellow and black hazard bands, and how tall a band is.
const STRIPE := 6
const BAND := 5
## A tank's dome rises this share of its radius.
const DOME := 0.3


## Cell -> material name for building `b` at `res` cells per unit.
static func cells(b: RampageSim.Building, res: int) -> Dictionary:
	var out := {}
	var size := Vector3i(b.w * res, b.height * res, b.d * res)
	match b.hazard:
		"fuel_silo":
			_silo(out, size, res)
		"fireworks_factory":
			_fireworks(out, size, res)
		_:
			_chem_lab(out, size, res)
	return out


static func _box(out: Dictionary, a: Vector3i, c: Vector3i, key: String) -> void:
	for x: int in range(mini(a.x, c.x), maxi(a.x, c.x) + 1):
		for y: int in range(mini(a.y, c.y), maxi(a.y, c.y) + 1):
			for z: int in range(mini(a.z, c.z), maxi(a.z, c.z) + 1):
				out[Vector3i(x, y, z)] = key


## A hollow upright tank: wall 1-2 cells thick from y0 to y1 at (cx, cz), radius r, capped by a
## dome. `paint` (Callable(cell, angle) -> key) colours the wall; the dome is `dome_key`.
static func _tank(
	out: Dictionary, centre: Vector2, r: float, y0: int, y1: int, paint: Callable, dome_key: String
) -> void:
	var lo := Vector2i(floori(centre.x - r), floori(centre.y - r))
	var hi := Vector2i(ceili(centre.x + r), ceili(centre.y + r))
	var dome := maxf(2.0, r * DOME)
	for x: int in range(lo.x, hi.x + 1):
		for z: int in range(lo.y, hi.y + 1):
			var off := Vector2(x + 0.5, z + 0.5) - centre
			var dist := off.length()
			if dist > r:
				continue
			var angle := atan2(off.y, off.x)
			if dist > r - 1.6:
				for y: int in range(y0, y1 + 1):
					var cell := Vector3i(x, y, z)
					out[cell] = paint.call(cell, angle)
			# The dome: a shell over the top, thick enough to stay closed.
			var cap := y1 + int(dome * sqrt(maxf(0.0, 1.0 - (dist * dist) / (r * r))))
			for y: int in range(maxi(y1, cap - 1), cap + 1):
				out[Vector3i(x, y, z)] = dome_key


static func _stripe(cell: Vector3i, along: int) -> String:
	return "hz_yellow" if posmod(along + cell.y, STRIPE) < STRIPE / 2 else "hz_black"


static func _silo(out: Dictionary, size: Vector3i, res: int) -> void:
	_box(out, Vector3i(0, 0, 0), Vector3i(size.x - 1, 0, size.z - 1), "hz_pad")
	var long_x := size.x >= size.z
	var short := mini(size.x, size.z)
	var count := clampi(maxi(size.x, size.z) / short, 1, 3)
	var r := short * 0.5 - 0.5
	var top := size.y - 1 - int(maxf(2.0, r * DOME))
	var upper := top - BAND >= res + BAND + 6  # room for a second band near the top
	for k: int in count:
		var t := (k + 0.5) / count
		var centre := (
			Vector2(size.x * t, size.z * 0.5) if long_x else Vector2(size.x * 0.5, size.z * t)
		)
		var paint := func(cell: Vector3i, angle: float) -> String:
			var along := roundi(angle * r)
			if absf(angle - PI * 0.5) * r < 1.5:  # a ladder up the street side
				return "hz_black" if cell.y % 3 == 0 else "hz_steel"
			if (
				cell.y >= res and cell.y < res + BAND
				or upper and cell.y >= top - BAND and cell.y < top
			):
				return _stripe(cell, along)
			if cell.y >= res + BAND and cell.y < res + BAND + 2:
				return "hz_red"
			return "hz_steel"
		_tank(out, centre, r, 1, top, paint, "hz_steel")
		var crown := Vector3i(floori(centre.x), size.y - 1, floori(centre.y))
		_box(out, crown, crown + Vector3i(0, 1, 0), "hz_lamp")
	if count > 1:  # the pipe that joins them, on low trestles
		var y := res / 2
		var a := Vector3i(roundi(size.x * 0.5 / count), y, size.z >> 1)
		var c := Vector3i(size.x - 1 - roundi(size.x * 0.5 / count), y, size.z >> 1)
		if not long_x:
			a = Vector3i(size.x >> 1, y, roundi(size.z * 0.5 / count))
			c = Vector3i(size.x >> 1, y, size.z - 1 - roundi(size.z * 0.5 / count))
		_box(out, a, c, "pipe")


static func _fireworks(out: Dictionary, size: Vector3i, res: int) -> void:
	var yard := mini(res, size.z / 3)  # a loading yard along the -z side
	var lo := Vector3i(0, 0, yard)
	var hi := Vector3i(size.x - 1, size.y - 1, size.z - 1)
	for x: int in range(lo.x, hi.x + 1):
		for z: int in range(lo.z, hi.z + 1):
			for y: int in range(0, hi.y + 1):
				var wall := x == lo.x or x == hi.x or z == lo.z or z == hi.z
				if y == hi.y:
					out[Vector3i(x, y, z)] = "hz_red" if posmod(x + z, 8) < 4 else "hz_yellow"
				elif wall:
					out[Vector3i(x, y, z)] = "hz_brick"
	for x: int in range(2, size.x - 2, 6):  # loading doors onto the yard
		_box(out, Vector3i(x, 1, lo.z), Vector3i(mini(x + 3, size.x - 3), 5, lo.z), "frame")
	# The sign on the roof: a blue board in a dark frame, starbursts in the four neon colours on
	# both faces.
	var sign_y := size.y
	var z0 := yard + 2
	_box(out, Vector3i(1, sign_y, z0), Vector3i(size.x - 2, sign_y + 8, z0), "sign_frame")
	_box(out, Vector3i(2, sign_y + 1, z0), Vector3i(size.x - 3, sign_y + 7, z0), "hz_blue")
	for k: int in range(0, size.x - 6, 6):
		var key := "neon%d" % (k / 6 % 4)
		for face: int in [z0 - 1, z0 + 1]:
			var c := Vector3i(3 + k, sign_y + 4, face)
			_box(out, c + Vector3i(-1, 0, 0), c + Vector3i(1, 0, 0), key)
			_box(out, c + Vector3i(0, -1, 0), c + Vector3i(0, 1, 0), key)
			for corner: Vector3i in [
				Vector3i(-2, 2, 0), Vector3i(2, 2, 0), Vector3i(-2, -2, 0), Vector3i(2, -2, 0)
			]:
				out[c + corner] = key
	# Crates stacked in the yard, two high, in bright fireworks colours with a dark band.
	var colours: Array[String] = ["hz_red", "hz_blue", "hz_yellow", "hz_green"]
	var n := 0
	for x: int in range(0, size.x - 3, 5):
		for z: int in range(0, maxi(1, yard - 3), 5):
			var tall := 2 if posmod(x / 5 + z, 3) != 0 else 1
			for level: int in tall:
				var a := Vector3i(x, level * 4, z)
				_box(out, a, a + Vector3i(3, 3, 3), colours[n % colours.size()])
				_box(out, a + Vector3i(0, 1, 0), a + Vector3i(3, 1, 3), "hz_black")
				n += 1


static func _chem_lab(out: Dictionary, size: Vector3i, res: int) -> void:
	var hi := size - Vector3i.ONE
	for x: int in size.x:
		for z: int in size.z:
			for y: int in size.y:
				var wall := x == 0 or z == 0 or x == hi.x or z == hi.z
				if y == hi.y:
					out[Vector3i(x, y, z)] = "hz_white"
				elif wall:
					var band := posmod(y, res) >= 3 and posmod(y, res) <= 5 and y >= res
					out[Vector3i(x, y, z)] = "hz_glow" if band else "hz_white"
	for x: int in size.x:  # a hazard-striped parapet
		for z: int in size.z:
			if x == 0 or z == 0 or x == hi.x or z == hi.z:
				var cell := Vector3i(x, size.y, z)
				out[cell] = _stripe(cell, x + z)
	# Green tanks on the roof, banded white, and a blue drum stack beside them.
	var r := clampf(mini(size.x, size.z) * 0.18, 2.5, 5.0)
	var paint := func(cell: Vector3i, _angle: float) -> String:
		return "hz_white" if posmod(cell.y - size.y, 5) == 0 else "hz_glow"
	var count := clampi(size.x / roundi(r * 2.0 + 3.0), 1, 3)
	for k: int in count:
		var centre := Vector2(r + 2.0 + k * (r * 2.0 + 3.0), size.z * 0.6)
		_tank(out, centre, r, size.y, size.y + roundi(r * 2.4), paint, "hz_white")
	for k: int in 3:
		var a := Vector3i(size.x - 4 - k * 3, size.y, 2)
		if a.x > 1:
			_box(out, a, a + Vector3i(1, 2 + k % 2, 1), "hz_drum")
