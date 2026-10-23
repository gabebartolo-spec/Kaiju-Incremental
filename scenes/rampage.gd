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
## Autoplay holds the signature for AUTOPLAY_GLIDE_HELD of every AUTOPLAY_GLIDE_CYCLE steps.
const AUTOPLAY_GLIDE_CYCLE := 90
const AUTOPLAY_GLIDE_HELD := 50

var sim: RampageSim
## true (the game's own flow): _ready builds the scene in stages, one per frame, behind a
## LoadingOverlay, and nothing runs until it is done, so starting a run never freezes the screen
## (b2-30). false (tests, captures): _ready builds it all at once, as before.
var staged := false
## Rampage seconds in the adolescent city or later, from the save; set before setup (D-160).
var city_seconds := 0.0
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
## The camera's shake (trauma); any hit adds to it through add_trauma.
var shake := CameraShake.new()
var _land := StompLanding.new(shake)  # a standing stomp's cracks and camera kick
var _city: CityView
var _powers: PowersView
var _fade: VehicleFade
var _cues: PowerCues
var _hud: RampageHud
var _kaiju: KaijuModel
var _kaiju_at := Vector3.ZERO
var _follow := CameraFollow.new(Vector3.ZERO, camera_rest)
var _ability := RampageAbility.new()
var _camera: Camera3D
var _step_dip := 0.0
var _tank_nodes: Dictionary = {}
var _tanks: TankYard
var _fx_rng: RandomNumberGenerator
var _autoplay := false
var _walk := AutoWalk.new()
## Physics steps run: autoplay paces on this, never the engine clock (same run every time).
var _steps := 0
var _stomp_radius := 0.0
## Seconds a sim stomp waits for the foot that delivers it; past that it is heard but not seen.
var _stomp_wait := 0.0
## Presses made while the rise from the river holds the sim back, kept for its first live tick.
var _latch := InputLatch.new(Num.f(Content.section("emerge")["input_latch_seconds"]))


## stats: final run stats; layout: CityGrowth.layout for stats.size; run_index seeds the army and
## picks the time of day.
func setup(
	p_species: Dictionary, stats: Dictionary, layout: Array[Dictionary], run_index: int
) -> void:
	species = p_species
	ClipAlive.run_seed = run_index  # the croc's standing life draws on it (D-165)
	GraphicsPresets.start_run(PlayerSettings.graphics_row())  # counts: this run, not mid-run
	Content.set_time(Content.time_for_run(run_index))
	var ability: Dictionary = species["ability"]
	sim = RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", run_index))
	sim.ability_type = str(ability["type"])
	sim.army_units.taskforce.carried = city_seconds  # rampage time in this city so far (D-160)
	sim.emerge.start(sim)  # the kaiju rises from the river before the run begins (D-083)
	sim.body.use_species(str(species["id"]))
	_fx_rng = Seeds.make("fx", run_index)
	sfx = Sfx.new(Seeds.make("sfx", run_index))
	_cues = PowerCues.new(sim, sfx)


## Returns once the scene is built (at once when it is; flow suites and captures that start a run
## through Main wait here, as the staged build takes a number of frames).
func wait_loaded() -> void:
	while not is_loaded and is_inside_tree():
		await get_tree().process_frame


## Test hook: the kaiju walks toward the nearest building it can topple on its own.
func set_autoplay(on: bool) -> void:
	_autoplay = on


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
	_ability.bind(self, _city, _kaiju)
	_camera = Camera3D.new()
	_camera.fov = camera_fov
	add_child(_camera)
	_camera.current = true
	_start_sound()
	_place_camera(1.0)
	_add_overlays()
	if stages.overlay != null:
		stages.overlay.queue_free()
	is_loaded = true
	loaded.emit()
	get_node("/root/EventBus").emit_signal("run_started", str(species["id"]))


## The vignette and colour fringe (D-142, they read the sim), then the HUD above them.
func _add_overlays() -> void:
	add_child(PostFx.new(self))
	_hud = RampageHud.new(sim, species, _city.street)
	_hud.beat_done.connect(finished.emit)
	add_child(_hud)


func _physics_process(delta: float) -> void:
	if not is_loaded or sim.over:
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var signature := Input.is_action_just_pressed("signature")
	var held := Input.is_action_pressed("signature")
	var ultimate := Input.is_action_just_pressed("ultimate")
	var dash := Input.is_action_just_pressed("dash")
	if scripted.is_valid():  # captures: {"move", "signature", "held", "ultimate", "dash"}
		var input: Dictionary = scripted.call(sim)
		dash = input.get("dash", false)
		move = input.get("move", Vector2.ZERO)
		signature = input.get("signature", false)
		held = input.get("held", false)
		ultimate = input.get("ultimate", false)
	elif _autoplay:
		move = _walk.move(sim, _steps)
		signature = autoplay_signature and sim.ability_ready_in <= 0.0
		held = autoplay_signature and _steps % AUTOPLAY_GLIDE_CYCLE < AUTOPLAY_GLIDE_HELD
		ultimate = autoplay_signature
	# The sim ignores input while it rises from the river: a tap before the handover is kept.
	var now := {"signature": signature, "ultimate": ultimate, "dash": dash}
	now = _latch.through(sim.emerge.active, now, delta)
	signature = now["signature"]
	ultimate = now["ultimate"]
	dash = now["dash"]
	_steps += 1
	var t0 := Time.get_ticks_usec()
	var buttons := Dash.BUTTON if dash else 0
	buttons |= (RampageSim.HELD if held else 0) | (RampageSim.ULTIMATE if ultimate else 0)
	var events := sim.step(delta, move, signature, buttons)
	_note_cost("sim.step", t0)
	for event: Dictionary in events:
		var t1 := Time.get_ticks_usec()
		_on_event(event)
		_note_cost(str(event["type"]), t1)
	_update_kaiju(delta, 1.0 if sim.body.dash.on() else move.length())  # legs keep going
	_cues.update(ability_fx, _kaiju_at, _to_world(sim.facing))
	_powers.update(delta, _kaiju_at)
	_tanks.update(delta, _kaiju_at, _steps)
	_hud.refresh()


func _process(delta: float) -> void:
	if not is_loaded:
		return
	_place_camera(delta)
	_fade.update(_camera.global_position, _kaiju_at, sim.body_scale(), delta)
	shake.update(delta)
	if _stomp_wait > 0.0:
		_stomp_wait -= delta
		if _stomp_wait <= 0.0:  # no foot came down: the sound, no ring or cracks
			sfx.stomp(_power("stomp_damage"), false)


## Shakes the camera (CameraShake): `amount` trauma from a hit at `at` (Vector3.INF: at the
## kaiju), fading with its distance from the camera's focus. Explosions and every other hit use it.
func add_trauma(amount: float, at := Vector3.INF) -> void:
	shake.add(amount, at, _follow.focus, sim.body_scale())


## Worst time (usec) spent per sim step and per event kind; read by the benchmark tool.
func _note_cost(what: String, since: int) -> void:
	var spent := Time.get_ticks_usec() - since
	cost_usec[what] = maxi(Num.i(cost_usec.get(what, 0)), spent)


func _to_world(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


func _on_event(event: Dictionary) -> void:
	match str(event["type"]):
		"stomp":
			_land.lift(_kaiju)
			# The sim decides the damage now; the ring, cracks and crush wait for the foot that
			# delivers the stomp (_on_footfall), so they land where and when a foot does.
			_stomp_radius = Num.f(event["radius"])
			_stomp_wait = STOMP_WAIT
			add_trauma(shake.source("stomp"))
		"ability":
			_kaiju.roar()
			_ability.play(event, _kaiju_at, _power("ability_damage"))
		"chunks_broken":
			var cells: Array[Vector3i] = event["cells"]
			_on_chunks_broken(Num.i(event["building"]), cells, Num.f(event.get("pay", 1.0)))
		"fall_start":
			_city.fall_start(event)
		"fall_land":
			_city.fall_land(event)
			sfx.collapse(str(event["kind"]) == "topple")
			var b := sim.buildings[Num.i(event["building"])]
			var topple := str(event["kind"]) == "topple"
			add_trauma(shake.source("topple" if topple else "drop"), Vector3(b.x, 0.0, b.z))
		"tank_spawned", "tank_fired", "tank_destroyed", "stray_landed":
			_tanks.on_event(event, _kaiju_at)
		"building_regrown":
			_city.regrow(Num.i(event["building"]))
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


func _update_kaiju(delta: float, moving: float) -> void:
	var target := _to_world(sim.kaiju_pos)
	target.y = sim.stand_y + (GLIDE_LIFT * sim.body_scale() if sim.airborne else 0.0)
	_kaiju_at = _ability.step(delta, target, _kaiju_at)
	_kaiju.position = _kaiju_at
	_kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
	# sim angle to model yaw: the sign flips
	_kaiju.follow_steps(sim.body.step_clock(), sim.body.step_ratio)
	_kaiju.animate(delta, moving, -sim.body.turn_left)


## Every footfall kicks a little dust, nudges the camera and sounds a step (or the stomp that
## was waiting for this foot), so what you hear lands with what you see.
func _on_footfall(side: String, strength: float, at: Vector3) -> void:
	var stomped := _stomp_wait > 0.0 and side != "tail"
	if stomped:
		_land_stomp(side, at)
	sfx.footstep(strength)
	var size := sim.body_scale() * (0.2 + strength)
	if side != "tail":  # a tail slam throws its own puffs (Fx.shockwave)
		_city.fx.footfall(at + Vector3(0, 0.2, 0), FOOTFALL_DUST * size)
	var ring := _stomp_radius * 1.3 * Fx.STOMP_RING if stomped else FOOTFALL_RING * size
	_city.fx.shockwave(at, ring, side == "tail", stomped)
	_step_dip = maxf(
		_step_dip, FOOTFALL_DIP * maxf(FOOTFALL_DIP_FLOOR, sim.body_scale()) * strength
	)


## The waiting stomp lands under the foot that delivers it: cracks (if heavy enough), the street
## crushed around that foot, one dust ripple. Sound is released by the same footfall (Sfx.footstep).
func _land_stomp(side: String, at: Vector3) -> void:
	_stomp_wait = 0.0
	var heavy := _power("stomp_damage")
	sfx.stomp(heavy, _land.landed(side, ability_fx.stomp_cracks(at, _stomp_radius, heavy)))
	var street := _city.street  # the foot lands wider than its ring (stomp_catch)
	var catch := street.tune("stomp_catch") * sim.body_scale() if street != null else 0.0
	_city.crush(at, _stomp_radius + catch)
	stomp_ring_at.append(at)


## The sound hears the world: the sfx its camera, helicopters and street; CitySound (D-155) the sim
## and the street, to set the city's beds and the music layers.
func _start_sound() -> void:
	sfx.watch(_camera, _powers, _city.street)
	add_child(CitySound.new(sim, _city.street, sfx))


func _place_camera(delta: float) -> void:
	var zoom := CameraTuning.zoom(sim.body_scale())
	_step_dip = move_toward(_step_dip, 0.0, delta * DIP_RECOVER * _step_dip + delta * 0.05)
	var motion := PlayerSettings.motion()  # the player's camera motion: shake, dip
	# Follow the body as drawn (KaijuModel.focus), eased: an insect's hold settles still on screen
	# and its dart bursts ahead of the camera.
	_follow.step(
		_kaiju.focus(), camera_rest * zoom - Vector3(0, _step_dip * zoom * motion, 0), delta
	)
	var hold := sim.body.dash.on() or _ability.leaping()
	_follow.step_lead(_kaiju.position, sim.body_scale(), hold, delta)
	_camera.position = _follow.eye()
	var nod := shake.turn(sim.body_scale(), motion).y
	_camera.look_at(_follow.aim(_kaiju, sim.body_scale(), Vector2(camera_fov, nod), delta))
	_city.drawn_sight = _follow.sight()
	shake.apply(_camera, sim.body_scale(), motion)
