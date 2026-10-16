class_name Rampage
extends Node3D
## Presents one rampage. Reads input, steps RampageSim, and turns its events into the city
## view, the kaiju, the tanks, the camera and the HUD. It never decides an outcome; when the
## sim ends, the HUD shows the result and Continue emits finished.

signal finished(result: Dictionary)

## Footfall: dust size and a pale ground ring (per body scale), and how far the camera dips
## (world units at full strength) and how fast it comes back (1/s).
const FOOTFALL_DUST := 1.1
const FOOTFALL_RING := 1.4
const FOOTFALL_TINT := Color(0.86, 0.83, 0.76, 0.7)
const FOOTFALL_DIP := 0.35
## The dip scales with body size, but never below this: a baby still shakes the street.
const FOOTFALL_DIP_FLOOR := 1.0
const DIP_RECOVER := 4.0
const CAMERA_OFFSET := Vector3(0, 27, 19)
const TANK_GREEN := Color("55613a")
## How high a gliding insectoid hovers (per body scale).
const GLIDE_LIFT := 3.0
## Autoplay holds the signature for AUTOPLAY_GLIDE_HELD of every AUTOPLAY_GLIDE_CYCLE steps.
const AUTOPLAY_GLIDE_CYCLE := 90
const AUTOPLAY_GLIDE_HELD := 50

var sim: RampageSim
## Worst cost per sim step / event kind, in microseconds (benchmarking).
var cost_usec: Dictionary = {}
var species: Dictionary
## The look of the signature attack and the upgrades (read by the flow suite).
var ability_fx: AbilityFx
## Autoplay fires the signature whenever it is ready (captures turn this off to time it).
var autoplay_signature := true
## Capture hook: when set, called with the sim each physics frame for the player's input.
var scripted: Callable
var _city: CityView
var _powers: PowersView
var _was_ready := true
var _leap_reach := 0.0
var _leap_power := 1.0
var _hud: RampageHud
var _kaiju: KaijuModel
var _kaiju_at := Vector3.ZERO
var _leap_time := 0.0
var _leap_from := Vector3.ZERO
var _camera: Camera3D
var _shake := 0.0
var _step_dip := 0.0
var _tank_nodes: Dictionary = {}
var _fx_rng: RandomNumberGenerator
var _too_tall_cooldown := 0.0
var _autoplay := false
## Seconds since the breath camera move began; negative when the camera is at rest.
var _orbit_t := -1.0
var _orbit_side := 1.0
var _autoplay_target := Vector2(INF, INF)
## Physics steps this rampage has run: autoplay paces itself on this, never the engine clock,
## so a run plays the same whatever ran before it.
var _steps := 0


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
	ability_fx = AbilityFx.new(_city, Color(str(colors["eye"])), sim.body_scale())
	add_child(ability_fx)
	_kaiju = KaijuModel.new(str(species["id"]), colors, KaijuModel.stage_for(sim.size_tier()))
	add_child(_kaiju)
	ability_fx.attach_body(_kaiju)
	_powers = PowersView.new(sim, _city, _kaiju, Color(str(colors["eye"])))
	add_child(_powers)
	_kaiju_at = _to_world(sim.kaiju_pos)
	_kaiju.position = _kaiju_at
	_kaiju.scale = Vector3.ONE * sim.body_scale()
	_kaiju.set_grip_finder(
		func(at: Vector3, r: float) -> Vector3: return KaijuGrip.point(sim, at, r)
	)
	_kaiju.foot_planted.connect(_on_footfall)
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
	var held := Input.is_action_pressed("signature")
	var ultimate := Input.is_action_just_pressed("ultimate")
	if scripted.is_valid():  # captures: {"move", "signature", "held", "ultimate"} per frame
		var input: Dictionary = scripted.call(sim)
		move = input.get("move", Vector2.ZERO)
		signature = input.get("signature", false)
		held = input.get("held", false)
		ultimate = input.get("ultimate", false)
	elif _autoplay:
		move = _autoplay_move()
		signature = autoplay_signature and sim.ability_ready_in <= 0.0
		held = autoplay_signature and _steps % AUTOPLAY_GLIDE_CYCLE < AUTOPLAY_GLIDE_HELD
		ultimate = autoplay_signature
	_steps += 1
	var t0 := Time.get_ticks_usec()
	var buttons := (RampageSim.HELD if held else 0) | (RampageSim.ULTIMATE if ultimate else 0)
	var events := sim.step(delta, move, signature, buttons)
	_note_cost("sim.step", t0)
	for event: Dictionary in events:
		var t1 := Time.get_ticks_usec()
		_on_event(event)
		_note_cost(str(event["type"]), t1)
	_too_tall_cooldown = maxf(0.0, _too_tall_cooldown - delta)
	_update_kaiju(delta, move.length())
	_update_powers()
	_powers.update(delta, _kaiju_at)
	_update_tanks()
	_hud.refresh()


func _process(delta: float) -> void:
	_place_camera(delta)
	_shake = maxf(0.0, _shake - delta * 3.0)


## Worst time (usec) spent per sim step and per event kind; read by the benchmark tool.
func _note_cost(what: String, since: int) -> void:
	var spent := Time.get_ticks_usec() - since
	cost_usec[what] = maxi(Num.i(cost_usec.get(what, 0)), spent)


func _to_world(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


func _on_event(event: Dictionary) -> void:
	match str(event["type"]):
		"stomp":
			_kaiju.stomp()
			_city.fx.shockwave(_kaiju_at, Num.f(event["radius"]) * 1.3)
			ability_fx.stomp_cracks(_kaiju_at, Num.f(event["radius"]), _power("stomp_damage"))
			_city.crush(_kaiju_at, Num.f(event["radius"]))
			_shake = maxf(_shake, 0.15)
		"ability":
			_kaiju.roar()
			_ability_fx(event)
		"chunks_broken":
			var cells: Array[Vector3i] = event["cells"]
			_on_chunks_broken(Num.i(event["building"]), cells)
		"fall_start":
			_city.fall_start(event)
		"fall_land":
			_city.fall_land(event)
			_shake = maxf(_shake, 0.6 if str(event["kind"]) == "topple" else 0.3)
		"tough":
			if _too_tall_cooldown <= 0.0:
				_too_tall_cooldown = 2.5
				var b := sim.buildings[Num.i(event["building"])]
				_city.float_text("TOO STRONG - UNDERMINE IT", Vector3(b.x, 4.0, b.z), UiKit.WARN)
		"tank_spawned":
			_spawn_tank_node(Num.i(event["tank"]))
		"tank_fired":
			var at: Vector2 = event.get("at", sim.kaiju_pos)
			_tank_fired(Num.i(event["tank"]), _to_world(at))
		"tank_destroyed":
			var at := Vector3(Num.f(event["x"]), 0.5, Num.f(event["z"]))
			_tank_destroyed(Num.i(event["tank"]), at)
		"run_over":
			_hud.refresh()
			_hud.show_results()
			get_node("/root/EventBus").emit_signal("run_ended", sim.result())
		_:
			_powers.on_event(event, _kaiju_at)


func _on_chunks_broken(index: int, cells: Array[Vector3i]) -> void:
	_city.chunks_broken(index, cells, _kaiju_at)
	var b := sim.buildings[index]
	var gained := cells.size() * b.tier * Num.f(sim.city["chunk_rubble"]) * sim.stat("rubble_mult")
	if gained >= 1.0:
		var at := b.chunk_world(cells[0]) + Vector3(0, 2.0, 0)
		_city.float_text("+%d" % Num.i(gained), at, UiKit.WARN)


## How far an upgraded stat is above the species' own value (1 = not upgraded).
func _power(stat_name: String) -> float:
	var base: Dictionary = species["stats"]
	return ability_fx.power(sim.stat(stat_name), Num.f(base[stat_name]))


func _ability_fx(event: Dictionary) -> void:
	var reach := Num.f(event["reach"])
	var strength := _power("ability_damage")
	_shake = maxf(_shake, 0.45)
	var colors: Dictionary = species["colors"]
	var eye := Color(str(colors["eye"]))
	_city.crush(_to_world(sim.kaiju_pos), reach * (0.5 if str(event["kind"]) == "cone" else 1.0))
	match str(event["kind"]):
		"cone":
			var facing := _to_world(sim.facing)
			var mouth := (
				_kaiju_at + Vector3(0, 6.0, 0) * sim.body_scale() + facing * sim.body_scale()
			)
			var span := facing * reach + Vector3(0, -mouth.y + 0.5, 0)
			_city.fx.breath(mouth, span, eye)
			var half_angle := deg_to_rad(Num.f(sim.city["cone_half_angle_deg"]))
			ability_fx.breath(mouth, span, half_angle, strength)
			_orbit_t = 0.0
			_orbit_side = 1.0 if sim.facing.x >= 0.0 else -1.0
		"leap":
			var from: Vector2 = event["from"]
			_leap_from = _to_world(from)
			_leap_time = 0.0001
			_leap_reach = reach
			_leap_power = strength
			ability_fx.leap_takeoff(_leap_from)
		_:
			ability_fx.lash(_kaiju_at, reach, strength)


func _update_kaiju(delta: float, moving: float) -> void:
	var target := _to_world(sim.kaiju_pos)
	target.y = sim.stand_y + (GLIDE_LIFT * sim.body_scale() if sim.airborne else 0.0)
	if _leap_time > 0.0:
		_leap_time += delta
		var t := clampf(_leap_time / 0.4, 0.0, 1.0)
		_kaiju_at = _leap_from.lerp(target, t) + Vector3(0, sin(t * PI) * 6.0, 0)
		ability_fx.leap_trail(_kaiju_at + Vector3(0, 3.0 * sim.body_scale(), 0), t < 1.0)
		if t >= 1.0:
			_leap_time = 0.0
			_kaiju_at = target
			ability_fx.leap_land(target, _leap_reach, _leap_power)
			_shake = maxf(_shake, 0.5)
	else:
		_kaiju_at = _kaiju_at.lerp(target, minf(1.0, delta * 12.0))
	_kaiju.position = _kaiju_at
	var heading := atan2(-sim.facing.x, -sim.facing.y)
	_kaiju.rotation.y = lerp_angle(_kaiju.rotation.y, heading, minf(1.0, delta * 10.0))
	_kaiju.animate(delta, moving)


## Signature Recharge's ready pulse and Regeneration's motes.
func _update_powers() -> void:
	var charged := sim.ability_ready_in <= 0.0
	if charged and not _was_ready:
		ability_fx.ready_pulse(_kaiju_at)
	_was_ready = charged
	var healing := sim.stat("regen") > 0.0 and sim.hp < sim.max_hp
	ability_fx.regen(_kaiju_at + Vector3(0, 3.0 * sim.body_scale(), 0), healing)


## Every footfall kicks a little dust and nudges the camera (a minimal version until the
## ability-sfx pass drives footstep sound, dust and shake from the same signal).
func _on_footfall(_side: String, strength: float, at: Vector3) -> void:
	var size := sim.body_scale() * (0.2 + strength)
	_city.fx.dust(at + Vector3(0, 0.2, 0), FOOTFALL_DUST * size)
	_city.fx.shockwave(at, FOOTFALL_RING * size, FOOTFALL_TINT)
	_step_dip = maxf(
		_step_dip, FOOTFALL_DIP * maxf(FOOTFALL_DIP_FLOOR, sim.body_scale()) * strength
	)


func _spawn_tank_node(id: int) -> void:
	var tank := TankModel.new()
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
	var flatten := _steps % 10 == 0  # tanks roll over cars and lamps
	for tank: RampageSim.Tank in sim.tanks:
		if flatten:
			_city.crush(_to_world(tank.pos), 1.4)
		if not _tank_nodes.has(tank.id):
			continue
		var node: Node3D = _tank_nodes[tank.id]
		node.position = _to_world(tank.pos)
		var to := sim.kaiju_pos - tank.pos
		if to.length() > 0.01:
			node.rotation.y = atan2(-to.x, -to.y)


func _tank_fired(id: int, at: Vector3) -> void:
	if not _tank_nodes.has(id):
		return
	var node: Node3D = _tank_nodes[id]
	var target := at + Vector3(0, 1.0, 0)
	if at.distance_to(_to_world(sim.kaiju_pos)) < 0.01:
		target = _kaiju_at + Vector3(0, 4.0 * sim.body_scale(), 0)
	var shell := _part(Vector3.ONE * 0.35, node.position + Vector3(0, 0.9, 0), UiKit.WARN)
	shell.material_override = CityView.glow(UiKit.WARN, 4.0)
	add_child(shell)
	_city.flash(node.position + Vector3(0, 1.0, 0), Color("ffc070"), 4.0, 0.12)
	var tween := shell.create_tween()
	tween.tween_property(shell, "position", target, 0.22)
	if sim.stat("armor") > 0.0:
		var away := (node.position - target).normalized() + Vector3.UP * 0.5
		tween.tween_callback(func() -> void: ability_fx.deflect(target, away))
	else:
		tween.tween_callback(func() -> void: _city.fx.sparks(target))
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
	_city.flash(pos + Vector3(0, 1.0, 0), Color("ff8a3a"), 7.0, 0.5)
	_city.fire(pos, 0.6)
	var gained := Num.f(sim.army["tank_rubble"]) * sim.stat("rubble_mult")
	_city.float_text("+%d" % Num.i(gained), pos + Vector3(0, 2, 0), UiKit.WARN)


func _place_camera(delta: float) -> void:
	var zoom := 0.75 + 0.4 * sim.body_scale()
	_step_dip = move_toward(_step_dip, 0.0, delta * DIP_RECOVER * _step_dip + delta * 0.05)
	var target := _kaiju_at + _breath_orbit(delta) * zoom - Vector3(0, _step_dip * zoom, 0)
	_camera.position = _camera.position.lerp(target, minf(1.0, delta * 5.0))
	var jitter := Vector3(_fx_rng.randf_range(-1, 1), _fx_rng.randf_range(-1, 1), 0) * _shake * 0.6
	_camera.look_at(_kaiju_at + Vector3(0, 3.5 * sim.body_scale(), 0) + jitter)


## The camera offset, swung to the side and lifted while Atomic Breath fires so the beam crosses
## the screen instead of running straight away from the camera; the kaiju stays framed.
func _breath_orbit(delta: float) -> Vector3:
	if _orbit_t < 0.0:
		return CAMERA_OFFSET
	_orbit_t += delta
	var fx: Dictionary = Content.section("fx")
	var ease_in := Num.f(fx["orbit_in_seconds"])
	var hold := ease_in + Num.f(fx["beam_seconds"])
	var ease_out := Num.f(fx["orbit_out_seconds"])
	var w := smoothstep(0.0, ease_in, _orbit_t)
	if _orbit_t > hold:
		w = 1.0 - smoothstep(hold, hold + ease_out, _orbit_t)
	if _orbit_t > hold + ease_out:
		_orbit_t = -1.0
	var turn := deg_to_rad(Num.f(fx["orbit_degrees"])) * w * _orbit_side
	return CAMERA_OFFSET.rotated(Vector3.UP, turn) + Vector3(0, Num.f(fx["orbit_rise"]) * w, 0)


func _autoplay_move() -> Vector2:
	if _steps % 15 == 0 or _autoplay_target.x == INF:
		_autoplay_target = sim.nearest_standing(sim.kaiju_pos)
	if (
		_autoplay_target.x == INF
		or sim.kaiju_pos.distance_to(_autoplay_target) < sim.stomp_radius() * 0.5
	):
		return Vector2.ZERO
	return (_autoplay_target - sim.kaiju_pos).normalized()
