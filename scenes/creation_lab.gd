class_name CreationLab
extends Node3D
## The set Kaiju Creation plays on (D-207), built from the game's own voxel blocks (D-163, the
## city's voxel material and colour noise) under Shader Cinematic (D-104): a lab bench, a petri
## dish of agar, a rack of genome vials behind it and a syringe of kaiju juice above. Every step is
## a pure function of its progress (0..1), so a frame is the same on any machine: a vial lifts
## when focused, pours its genome into the dish, the syringe injects, the juice takes the genome
## over from the centre out, and the camera rushes into the dish. Sizes and colours: tuning
## "creation" "lab".

## Half widths in cells (a vial and the barrel are 3 cells across, the plunger 5).
const VIAL_HALF := 1
const BARREL_HALF := 1
const PLUNGER_HALF := 2
## The share of a vial's height that holds its genome (the rest is glass, then a cap).
const LIQUID_SHARE := 0.7
## The pour: the vial flies over the dish by this share of the step, pours until the next, then
## flies home; the genome spreads from the pour to the end.
const POUR_FROM := 0.35
const POUR_TO := 0.6
const POUR_TILT := 0.6
## The injection: the syringe comes down by this share of the step, then presses.
const PRESS_FROM := 0.7
## The syringe leaves over this first share of the takeover.
const LEAVE_SHARE := 0.3
const SALT := 207
## The camera's up: between up and away, so the shot never rolls as it tips straight down into
## the dish (both give the same picture while it looks down and ahead).
const CAMERA_UP := Vector3(0.0, 0.7071, -0.7071)

var camera: Camera3D
var _cfg: Dictionary
var _colors: Dictionary
var _voxel := 0.0
var _titans: Array[Dictionary] = []
var _vials: Array[Node3D] = []
var _homes: Array[Vector3] = []
var _colony: MultiMesh
## The colony's cells, nearest the centre first, and their distances from it.
var _spots: Array[Vector3] = []
var _reach: Array[float] = []
var _taken := 0
var _syringe: Node3D
var _plunger: Node3D
var _glow: OmniLight3D


func setup(titans: Array[Dictionary]) -> void:
	_titans = titans


func _ready() -> void:
	_cfg = Content.section("creation")["lab"]
	_colors = _cfg["colors"]
	_voxel = Num.f(_cfg["voxel"])
	_add_environment()
	_add_lights()
	_add_bench()
	_add_dish()
	_add_rack()
	_add_syringe()
	_add_camera()


func _color(key: String) -> Color:
	return Color(str(_colors[key]))


## One MultiMesh of `cells` (grid coordinates from `origin`) in `colors` (alpha 0 glows).
func _blocks(cells: Array[Vector3i], colors: Array[Color], origin := Vector3.ZERO) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Look.voxel_mesh(_voxel, Num.f(_cfg["glow"]))
	mm.instance_count = cells.size()
	for i: int in cells.size():
		var at := origin + (Vector3(cells[i]) + Vector3.ONE * 0.5) * _voxel
		mm.set_instance_transform(i, Transform3D(Basis(), at))
		mm.set_instance_color(i, Look.jitter(colors[i], cells[i], SALT))
	return mm


func _add_blocks(parent: Node3D, mm: MultiMesh) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	parent.add_child(mmi)
	return mmi


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _color("background")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _color("fill")
	env.ambient_light_energy = Num.f(_cfg["fill_energy"])
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_intensity = Look.value("ssao")
	env.ssao_power = Look.value("ssao_power")
	env.glow_enabled = Look.value("glow") > 0.0
	env.glow_intensity = Look.value("glow")
	env.glow_hdr_threshold = Look.value("glow_threshold")
	env.adjustment_enabled = true
	env.adjustment_saturation = Look.value("saturation")
	env.adjustment_contrast = Look.value("contrast")
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.add_to_group(GraphicsPresets.GROUP)
	GraphicsPresets.apply_to(PlayerSettings.graphics_row(), world_env)
	add_child(world_env)


## A cold lamp over the dish (shadows on), and the juice's own light, dark until the takeover.
func _add_lights() -> void:
	var lamp := SpotLight3D.new()
	lamp.light_color = _color("lamp")
	lamp.light_energy = Num.f(_cfg["lamp_energy"])
	lamp.spot_range = 8.0
	lamp.spot_angle = 40.0
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.position = Vector3(0.8, 3.2, 1.2)
	lamp.look_at(Vector3(0.0, 0.0, -0.4))
	_glow = OmniLight3D.new()
	_glow.light_color = _color("juice")
	_glow.light_energy = 0.0
	_glow.omni_range = Num.f(_cfg["dish_radius"]) * 3.0
	_glow.position = Vector3(0.0, 0.3, 0.0)
	add_child(_glow)


func _add_bench() -> void:
	var size: Array = _cfg["bench_size"]
	var nx := roundi(Num.f(size[0]) / _voxel)
	var nz := roundi(Num.f(size[1]) / _voxel)
	var cells: Array[Vector3i] = []
	var colors: Array[Color] = []
	for x: int in nx:
		for z: int in nz:
			cells.append(Vector3i(x - floori(nx * 0.5), -1, z - floori(nz * 0.67)))
			colors.append(_color("bench"))
	_add_blocks(self, _blocks(cells, colors))


## The dish: a glass base and wall, agar inside, and the colony's cells (hidden until a genome is
## poured), nearest the centre first so a growing visible count spreads it outward.
func _add_dish() -> void:
	var r := Num.f(_cfg["dish_radius"]) / _voxel
	var n := ceili(r)
	var cells: Array[Vector3i] = []
	var colors: Array[Color] = []
	for x: int in range(-n, n + 1):
		for z: int in range(-n, n + 1):
			var d := Vector2(x + 0.5, z + 0.5).length()
			if d > r:
				continue
			cells.append(Vector3i(x, 0, z))
			colors.append(_color("rim"))
			var wall := d > r - 1.0
			var top := Num.i(_cfg["dish_wall"]) if wall else 1
			for y: int in range(1, top + 1):
				cells.append(Vector3i(x, y, z))
				colors.append(_color("rim" if wall else "agar"))
	_add_blocks(self, _blocks(cells, colors))
	_add_colony()


func _add_colony() -> void:
	var r := Num.f(_cfg["colony_radius"]) / _voxel
	var n := ceili(r)
	var fill := Num.f(_cfg["colony_fill"])
	var spots: Array[Vector3i] = []
	for x: int in range(-n, n + 1):
		for z: int in range(-n, n + 1):
			var keep := float(absi(hash(Vector2i(x, z))) % 1000) / 1000.0 < fill
			if Vector2(x + 0.5, z + 0.5).length() <= r and keep:
				spots.append(Vector3i(x, 2, z))
	var from_centre := func(a: Vector3i, b: Vector3i) -> bool:
		return Vector2(a.x, a.z).length_squared() < Vector2(b.x, b.z).length_squared()
	spots.sort_custom(from_centre)
	var colors: Array[Color] = []
	colors.resize(spots.size())
	colors.fill(Color.WHITE)
	_colony = _blocks(spots, colors)
	_colony.visible_instance_count = 0
	for cell: Vector3i in spots:
		_spots.append((Vector3(cell) + Vector3.ONE * 0.5) * _voxel)
		_reach.append(Vector2(cell.x + 0.5, cell.z + 0.5).length() * _voxel)
	_add_blocks(self, _colony)


## The vials stand in a row behind the dish on a steel bar: each a column of its genome under
## glass and a cap; a locked genome is drawn in the locked grey.
func _add_rack() -> void:
	var spacing := Num.f(_cfg["vial_spacing"])
	var z := Num.f(_cfg["vial_z"])
	var count := _titans.size()
	for i: int in count:
		var titan := _titans[i]
		var liquid: Color = titan["genome"]
		if titan["locked"] == true:
			liquid = _color("locked")
		var vial := Node3D.new()
		var home := Vector3((i - (count - 1) * 0.5) * spacing, 0.0, z)
		vial.position = home
		add_child(vial)
		_add_blocks(vial, _vial_blocks(liquid))
		_vials.append(vial)
		_homes.append(home)
	var bar: Array[Vector3i] = []
	var steel: Array[Color] = []
	var half := roundi(spacing * count * 0.5 / _voxel)
	for x: int in range(-half, half):
		for dz: int in [-2, 2]:
			bar.append(Vector3i(x, 2, roundi(z / _voxel) + dz))
			steel.append(_color("steel"))
	_add_blocks(self, _blocks(bar, steel))


func _vial_blocks(liquid: Color) -> MultiMesh:
	var tall := roundi(Num.f(_cfg["vial_height"]) / _voxel)
	var cells: Array[Vector3i] = []
	var colors: Array[Color] = []
	var half := VIAL_HALF
	for y: int in tall:
		var color := liquid if y < tall * LIQUID_SHARE else _color("rim")
		if y == tall - 1:
			color = _color("steel")
		for x: int in range(-half, half + 1):
			for z: int in range(-half, half + 1):
				cells.append(Vector3i(x, y, z))
				colors.append(color)
	return _blocks(cells, colors)


## The syringe: a needle under a barrel of glowing juice ribbed in steel, a plunger on top; it
## waits above the frame until the injection.
func _add_syringe() -> void:
	_syringe = Node3D.new()
	_syringe.position = Vector3(0.0, Num.f(_cfg["syringe_top"]), 0.0)
	add_child(_syringe)
	var needle := roundi(Num.f(_cfg["needle"]) / _voxel)
	var tall := roundi(Num.f(_cfg["syringe_height"]) / _voxel)
	var juice := Color(_color("juice"), 0.0)
	var cells: Array[Vector3i] = []
	var colors: Array[Color] = []
	for y: int in needle:
		cells.append(Vector3i(0, y, 0))
		colors.append(_color("steel"))
	var half := BARREL_HALF
	for y: int in range(needle, tall):
		for x: int in range(-half, half + 1):
			for z: int in range(-half, half + 1):
				var rib := absi(x) == half and absi(z) == half
				cells.append(Vector3i(x, y, z))
				colors.append(_color("steel") if rib else juice)
	_add_blocks(_syringe, _blocks(cells, colors))
	_plunger = Node3D.new()
	_plunger.position = Vector3(0.0, tall * _voxel, 0.0)
	_syringe.add_child(_plunger)
	var plate: Array[Vector3i] = []
	var steel: Array[Color] = []
	var edge := PLUNGER_HALF
	for x: int in range(-edge, edge + 1):
		for z: int in range(-edge, edge + 1):
			plate.append(Vector3i(x, 0, z))
			steel.append(_color("steel"))
	_add_blocks(_plunger, _blocks(plate, steel))


func _add_camera() -> void:
	var shot: Dictionary = _cfg["camera"]
	camera = Camera3D.new()
	camera.fov = Num.f(shot["fov"])
	add_child(camera)
	zoom(0.0)


static func _vec(raw: Variant) -> Vector3:
	var xyz: Array = raw
	return Vector3(Num.f(xyz[0]), Num.f(xyz[1]), Num.f(xyz[2]))


## Lifts the focused vial a little off the rack (-1: none).
func focus(index: int) -> void:
	var lift := Num.f(_cfg["vial_lift"])
	for i: int in _vials.size():
		_vials[i].position = _homes[i] + Vector3.UP * (lift if i == index else 0.0)


## The pour (t 0..1): vial `index` flies over the dish, tips its genome in and flies home while
## the colony spreads out from the centre in the genome's colour.
func place(index: int, t: float) -> void:
	var vial := _vials[index]
	var over := Vector3(0.0, Num.f(_cfg["vial_hover"]), 0.0)
	var out := smoothstep(0.0, POUR_FROM, t) * (1.0 - smoothstep(POUR_TO, 1.0, t))
	vial.position = _homes[index].lerp(over, out)
	var tip := (
		smoothstep(POUR_FROM * 0.8, POUR_FROM, t) * (1.0 - smoothstep(POUR_TO, POUR_TO + 0.1, t))
	)
	vial.rotation.z = POUR_TILT * tip
	var genome: Color = _titans[index]["genome"]
	var shown := roundi(_spots.size() * smoothstep(POUR_FROM, 1.0, t))
	for i: int in range(_colony.visible_instance_count, shown):
		_colony.set_instance_color(i, genome)
	_colony.visible_instance_count = shown


## The injection (t 0..1): the syringe comes down until its needle touches the colony, then the
## plunger presses.
func inject(t: float) -> void:
	var top := Num.f(_cfg["syringe_top"])
	var touch := 3.0 * _voxel
	_syringe.position.y = lerpf(top, touch, ease(minf(t / PRESS_FROM, 1.0), 0.4))
	var tall := Num.f(_cfg["syringe_height"])
	var press := smoothstep(PRESS_FROM, 1.0, t)
	_plunger.position.y = lerpf(tall, tall * 0.55, press)


## The takeover (t 0..1): a front of glowing juice sweeps out from the needle; every cell it
## passes rises and burns white-hot, and the dish lights the lab. The syringe pulls away.
func takeover(t: float) -> void:
	var leave := smoothstep(0.0, LEAVE_SHARE, t)
	_syringe.position.y = lerpf(3.0 * _voxel, Num.f(_cfg["syringe_top"]), leave)
	var front := t * (Num.f(_cfg["colony_radius"]) + Num.f(_cfg["wave_width"]))
	var juice := Color(_color("juice"), 0.0)
	var rise := Vector3.UP * Num.i(_cfg["rise"]) * _voxel
	while _taken < _spots.size() and _reach[_taken] <= front:
		_colony.set_instance_color(_taken, juice)
		_colony.set_instance_transform(_taken, Transform3D(Basis(), _spots[_taken] + rise))
		_taken += 1
	_glow.light_energy = Num.f(_cfg["lamp_energy"]) * t


## The camera (t 0..1): from the close-up over the bench it rushes down into the dish, faster and
## faster, narrowing as it goes.
func zoom(t: float) -> void:
	var shot: Dictionary = _cfg["camera"]
	var end: Dictionary = _cfg["zoom"]
	var k := t * t * t
	camera.position = _vec(shot["position"]).lerp(_vec(end["position"]), k)
	camera.fov = lerpf(Num.f(shot["fov"]), Num.f(end["fov"]), k)
	camera.look_at(_vec(shot["look"]).lerp(Vector3.ZERO, k), CAMERA_UP)
