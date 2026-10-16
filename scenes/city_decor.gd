class_name CityDecor
extends Node3D
## Street life on the street plan (CityGen.map): cars parked along the kerbs, streetlights at
## the crossings and down the long blocks, trees in the park, round the plaza and along the
## diagonal avenue, and parking lots full of cars. All seeded, all voxels; cars, trees and
## lights flatten under the kaiju's feet. Presentation only.

const PROP_VOXEL := 0.25
const CAR_COLORS: Array[Color] = [
	Color("6b6e70"),
	Color("2a3138"),
	Color("5a2a26"),
	Color("8a8a84"),
	Color("3a4236"),
	Color("6a5e48")
]
const CROSSING_CLEAR := 3.0  # no parking this close to a crossing
const LAMP_EVERY := 13.0

var sim: RampageSim
var plan: Dictionary
var _rng: RandomNumberGenerator
var _props := PropField.new(PROP_VOXEL)
var _half: float
var _lamps: Array[OmniLight3D] = []
var _footprints: Array[Rect2] = []


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	_rng = rng
	plan = CityGen.map(sim.city)
	_half = CityGen.half_extent(sim.city)
	for b: RampageSim.Building in sim.buildings:
		_footprints.append(Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d).grow(0.4))


func _ready() -> void:
	_streets()
	_blocks()
	_diagonal_trees()
	var palette := {
		"glass": Color("2b3640"),
		"wheel": Color("1a1a1a"),
		"ivory": Color("b8b2a0"),
		"tail": Color("6a1a1a"),
		"bark": Color("5a4030"),
		"leaf": Color("55703f"),
		"leaf_dark": Color("3f5832"),
		"pole": Color("4a4c4e"),
		"lamp": Color(1.0, 0.86, 0.6, 0.0),
	}
	for i: int in CAR_COLORS.size():
		palette["car%d" % i] = CAR_COLORS[i]
	add_child(_props.build(palette, 31, 3.0))


## Flattens props under a stomp.
func crush(at: Vector3, radius: float) -> void:
	_props.crush(at, radius)
	for lamp: OmniLight3D in _lamps.duplicate():
		if Vector2(lamp.position.x - at.x, lamp.position.z - at.z).length() <= radius:
			_lamps.erase(lamp)
			lamp.queue_free()


func _inside(p: Vector2, margin: float = 0.0) -> bool:
	return maxf(absf(p.x), absf(p.y)) <= _half + margin


func _on_building(p: Vector2) -> bool:
	for r: Rect2 in _footprints:
		if r.has_point(p):
			return true
	return false


## Parked cars along both kerbs, now and then one stopped in the lane; a streetlight at a
## corner of every crossing and down the long blocks.
func _streets() -> void:
	var nodes: Array[Vector2] = plan["nodes"]
	var lit_nodes := {}
	for street: Dictionary in plan["streets"]:
		var kind := str(street["kind"])
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if not (_inside(a, 0.5) and _inside(b, 0.5)) or kind == CityGen.ALLEY:
			continue
		var width := Num.f(street["width"])
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var length := a.distance_to(b)
		if kind != CityGen.DIAGONAL:
			var along_x := absf(dir.x) > 0.5
			for kerb: float in [-1.0, 1.0]:
				var t := CROSSING_CLEAR + _rng.randf_range(0.0, 2.0)
				while t < length - CROSSING_CLEAR:
					var lane := width * 0.5 - 0.6
					if _rng.randf() < 0.12:
						lane = width * 0.25  # stopped in the traffic lane
					var p := a + dir * t + side * kerb * lane
					var color := "car%d" % _rng.randi_range(0, CAR_COLORS.size() - 1)
					var on_diagonal := (
						CityGen.diagonal_distance(plan, p)
						< CityGen.width_of(CityGen.DIAGONAL, sim.city) * 0.5 + 1.0
					)
					if _rng.randf() < 0.7 and not on_diagonal:
						_props.add(
							Vector3(p.x, 0, p.y),
							func(v: VoxelBuilder) -> void: car(v, color, along_x)
						)
					t += _rng.randf_range(1.9, 3.2)
		for end: int in [Num.i(street["from"]), Num.i(street["to"])]:
			if not lit_nodes.has(end) and kind != CityGen.DIAGONAL:
				lit_nodes[end] = true
				var corner := nodes[end] + (dir + side) * (width * 0.5 + 0.7)
				_lamp(corner, -(dir + side))
		var t2 := LAMP_EVERY
		var flip := 1.0
		while t2 < length - LAMP_EVERY * 0.6:
			var p2 := a + dir * t2 + side * flip * (width * 0.5 + 0.6)
			_lamp(p2, -side * flip)
			flip = -flip
			t2 += LAMP_EVERY


## A streetlight at p whose arm reaches toward `toward` (over the road), with a real light.
func _lamp(p: Vector2, toward: Vector2) -> void:
	if _on_building(p):
		return
	var arm := Vector2i(roundi(signf(toward.x)), roundi(signf(toward.y)))
	_props.add(Vector3(p.x, 0, p.y), func(v: VoxelBuilder) -> void: _streetlight(v, arm))
	var light := OmniLight3D.new()
	light.light_color = Color("ffd59a")
	light.light_energy = Look.value("lamp_energy")
	light.omni_range = 6.0
	light.position = Vector3(p.x + arm.x * 0.5, 2.4, p.y + arm.y * 0.5)
	add_child(light)
	_lamps.append(light)


## The park, the plaza and the parking lots.
func _blocks() -> void:
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		match str(block["use"]):
			"park":
				var inner := rect.grow(-1.6)
				for n: int in roundi(rect.get_area() / 9.0):
					var p := Vector2(
						_rng.randf_range(inner.position.x, inner.end.x),
						_rng.randf_range(inner.position.y, inner.end.y)
					)
					if absf(p.x - rect.get_center().x) > 1.2:  # a path down the middle
						_props.add(Vector3(p.x, 0, p.y), _tree)
			"plaza":
				var ring := rect.grow(-1.2)
				var t := 0.0
				while t < 1.0:
					for edge: int in 4:
						var p := _on_edge(ring, edge, t)
						if not _on_building(p):
							_props.add(Vector3(p.x, 0, p.y), _tree)
					t += 0.2
			"parking":
				var bays := rect.grow(-0.6)
				var x := bays.position.x + 1.65
				while x < bays.end.x - 0.6:
					for z: float in [bays.position.y + 1.2, bays.end.y - 1.2]:
						if _rng.randf() < 0.7:
							var color := "car%d" % _rng.randi_range(0, CAR_COLORS.size() - 1)
							_props.add(
								Vector3(x, 0, z),
								func(v: VoxelBuilder) -> void: car(v, color, false)
							)
					x += 1.3


func _on_edge(r: Rect2, edge: int, t: float) -> Vector2:
	match edge:
		0:
			return Vector2(lerpf(r.position.x, r.end.x, t), r.position.y)
		1:
			return Vector2(lerpf(r.position.x, r.end.x, t), r.end.y)
		2:
			return Vector2(r.position.x, lerpf(r.position.y, r.end.y, t))
	return Vector2(r.end.x, lerpf(r.position.y, r.end.y, t))


## Street trees down both sides of the diagonal, and in the leftover corners it cuts out of
## the blocks (little plazas, the way Broadway leaves them).
func _diagonal_trees() -> void:
	var diag: Dictionary = plan["diagonal"]
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	var side := Vector2(-dir.y, dir.x)
	var kerb := CityGen.width_of(CityGen.DIAGONAL, sim.city) * 0.5 + 0.6
	var t := -_half * 1.6
	while t < _half * 1.6:
		for s: float in [-1.0, 1.0]:
			for off: float in [kerb, kerb + 2.5, kerb + 5.0]:
				var p := at + dir * t + side * s * off
				if not _inside(p, -1.0) or _on_building(p) or _near_street(p):
					continue
				if off == kerb or _rng.randf() < 0.45:
					_props.add(Vector3(p.x, 0, p.y), _tree)
		t += 4.0


## Whether p lies on a grid street (not on a block).
func _near_street(p: Vector2) -> bool:
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		if rect.has_point(p):
			return false
	return true


## A car (about 1.5 long at PROP_VOXEL), nose to -Z (to -X when along_x). Traffic reuses it.
static func car(v: VoxelBuilder, color: String, along_x: bool) -> void:
	var local := VoxelBuilder.new()
	local.box(Vector3i(-1, 0, -3), Vector3i(1, 1, 2), color)
	local.box(Vector3i(-1, 2, -1), Vector3i(1, 2, 1), "glass")
	for wheel: Vector3i in [
		Vector3i(-1, 0, -2), Vector3i(1, 0, -2), Vector3i(-1, 0, 1), Vector3i(1, 0, 1)
	]:
		local.put(wheel, "wheel")
	local.put(Vector3i(-1, 1, -3), "ivory")
	local.put(Vector3i(1, 1, -3), "ivory")
	local.put(Vector3i(-1, 1, 2), "tail")
	local.put(Vector3i(1, 1, 2), "tail")
	for cell: Vector3i in local.cells:
		var placed := Vector3i(cell.z, cell.y, cell.x) if along_x else cell
		v.put(placed, local.key_at(cell))


## arm: which way (x, z signs) the lamp arm reaches.
func _streetlight(v: VoxelBuilder, arm: Vector2i) -> void:
	var reach := Vector3i(arm.x * 2, 0, arm.y * 2)
	v.box(Vector3i(0, 0, 0), Vector3i(0, 11, 0), "pole")
	v.box(Vector3i(0, 11, 0), reach + Vector3i(0, 11, 0), "pole")
	v.put(reach + Vector3i(0, 10, 0), "lamp")


func _tree(v: VoxelBuilder) -> void:
	var tall := 4 + _rng.randi_range(0, 3)
	v.box(Vector3i(0, 0, 0), Vector3i(1, tall, 1), "bark")
	var r := _rng.randf_range(2.6, 3.6)
	v.blob(Vector3(0.5, tall + r * 0.8, 0.5), Vector3(r, r * 0.85, r), "leaf")
	v.blob(
		Vector3(0.5 + r * 0.5, tall + r * 0.5, 0.0), Vector3(r * 0.7, r * 0.6, r * 0.7), "leaf_dark"
	)
