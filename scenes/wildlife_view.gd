class_name WildlifeView
extends Node3D
## Sky and sea life (DESIGN atmosphere; director comments 63, 66, 71): gulls wheel over the
## water, pigeons sit in flocks on rooftops, and both burst up and away from a roar (the dash's
## leap, an ultimate, an ability) or a section of a tower hitting the ground; gulls settle back
## into their circles, pigeons stay up wheeling over the roof they left. The whale surfaces a few
## times a run out in the bay, spouts, and dives at once on a roar. Pure spectacle: it reads the
## sim's events and decides nothing, and the kaiju can't touch it. Seeded (Seeds "wildlife").
## Numbers: data/tuning.json "wildlife".

const SHADER := preload("res://scenes/bird.gdshader")

## Birds put to flight so far, and the whale's surfacings and dives (the wildlife suite reads them).
var scattered := 0
var surfacings := 0
var dives := 0
var whale: Node3D
var gulls: MultiMeshInstance3D
var pigeons: MultiMeshInstance3D
var _cfg: Dictionary
var _sim: RampageSim
var _rng: RandomNumberGenerator
var _sea := 0.0
var _flocks: Array[Dictionary] = []  # one per kind: {"mm", "birds": Array[Dictionary], "kind"}
var _whale_state := "wait"  # wait, rise, up, dive, gone
var _whale_t := 0.0
var _whale_left := 0
var _whale_body: MeshInstance3D
var _spout: CPUParticles3D


## Builds the wildlife under `city` (a CityView) for its sim.
static func attach(city: Node3D, sim: RampageSim) -> WildlifeView:
	var view := WildlifeView.new()
	view._sim = sim
	city.add_child(view)
	return view


func _ready() -> void:
	name = "Wildlife"
	_cfg = Content.section("wildlife")
	_rng = Seeds.make("wildlife", 0)
	_sea = CityHarbour.sea(_sim.city)
	_build_gulls()
	_build_pigeons()
	_build_whale()


func _process(delta: float) -> void:
	for flock: Dictionary in _flocks:
		_move_flock(flock, delta)
	_move_whale(delta)


## Hands `event` to `view` (null: a city without decor, nothing to do).
static func feed(view: WildlifeView, event: Dictionary, kaiju_at: Vector3) -> void:
	if view != null:
		view.on_event(event, kaiju_at)


## A sim event: a roar scatters every bird near the kaiju and sends the whale down; a falling
## section scatters the birds near where it lands.
func on_event(event: Dictionary, kaiju_at: Vector3) -> void:
	match str(event["type"]):
		"leap", "ultimate", "ability":
			startle(kaiju_at, Num.f(_cfg["roar_radius"]))
			dive()
		"fall_land":
			var b := _sim.buildings[Num.i(event["building"])]
			startle(Vector3(b.x, 0.0, b.z), Num.f(_cfg["fall_radius"]))


## Every bird within `radius` (on the ground plane) of `at` bursts up and away from it.
func startle(at: Vector3, radius: float) -> void:
	var speed: Array = _cfg["flee_speed"]
	var up: Array = _cfg["flee_up"]
	var seconds: Array = _cfg["flee_seconds"]
	for flock: Dictionary in _flocks:
		for bird: Dictionary in flock["birds"]:
			var pos: Vector3 = bird["pos"]
			var flat := Vector2(pos.x - at.x, pos.z - at.z)
			if flat.length() > radius or Num.f(bird["scared"]) > 0.0:
				continue
			var away := (
				flat.normalized()
				if flat.length() > 0.01
				else Vector2.RIGHT.rotated(_rng.randf() * TAU)
			)
			away = away.rotated(_rng.randf_range(-0.5, 0.5))
			var v := _range(speed)
			bird["vel"] = Vector3(away.x * v, _range(up), away.y * v)
			bird["scared"] = _range(seconds)
			bird["perched"] = false
			scattered += 1


## The whale dives now if it is up or rising.
func dive() -> void:
	if _whale_state == "rise" or _whale_state == "up":
		_whale_state = "dive"
		_whale_t = 0.0
		dives += 1


## The whale's state (wait, rise, up, dive, gone), for the suite.
func whale_state() -> String:
	return _whale_state


func _build_gulls() -> void:
	var g: Dictionary = _cfg["gull"]
	var coast := Num.f(_sim.city["coast_z"])
	var birds: Array[Dictionary] = []
	for f: int in Num.i(g["flocks"]):
		var centre := Vector3(_range(g["area_x"]), 0.0, coast + _range(g["area_z"]))
		for n: int in Num.i(g["per_flock"]):
			var home := {
				"centre":
				centre + Vector3(_rng.randf_range(-4.0, 4.0), 0.0, _rng.randf_range(-4.0, 4.0)),
				"radius": _range(g["radius"]),
				"height": _sea + _range(g["height"]),
				"angle": _rng.randf() * TAU,
				"spin": _range(g["speed"]) * (1.0 if f % 2 == 0 else -1.0),
			}
			birds.append(_bird(home, false))
	gulls = _add_flock("gull", birds)


func _build_pigeons() -> void:
	var p: Dictionary = _cfg["pigeon"]
	var roofs: Array[int] = []
	for i: int in _sim.buildings.size():
		var b := _sim.buildings[i]
		if b.height >= Num.i(p["min_height"]) and b.landmark == "":
			roofs.append(i)
	var birds: Array[Dictionary] = []
	for f: int in mini(Num.i(p["flocks"]), roofs.size()):
		var b := _sim.buildings[roofs[_rng.randi_range(0, roofs.size() - 1)]]
		var wheel := Vector3(b.x, b.height + _range(p["wheel_lift"]), b.z)
		var radius := _range(p["radius"])
		for n: int in Num.i(p["per_flock"]):
			var seat := Vector3(
				b.x + _rng.randf_range(-0.4, 0.4) * b.w,
				float(b.height),
				b.z + _rng.randf_range(-0.4, 0.4) * b.d
			)
			var home := {
				"seat": seat,
				"centre": wheel,
				"radius": radius,
				"height": wheel.y,
				"angle": _rng.randf() * TAU,
				"spin": _range(p["speed"]),
			}
			birds.append(_bird(home, true))
	pigeons = _add_flock("pigeon", birds)


func _bird(home: Dictionary, perched: bool) -> Dictionary:
	var pos: Vector3 = home["seat"] if perched else _circle(home)
	return {
		"home": home,
		"pos": pos,
		"vel": Vector3.ZERO,
		"scared": 0.0,
		"perched": perched,
		"phase": _rng.randf(),
		"facing": Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)),
	}


func _add_flock(kind: String, birds: Array[Dictionary]) -> MultiMeshInstance3D:
	var look: Dictionary = _cfg[kind]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("color", Color.html(str(look["color"])))
	mat.set_shader_parameter("flap_rate", Num.f(look["flap_rate"]))
	mat.set_shader_parameter("flap_lift", Num.f(_cfg["flap_lift"]))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _bird_mesh(Num.f(look["span"]))
	mm.instance_count = birds.size()
	var mi := MultiMeshInstance3D.new()
	mi.name = kind.capitalize()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var flock := {"mm": mm, "birds": birds, "kind": kind}
	_flocks.append(flock)
	_move_flock(flock, 0.0)
	return mi


## A bird `span` metres wingtip to wingtip: a slim body along -z and two swept wings (vertex red:
## the share of the way out along the wing, for the beat in bird.gdshader).
static func _bird_mesh(span: float) -> ArrayMesh:
	var h := span * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var body := [
		Vector3(0.0, 0.0, -h * 0.6),
		Vector3(h * 0.08, 0.0, h * 0.4),
		Vector3(-h * 0.08, 0.0, h * 0.4)
	]
	for side: float in [-1.0, 1.0]:
		var root_front := Vector3(0.0, 0.0, -h * 0.15)
		var root_back := Vector3(0.0, 0.0, h * 0.2)
		var tip := Vector3(side * h, 0.0, h * 0.25)
		st.set_color(Color(0.0, 0.0, 0.0))
		st.add_vertex(root_front)
		st.add_vertex(root_back)
		st.set_color(Color(1.0, 0.0, 0.0))
		st.add_vertex(tip)
	st.set_color(Color(0.0, 0.0, 0.0))
	for v: Vector3 in body:
		st.add_vertex(v)
	return st.commit()


func _move_flock(flock: Dictionary, delta: float) -> void:
	var mm: MultiMesh = flock["mm"]
	var birds: Array[Dictionary] = flock["birds"]
	var settle := Num.f(_cfg["settle"])
	for i: int in birds.size():
		var bird := birds[i]
		var home: Dictionary = bird["home"]
		var pos: Vector3 = bird["pos"]
		var before := pos
		var scared := Num.f(bird["scared"])
		if scared > 0.0:
			var vel: Vector3 = bird["vel"]
			pos += vel * delta
			bird["scared"] = scared - delta
		elif not bird["perched"]:
			home["angle"] = Num.f(home["angle"]) + Num.f(home["spin"]) * delta
			pos = pos.lerp(_circle(home), 1.0 - exp(-settle * delta))
		bird["pos"] = pos
		var step := pos - before
		if step.length() > 0.001:
			bird["facing"] = step
		var facing: Vector3 = bird["facing"]
		var flat := Vector3(facing.x, clampf(facing.y, -0.5, 0.5), facing.z)
		var basis := Basis.looking_at(
			flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD
		)
		mm.set_instance_transform(i, Transform3D(basis, pos))
		mm.set_instance_custom_data(
			i, Color(Num.f(bird["phase"]), 0.0 if bird["perched"] else 1.0, 0.0)
		)


static func _circle(home: Dictionary) -> Vector3:
	var a := Num.f(home["angle"])
	var c: Vector3 = home["centre"]
	var r := Num.f(home["radius"])
	return Vector3(c.x + cos(a) * r, Num.f(home["height"]), c.z + sin(a) * r)


func _build_whale() -> void:
	var w: Dictionary = _cfg["whale"]
	_whale_left = _rng.randi_range(Num.i(w["surfacings"][0]), Num.i(w["surfacings"][1]))
	_whale_t = -_range(w["first"])
	whale = Node3D.new()
	whale.name = "Whale"
	whale.visible = false
	add_child(whale)
	_whale_body = MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("color", Color.html(str(w["color"])))
	mat.set_shader_parameter("roughness_value", Num.f(w["roughness"]))
	shape.material = mat
	_whale_body.mesh = shape
	_whale_body.scale = Vector3(Num.f(w["width"]), Num.f(w["hump"]) * 2.0, Num.f(w["length"]))
	whale.add_child(_whale_body)
	_build_spout(w)


func _build_spout(w: Dictionary) -> void:
	var s: Dictionary = w["spout"]
	_spout = CPUParticles3D.new()
	_spout.emitting = false
	_spout.one_shot = true
	_spout.amount = Num.i(s["amount"])
	_spout.lifetime = Num.f(s["life"])
	_spout.explosiveness = 0.6
	_spout.direction = Vector3.UP
	_spout.spread = Num.f(s["spread"])
	_spout.initial_velocity_min = Num.f(s["speed"]) * 0.7
	_spout.initial_velocity_max = Num.f(s["speed"])
	_spout.gravity = Vector3(0.0, -Num.f(s["gravity"]), 0.0)
	var drop := QuadMesh.new()
	drop.size = Vector2.ONE * Num.f(s["size"])
	var mist := StandardMaterial3D.new()
	mist.albedo_color = Color.html(str(s["color"]))
	mist.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = mist
	_spout.mesh = drop
	_spout.position = Vector3(0.0, Num.f(w["hump"]), -Num.f(w["length"]) * 0.3)
	whale.add_child(_spout)


func _move_whale(delta: float) -> void:
	if whale == null or _whale_state == "gone":
		return
	var w: Dictionary = _cfg["whale"]
	_whale_t += delta
	var low := _sea - Num.f(w["depth"])
	var high := _sea
	match _whale_state:
		"wait":
			if _whale_t < 0.0:
				return
			_surface(w, low)
		"rise":
			var k := clampf(_whale_t / Num.f(w["rise_seconds"]), 0.0, 1.0)
			whale.position.y = lerpf(low, high, k)
			if k >= 1.0:
				_whale_state = "up"
				_whale_t = -_range(w["stay"])
				_spout.restart()
		"up":
			whale.position += -whale.basis.z * Num.f(w["swim"]) * delta
			if _whale_t >= 0.0:
				dive()
		"dive":
			var k := clampf(_whale_t / Num.f(w["dive_seconds"]), 0.0, 1.0)
			whale.position.y = lerpf(high, low, k)
			whale.position += -whale.basis.z * Num.f(w["swim"]) * delta
			if k >= 1.0:
				whale.visible = false
				_whale_state = "wait"
				_whale_t = -_range(w["gap"])


func _surface(w: Dictionary, low: float) -> void:
	if _whale_left <= 0:
		_whale_state = "gone"
		return
	var coast := Num.f(_sim.city["coast_z"])
	whale.position = Vector3(_range(w["area_x"]), low, coast + _range(w["area_z"]))
	whale.rotation.y = _rng.randf() * TAU
	whale.visible = true
	_whale_state = "rise"
	_whale_t = 0.0
	_whale_left -= 1
	surfacings += 1


func _range(pair: Variant) -> float:
	var a: Array = pair
	return _rng.randf_range(Num.f(a[0]), Num.f(a[1]))
