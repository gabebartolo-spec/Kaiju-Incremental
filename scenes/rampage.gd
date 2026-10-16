class_name Rampage
extends Node3D
## Presents one rampage. Reads input, steps RampageSim, and turns its events into the city
## view, the kaiju, the tanks, the camera and the HUD. It never decides an outcome; when the
## sim ends, the HUD shows the result and Continue emits finished.

signal finished(result: Dictionary)

const CAMERA_OFFSET := Vector3(0, 27, 19)
const TANK_GREEN := Color("55613a")

var sim: RampageSim
var species: Dictionary
var _city: CityView
var _hud: RampageHud
var _kaiju: KaijuModel
var _kaiju_at := Vector3.ZERO
var _leap_time := 0.0
var _leap_from := Vector3.ZERO
var _camera: Camera3D
var _shake := 0.0
var _tank_nodes: Dictionary = {}
var _fx_rng: RandomNumberGenerator
var _too_tall_cooldown := 0.0
var _autoplay := false


## stats: final run stats; layout: CityGen output; run_index seeds the army.
func setup(
	p_species: Dictionary, stats: Dictionary, layout: Array[Dictionary], run_index: int
) -> void:
	species = p_species
	var ability: Dictionary = species["ability"]
	sim = RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", run_index))
	sim.ability_type = str(ability["type"])
	_fx_rng = Seeds.make("fx", run_index)


## Test hook: the kaiju walks toward the nearest building it can topple on its own.
func set_autoplay(on: bool) -> void:
	_autoplay = on


func _ready() -> void:
	_city = CityView.new(sim, _fx_rng)
	add_child(_city)
	var colors: Dictionary = species["colors"]
	_kaiju = KaijuModel.new(str(species["id"]), colors)
	add_child(_kaiju)
	_kaiju_at = _to_world(sim.kaiju_pos)
	_kaiju.position = _kaiju_at
	_kaiju.scale = Vector3.ONE * sim.body_scale()
	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_camera.current = true
	_place_camera(1.0)
	_hud = RampageHud.new(sim, species)
	_hud.continued.connect(func() -> void: finished.emit(sim.result()))
	add_child(_hud)
	get_node("/root/EventBus").emit_signal("run_started", str(species["id"]))


func _physics_process(delta: float) -> void:
	if sim.over:
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var signature := Input.is_action_just_pressed("signature")
	if _autoplay:
		move = _autoplay_move()
		signature = sim.ability_ready_in <= 0.0
	for event: Dictionary in sim.step(delta, move, signature):
		_on_event(event)
	_too_tall_cooldown = maxf(0.0, _too_tall_cooldown - delta)
	_update_kaiju(delta, move.length())
	_update_tanks()
	_hud.refresh()


func _process(delta: float) -> void:
	_place_camera(delta)
	_shake = maxf(0.0, _shake - delta * 3.0)


func _to_world(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


func _on_event(event: Dictionary) -> void:
	match str(event["type"]):
		"stomp":
			_kaiju.stomp()
			_city.ring(_kaiju_at, Num.f(event["radius"]), Color(1, 0.85, 0.6, 0.7), 0.35)
			_shake = maxf(_shake, 0.15)
		"ability":
			_ability_fx(event)
		"layers_destroyed":
			_on_layers_destroyed(Num.i(event["building"]), Num.i(event["count"]))
		"too_tall":
			if _too_tall_cooldown <= 0.0:
				_too_tall_cooldown = 2.5
				var b := sim.buildings[Num.i(event["building"])]
				_city.float_text("TOO TALL - EVOLVE", Vector3(b.x, 4.0, b.z), UiKit.WARN)
		"tank_spawned":
			_spawn_tank_node(Num.i(event["tank"]))
		"tank_fired":
			_tank_fired(Num.i(event["tank"]))
		"tank_destroyed":
			var at := Vector3(Num.f(event["x"]), 0.5, Num.f(event["z"]))
			_tank_destroyed(Num.i(event["tank"]), at)
		"run_over":
			_hud.refresh()
			_hud.show_results()
			get_node("/root/EventBus").emit_signal("run_ended", sim.result())


func _on_layers_destroyed(index: int, count: int) -> void:
	_city.layers_destroyed(index, count, _kaiju_at)
	var b := sim.buildings[index]
	var gained := count * b.tier * (b.w * b.d) / 9.0 * sim.stat("rubble_mult")
	if gained >= 1.0:
		_city.float_text("+%d" % Num.i(gained), Vector3(b.x, b.layers + 2.0, b.z), UiKit.WARN)


func _ability_fx(event: Dictionary) -> void:
	var reach := Num.f(event["reach"])
	_shake = maxf(_shake, 0.45)
	var colors: Dictionary = species["colors"]
	var eye := Color(str(colors["eye"]))
	match str(event["kind"]):
		"cone":
			var mouth := _kaiju_at + Vector3(0, 6.0 * sim.body_scale(), 0)
			_city.flame_cone(mouth, _kaiju_at, _to_world(sim.facing) * reach, eye)
		"leap":
			var from: Vector2 = event["from"]
			_leap_from = _to_world(from)
			_leap_time = 0.0001
			_city.ring(_to_world(sim.kaiju_pos), reach, eye, 0.5)
		_:
			_city.ring(_kaiju_at, reach, eye, 0.5)
			_city.ring(_kaiju_at, reach * 0.6, eye.lightened(0.3), 0.35)


func _update_kaiju(delta: float, moving: float) -> void:
	var target := _to_world(sim.kaiju_pos)
	if _leap_time > 0.0:
		_leap_time += delta
		var t := clampf(_leap_time / 0.4, 0.0, 1.0)
		_kaiju_at = _leap_from.lerp(target, t) + Vector3(0, sin(t * PI) * 6.0, 0)
		if t >= 1.0:
			_leap_time = 0.0
			_kaiju_at = target
	else:
		_kaiju_at = _kaiju_at.lerp(target, minf(1.0, delta * 12.0))
	_kaiju.position = _kaiju_at
	var heading := atan2(-sim.facing.x, -sim.facing.y)
	_kaiju.rotation.y = lerp_angle(_kaiju.rotation.y, heading, minf(1.0, delta * 10.0))
	_kaiju.animate(delta, moving)


func _spawn_tank_node(id: int) -> void:
	var tank := Node3D.new()
	tank.add_child(_part(Vector3(1.6, 0.6, 2.2), Vector3(0, 0.3, 0), TANK_GREEN))
	tank.add_child(_part(Vector3(1.0, 0.45, 1.0), Vector3(0, 0.82, 0.1), Color("6b7848")))
	tank.add_child(_part(Vector3(0.22, 0.22, 1.3), Vector3(0, 0.85, -0.9), Color("3a4228")))
	add_child(tank)
	_tank_nodes[id] = tank


func _part(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	return mi


func _update_tanks() -> void:
	for tank: RampageSim.Tank in sim.tanks:
		if not _tank_nodes.has(tank.id):
			continue
		var node: Node3D = _tank_nodes[tank.id]
		node.position = _to_world(tank.pos)
		var to := sim.kaiju_pos - tank.pos
		if to.length() > 0.01:
			node.rotation.y = atan2(-to.x, -to.y)


func _tank_fired(id: int) -> void:
	if not _tank_nodes.has(id):
		return
	var node: Node3D = _tank_nodes[id]
	var target := _kaiju_at + Vector3(0, 4.0 * sim.body_scale(), 0)
	var shell := _part(Vector3.ONE * 0.35, node.position + Vector3(0, 0.9, 0), UiKit.WARN)
	shell.material_override = CityView.glow(UiKit.WARN, 4.0)
	add_child(shell)
	var tween := shell.create_tween()
	tween.tween_property(shell, "position", target, 0.22)
	tween.tween_callback(shell.queue_free)
	_shake = maxf(_shake, 0.08)


func _tank_destroyed(id: int, pos: Vector3) -> void:
	if _tank_nodes.has(id):
		var node: Node3D = _tank_nodes[id]
		node.queue_free()
		_tank_nodes.erase(id)
	for n: int in 8:
		_city.debris(
			pos + Vector3(0, 0.5, 0), TANK_GREEN if n % 2 == 0 else UiKit.ACCENT, Vector3.UP
		)
	var gained := Num.f(sim.army["tank_rubble"]) * sim.stat("rubble_mult")
	_city.float_text("+%d" % Num.i(gained), pos + Vector3(0, 2, 0), UiKit.WARN)


func _place_camera(delta: float) -> void:
	var zoom := 0.75 + 0.4 * sim.body_scale()
	var target := _kaiju_at + CAMERA_OFFSET * zoom
	_camera.position = _camera.position.lerp(target, minf(1.0, delta * 5.0))
	var jitter := Vector3(_fx_rng.randf_range(-1, 1), _fx_rng.randf_range(-1, 1), 0) * _shake * 0.6
	_camera.look_at(_kaiju_at + Vector3(0, 3.5 * sim.body_scale(), 0) + jitter)


func _autoplay_move() -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for b: RampageSim.Building in sim.buildings:
		if b.layers <= 0 or b.tier > sim.size_tier():
			continue
		var d := sim.kaiju_pos.distance_to(Vector2(b.x, b.z))
		if d < best_d:
			best_d = d
			best = Vector2(b.x, b.z)
	if best_d == INF or best_d < sim.stomp_radius() * 0.6:
		return Vector2.ZERO
	return (best - sim.kaiju_pos).normalized()
