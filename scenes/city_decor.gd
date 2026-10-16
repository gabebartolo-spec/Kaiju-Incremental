class_name CityDecor
extends Node3D
## Street life around the buildings: lane markings, parked and driving-lane cars, streetlights
## at the corners, parks in empty lots and trees on the outskirts. All seeded, all voxels;
## cars, trees and lights flatten under the kaiju's feet. Presentation only.

const PROP_VOXEL := 0.25
const CAR_COLORS: Array[Color] = [
	Color("b8b8b4"),
	Color("2e3a48"),
	Color("7a1f1f"),
	Color("d8d4c8"),
	Color("3d4a3a"),
	Color("a08850")
]

var sim: RampageSim
var _rng: RandomNumberGenerator
var _props := PropField.new(PROP_VOXEL)
var _spacing: float
var _half: float
var _grid: int
var _lamps: Array[OmniLight3D] = []


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	_rng = rng
	_spacing = Num.f(sim.city["spacing"])
	_grid = Num.i(sim.city["grid"])
	_half = CityGen.half_extent(sim.city)


func _ready() -> void:
	_lane_markings()
	_streets()
	_parks_and_outskirts()
	var palette := {
		"glass": Color("2b3640"),
		"wheel": Color("1a1a1a"),
		"ivory": Color("e8e0c8"),
		"tail": Color("a02020"),
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


## Street centre lines between lot rows, k = 0..grid.
func _street(k: int) -> float:
	return -_half + (k - 0.5) * _spacing


func _lane_markings() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var dash := BoxMesh.new()
	dash.size = Vector3(0.15, 0.04, 0.9)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d9d4c4")
	dash.material = mat
	mm.mesh = dash
	var transforms: Array[Transform3D] = []
	var reach := _half + _spacing * 0.5
	for k: int in _grid + 1:
		var s := _street(k)
		var t := -reach
		while t < reach:
			transforms.append(Transform3D(Basis(), Vector3(s, 0.02, t)))
			transforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(t, 0.02, s)))
			t += 2.0
	mm.instance_count = transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _streets() -> void:
	var reach := _half + _spacing * 0.5
	for k: int in _grid + 1:
		var s := _street(k)
		for along_x: bool in [false, true]:
			var t := -reach + _rng.randf_range(1.0, 4.0)
			while t < reach:
				var lane := 0.9 if _rng.randf() < 0.5 else -0.9
				var at := Vector3(t, 0, s + lane) if along_x else Vector3(s + lane, 0, t)
				var color := "car%d" % _rng.randi_range(0, CAR_COLORS.size() - 1)
				if absf(fposmod(t + _spacing * 0.5 + _half, _spacing) - _spacing * 0.5) > 2.2:
					_props.add(at, func(v: VoxelBuilder) -> void: _car(v, color, along_x))
				t += _rng.randf_range(3.0, 7.0)
		for j: int in _grid + 1:  # a streetlight at one corner of every crossing
			var base := Vector3(s + 1.9, 0, _street(j) + 1.9)
			_props.add(base, _streetlight)
			var lamp := OmniLight3D.new()
			lamp.light_color = Color("ffd59a")
			lamp.light_energy = Look.value("lamp_energy")
			lamp.omni_range = 6.0
			lamp.position = base + Vector3(-0.5, 2.4, -0.5)
			add_child(lamp)
			_lamps.append(lamp)


func _car(v: VoxelBuilder, color: String, along_x: bool) -> void:
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


func _streetlight(v: VoxelBuilder) -> void:
	v.box(Vector3i(0, 0, 0), Vector3i(0, 11, 0), "pole")
	v.box(Vector3i(-2, 11, -2), Vector3i(0, 11, 0), "pole")
	v.put(Vector3i(-2, 10, -2), "lamp")


func _tree(v: VoxelBuilder) -> void:
	var tall := 4 + _rng.randi_range(0, 3)
	v.box(Vector3i(0, 0, 0), Vector3i(1, tall, 1), "bark")
	var r := _rng.randf_range(2.6, 3.6)
	v.blob(Vector3(0.5, tall + r * 0.8, 0.5), Vector3(r, r * 0.85, r), "leaf")
	v.blob(
		Vector3(0.5 + r * 0.5, tall + r * 0.5, 0.0), Vector3(r * 0.7, r * 0.6, r * 0.7), "leaf_dark"
	)


func _parks_and_outskirts() -> void:
	var taken := {}
	for b: RampageSim.Building in sim.buildings:
		taken[Vector2i(roundi(b.x), roundi(b.z))] = true
	var park_mat := StandardMaterial3D.new()
	park_mat.albedo_color = Look.color("outskirts")
	for gx: int in _grid:
		for gz: int in _grid:
			var c := Vector3(-_half + gx * _spacing, 0, -_half + gz * _spacing)
			if taken.has(Vector2i(roundi(c.x), roundi(c.z))):
				continue
			var lawn := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(5.5, 0.12, 5.5)
			mesh.material = park_mat
			lawn.mesh = mesh
			lawn.position = c + Vector3(0, 0.06, 0)
			add_child(lawn)
			for n: int in 3:
				var at := c + Vector3(_rng.randf_range(-2.0, 2.0), 0, _rng.randf_range(-2.0, 2.0))
				_props.add(at, _tree)
	var ring := sim.arena_half + 6.0
	var planted := 0
	while planted < 110:
		var at := Vector3(_rng.randf_range(-ring, ring), 0, _rng.randf_range(-ring, ring))
		if maxf(absf(at.x), absf(at.z)) > _half + _spacing * 0.8:
			_props.add(at, _tree)
			planted += 1
