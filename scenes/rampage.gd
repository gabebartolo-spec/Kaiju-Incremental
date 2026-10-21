class_name Rampage
extends Node3D
## Presents one rampage. Reads input, steps RampageSim, and turns its events into the city
## view, the kaiju, the tanks, the camera and the HUD. It never decides an outcome; when the
## sim ends, the HUD plays the end beat, then `finished` reports the result. Esc pauses.

signal finished(result: Dictionary)
## The run's scene is built and the sim is stepping (see `staged`).
signal loaded

## Footfall: dust and a pale ground ring (per body scale), camera dip (units) and its return (1/s).
const FOOTFALL_DUST := 1.1
const FOOTFALL_RING := 1.4
const STOMP_WAIT := 0.6  # s, about one stride: the next footfall is the stomp
const FOOTFALL_DIP := 0.35
## The dip scales with body size, but never below this: a baby still shakes the street.
const FOOTFALL_DIP_FLOOR := 1.0
const DIP_RECOVER := 4.0
## How high a gliding insectoid hovers (per body scale).
const GLIDE_LIFT := 3.0

var sim: RampageSim
## true (the game's own flow): _ready builds the scene in stages, one per frame, behind a
## LoadingOverlay, and nothing runs until it is done, so starting a run never freezes the screen
## (b2-30). false (tests, captures): _ready builds it all at once, as before.
var staged := false
## Whether the scene is built (always true after _ready when not staged).
var is_loaded := false
## Worst cost per sim step / event kind, in microseconds (benchmarking).
var cost_usec: Dictionary = {}
var species: Dictionary
## The look and the sounds of the signature attack and the upgrades (read by the flow suite).
var ability_fx: AbilityFx
var sfx: Sfx
## Autoplay fires the signature whenever it is ready (captures turn this off to time it).
var autoplay_signature := true
## Capture hook: when set, called with the sim each physics frame for the player's input.
var scripted: Callable
## Where each stomp landed (the foot's ground point), for the capture and the tests.
var stomp_ring_at: Array[Vector3] = []
## The gameplay camera at rest (data/tuning.json "camera"): offset from the kaiju's focus, FOV.
var camera_rest := CameraTuning.offset()
var camera_fov := CameraTuning.fov()
## Main: whether this run plays the whole intro (the first run, the first after an evolution) or
## its short cut (RunIntro).
var full_intro := true
var _city: CityView
var _powers: PowersView
var _fade: VehicleFade
var _was_ready := true
var _leap_reach := 0.0
var _leap_power := 1.0
var _hud: RampageHud
var _kaiju: KaijuModel
var _kaiju_at := Vector3.ZERO
var _follow := CameraFollow.new(Vector3.ZERO, camera_rest)
var _leap_time := 0.0
var _leap_from := Vector3.ZERO
var _camera: Camera3D
var _shake := 0.0
var _step_dip := 0.0
var _tank_nodes: Dictionary = {}
var _tanks: TankYard
var _fx_rng: RandomNumberGenerator
var _topple_cfg: Dictionary = Content.section("topple_fx")
## Seconds since the breath camera move began; negative when the camera is at rest.
var _breath_camera := BreathCamera.new()
## Physics steps run: autoplay paces on this, never the engine clock (same run every time).
var _steps := 0
var _stomp_radius := 0.0
## Seconds a sim stomp waits for the foot that delivers it; past that it is heard but not seen.
var _stomp_wait := 0.0
var _reader := RunInput.new()
var _intro: RunIntro


## stats: final run stats; layout: CityGrowth.layout for stats.size; run_index seeds the army and
## picks the time of day.
func setup(
	p_species: Dictionary, stats: Dictionary, layout: Array[Dictionary], run_index: int
) -> void:
	species = p_species
	Content.set_time(Content.time_for_run(run_index))
	var ability: Dictionary = species["ability"]
	sim = RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", run_index))
	sim.ability_type = str(ability["type"])
	sim.body.use_species(str(species["id"]))  # first: the rise is placed by the body's length
	sim.emerge.start(sim)  # the kaiju rises from the river before the run begins (D-083)
	_fx_rng = Seeds.make("fx", run_index)
	sfx = Sfx.new(Seeds.make("sfx", run_index))


## Returns once the scene is built (at once when it is; flow suites and captures that start a run
## through Main wait here, as the staged build takes a number of frames).
func wait_loaded() -> void:
	while not is_loaded and is_inside_tree():
		await get_tree().process_frame


## Test hook: the kaiju walks toward the nearest building it can topple on its own.
func set_autoplay(on: bool) -> void:
	_reader.autoplay = on


func _ready() -> void:
	var stages := BuildStages.new()
	stages.on = staged
	if staged:
		stages.overlay = LoadingOverlay.new()
		add_child(stages.overlay)
		if not await stages.next(self):
			return
	_city = CityView.new(sim, _fx_rng)
	_city.stages = stages
	add_child(_city)
	while not _city.is_loaded:  # staged: the city builds itself over the next frames
		if not await stages.next(self, false):
			return
	var colors: Dictionary = species["colors"]
	var cone := deg_to_rad(Num.f(sim.city["cone_half_angle_deg"]))
	ability_fx = AbilityFx.new(_city, Color(str(colors["eye"])), sim.body_scale(), cone)
	add_child(ability_fx)
	if not await stages.next(self):
		return
	add_child(BreathAim.new(sim, Color(str(colors["eye"]))))  # where a ready breath will burn
	add_child(sfx)
	sfx.set_size_tier(sim.size_tier())
	_kaiju = KaijuModel.new(str(species["id"]), colors, KaijuModel.stage_for(sim.size_tier()))
	add_child(_kaiju)
	if not await stages.next(self):
		return
	ability_fx.attach_body(_kaiju)
	_powers = PowersView.new(sim, _city, _kaiju, Color(str(colors["eye"])))
	add_child(_powers)
	add_child(RiverView.new(sim, _city.fx))
	add_child(IntroWater.new(sim, _city.fx, _city.ground_opacity))
	_intro = RunIntro.new(sim, full_intro)
	TankModel.new().free()  # built once now, so the army's first spawn reuses their voxels
	HelicopterModel.new().free()
	_tanks = TankYard.new(self, sim, _city, _tank_nodes)
	_fade = VehicleFade.new(func() -> Array: return _tank_nodes.values(), _powers.helis)
	_kaiju_at = _to_world(sim.kaiju_pos) + Vector3(0, sim.stand_y, 0)  # under the river at first
	_kaiju.position = _kaiju_at
	_follow.focus = _kaiju_at
	_kaiju.scale = Vector3.ONE * sim.body_scale()
	_kaiju.set_grip_finder(
		func(at: Vector3, r: float) -> Vector3: return KaijuGrip.point(sim, at, r)
	)
	_kaiju.foot_planted.connect(_on_footfall)
	_camera = Camera3D.new()
	_camera.fov = camera_fov
	add_child(_camera)
	_camera.current = true
	sfx.watch(_camera, _powers, _city.street)
	_hud = RampageHud.new(sim, species, _city.street)
	_hud.beat_done.connect(finished.emit)
	add_child(_hud)
	_place_camera(1.0)  # after the HUD: the intro hides it
	if stages.overlay != null:
		stages.overlay.queue_free()
	is_loaded = true
	loaded.emit()
	get_node("/root/EventBus").emit_signal("run_started", str(species["id"]))


func _physics_process(delta: float) -> void:
	if not is_loaded or sim.over:
		return
	var now := _reader.read(self, _steps, delta)
	var move: Vector2 = now["move"]
	var signature: bool = now["signature"]
	_steps += 1
	var buttons := (Dash.BUTTON if now["dash"] else 0) | (RampageSim.HELD if now["held"] else 0)
	buttons |= RampageSim.ULTIMATE if now["ultimate"] else 0
	var wading := sim.emerge.risen() >= 1.0 and sim.emerge.active
	var ticks := _intro.ticks()  # the intro's short cut and skip run the rise's ticks faster
	for k: int in ticks:
		if k > 0 and not sim.emerge.active:
			break  # the first live tick takes this frame's presses, once
		_step_sim(delta, move, signature, buttons)
	var moving := 1.0 if sim.body.dash.on() or wading else move.length()  # legs keep going
	_update_kaiju(delta * ticks, moving)
	_update_powers()
	_powers.update(delta, _kaiju_at)
	_tanks.update(delta, _kaiju_at, _steps)
	_hud.refresh()


func _step_sim(delta: float, move: Vector2, signature: bool, buttons: int) -> void:
	var t0 := Time.get_ticks_usec()
	var events := sim.step(delta, move, signature, buttons)
	_note_cost("sim.step", t0)
	for event: Dictionary in events:
		var t1 := Time.get_ticks_usec()
		_on_event(event)
		_note_cost(str(event["type"]), t1)


func _input(event: InputEvent) -> void:
	if _intro != null:
		_intro.on_input(event)


func _process(delta: float) -> void:
	if not is_loaded:
		return
	_place_camera(delta)
	_fade.update(_camera.global_position, _kaiju_at, sim.body_scale(), delta)
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _stomp_wait > 0.0:
		_stomp_wait -= delta
		if _stomp_wait <= 0.0:  # no foot came down: the sound, no ring or cracks
			sfx.stomp(_power("stomp_damage"), false)


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
			# The sim decides the damage now; the ring, cracks and crush wait for the foot that
			# delivers the stomp (_on_footfall), so they land where and when a foot does.
			_stomp_radius = Num.f(event["radius"])
			_stomp_wait = STOMP_WAIT
			_shake = maxf(_shake, 0.15)
		"ability":
			_kaiju.roar()
			_ability_fx(event)
		"chunks_broken":
			var cells: Array[Vector3i] = event["cells"]
			_on_chunks_broken(Num.i(event["building"]), cells, Num.f(event.get("pay", 1.0)))
		"fall_start":
			_city.fall_start(event)
		"fall_land":
			_city.fall_land(event)
			sfx.collapse(str(event["kind"]) == "topple")
			var topple := str(event["kind"]) == "topple"
			_shake = maxf(_shake, Num.f(_topple_cfg["shake"]) if topple else 0.3)
		"deck_burst":
			_city.deck_burst()
			_shake = maxf(_shake, 0.3)
		"surface_break":  # the head breaks the water: he roars with rage (#11, R 20.3)
			_kaiju.roar(Num.f(Content.section("intro")["roar_jaw_seconds"]))
			Sfx.roar(self)
		"tank_spawned":
			_tanks.spawn(Num.i(event["tank"]))
		"tank_fired":
			var at: Vector2 = event.get("at", sim.kaiju_pos)
			if _tanks.fire(Num.i(event["tank"]), _to_world(at), _kaiju_at):
				_shake = maxf(_shake, 0.08)
		"tank_destroyed":
			var at := Vector3(Num.f(event["x"]), 0.5, Num.f(event["z"]))
			_tanks.destroy(Num.i(event["tank"]), at)
		"kaiju_emerged":
			_hud.visible = true
		"run_over":
			_hud.run_over(str(event["reason"]))
		_:
			_powers.on_event(event, _kaiju_at)


func _on_chunks_broken(index: int, cells: Array[Vector3i], pay: float) -> void:
	_city.chunks_broken(index, cells, _kaiju_at)
	var b := sim.buildings[index]
	var per := b.tier * Num.f(sim.city["chunk_rubble"]) * sim.stat("rubble_mult") * pay
	var gained := cells.size() * per
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
	_city.crush(_to_world(sim.kaiju_pos), reach * (0.5 if str(event["kind"]) == "cone" else 1.0))
	match str(event["kind"]):
		"cone":
			var facing := _to_world(sim.facing)
			var chest := _kaiju_at + (Vector3(0, 6.0, 0) + facing) * sim.body_scale()
			var mouth := BreathBeam.mouth_of(_kaiju, chest)  # the jaw, where the model has one
			var from: Vector2 = event["from"]  # the sim's cone (BreathCone) starts at the snout
			var snout := _to_world(from)
			var span := snout + facing * reach + Vector3(0, 0.5, 0) - mouth  # to full reach
			ability_fx.cone_origin = snout
			ability_fx.breath(mouth, span, ability_fx.cone_half_angle, strength)
			_city.crush_cone(BreathCone.of(sim))  # trees and cars burn flat along it
			sfx.play("breath")
			_breath_camera.start(1.0 if sim.facing.x >= 0.0 else -1.0)
		"leap":
			var from: Vector2 = event["from"]
			_leap_from = _to_world(from)
			_leap_time = 0.0001
			_leap_reach = reach
			_leap_power = strength
			ability_fx.leap_takeoff(_leap_from)
			sfx.play("leap_whoosh")
		_:
			ability_fx.lash(_kaiju_at, reach, strength)
			sfx.play("lash")


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
			sfx.play("leap_land")
			_shake = maxf(_shake, 0.5)
	else:
		_kaiju_at = _kaiju_at.lerp(target, 1.0 if sim.body.dash.on() else minf(1.0, delta * 12.0))
	_kaiju.position = _kaiju_at
	_kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
	_kaiju.animate(delta, moving)


## Signature Recharge's ready pulse and Regeneration's motes.
func _update_powers() -> void:
	var charged := sim.ability_ready_in <= 0.0
	if charged and not _was_ready:
		var head := _kaiju_at + Vector3(0, 6.0, 0) * sim.body_scale()
		ability_fx.ready_pulse(_kaiju_at, head + _to_world(sim.facing) * sim.body_scale())
		sfx.play("ready")
	_was_ready = charged
	var healing := sim.stat("regen") > 0.0 and sim.hp < sim.max_hp
	ability_fx.regen(_kaiju_at + Vector3(0, 3.0 * sim.body_scale(), 0), healing)
	sfx.regen(healing)


## Every footfall kicks a little dust, nudges the camera and sounds a step (or the stomp that
## was waiting for this foot), so what you hear lands with what you see.
func _on_footfall(side: String, strength: float, at: Vector3) -> void:
	var stomped := _stomp_wait > 0.0 and side != "tail"
	if stomped:
		_land_stomp(at)
	sfx.footstep(strength)
	var size := sim.body_scale() * (0.2 + strength)
	if side != "tail":  # a tail slam throws its own puffs (Fx.shockwave)
		_city.fx.footfall(at + Vector3(0, 0.2, 0), FOOTFALL_DUST * size)
	var ring := _stomp_radius * 1.3 if stomped else FOOTFALL_RING * size
	_city.fx.shockwave(at, ring, side == "tail")
	_step_dip = maxf(
		_step_dip, FOOTFALL_DIP * maxf(FOOTFALL_DIP_FLOOR, sim.body_scale()) * strength
	)


## The waiting stomp lands under the foot that delivers it: cracks (if heavy enough), the street
## crushed around that foot, one dust ripple. Sound is released by the same footfall (Sfx.footstep).
func _land_stomp(at: Vector3) -> void:
	_stomp_wait = 0.0
	var heavy := _power("stomp_damage")
	sfx.stomp(heavy, ability_fx.stomp_cracks(at, _stomp_radius, heavy))
	_city.crush(at, _stomp_radius)
	stomp_ring_at.append(at)


func _place_camera(delta: float) -> void:
	var zoom := CameraTuning.zoom(sim.body_scale())
	_step_dip = move_toward(_step_dip, 0.0, delta * DIP_RECOVER * _step_dip + delta * 0.05)
	# Follow the body as drawn (KaijuModel.focus), eased: an insect's hold settles still on screen
	# and its dart bursts ahead of the camera.
	var rest := _breath_camera.offset(camera_rest, delta)
	_follow.step(_kaiju.focus(), rest * zoom - Vector3(0, _step_dip * zoom, 0), delta)
	var aim := _follow.look_at(sim.body_scale())
	if sim.emerge.active:  # the run intro's shot, ending on this camera (RunIntro)
		var frac := Engine.get_physics_interpolation_fraction()
		var shot := RunIntro.shot(sim, _follow, camera_fov, frac)
		var eye: Vector3 = shot["eye"]
		_follow.hold(eye)
		aim = shot["aim"]
		_camera.fov = Num.f(shot["fov"])
		_hud.visible = get_tree().paused  # no HUD over the intro (the pause menu shows)
	else:
		_camera.fov = camera_fov
	_camera.position = _follow.eye()
	var jitter := Vector3(_fx_rng.randf_range(-1, 1), _fx_rng.randf_range(-1, 1), 0) * _shake * 0.6
	_camera.look_at(aim + jitter)
