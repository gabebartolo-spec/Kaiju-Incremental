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
## Main: whether this run plays the whole intro (the first run, the first after an evolution) or
## its short cut (RunIntro).
var full_intro := true
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
	GraphicsPresets.start_run(PlayerSettings.graphics_row())  # counts: this run, not mid-run
	Content.set_time(Content.time_for_run(run_index))
	var ability: Dictionary = species["ability"]
	sim = RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", run_index))
	sim.ability_type = str(ability["type"])
	sim.body.use_species(str(species["id"]))  # first: the rise is placed by the body's length
	sim.army_units.taskforce.carried = city_seconds  # rampage time in this city so far (D-160)
	sim.emerge.start(sim)  # the kaiju rises from the river before the run begins (D-083)
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
	_reader.autoplay = on


## Leaving the tree (Main._swap frees the rampage next): the sim's parts point back at it, so a
## dropped sim is never freed; let go of them (RampageSim.dispose, D-179) or every rampage played
## keeps its city in memory for good. The children have left already, nothing reads the sim.
func _exit_tree() -> void:
	if sim != null:
		sim.dispose()


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
	_add_rise()
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
	_add_overlays()
	_place_camera(1.0)  # after the HUD: the intro hides it
	if stages.overlay != null:
		stages.overlay.queue_free()
	is_loaded = true
	loaded.emit()
	get_node("/root/EventBus").emit_signal("run_started", str(species["id"]))


## The rise from the river: its splashes, the intro's ripples and fount, and the intro's pacing.
func _add_rise() -> void:
	add_child(RiverView.new(sim, _city.fx))
	add_child(IntroWater.new(sim, _city.fx))
	_intro = RunIntro.new(sim, full_intro)


## The vignette and colour fringe (D-142, they read the sim), then the HUD above them.
func _add_overlays() -> void:
	add_child(PostFx.new(self))
	_hud = RampageHud.new(sim, species, _city.street)
	_hud.beat_done.connect(finished.emit)
	add_child(_hud)


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
	_cues.update(ability_fx, _kaiju_at, _to_world(sim.facing))
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
			if not _on_rise(event):
				_powers.on_event(event, _kaiju_at)


## The rise from the river's events (Emergence); false for any other.
func _on_rise(event: Dictionary) -> bool:
	match str(event["type"]):
		"deck_burst":
			_city.deck_burst()
			add_trauma(shake.source("drop"))
		"surface_break":  # the head breaks the water: he roars with rage (#11, R 20.3)
			_kaiju.roar(Num.f(Content.section("intro")["roar_jaw_seconds"]))
			Sfx.roar(self)
		"kaiju_emerged":
			_hud.fade_in(Num.f(Content.section("intro")["hud_fade_seconds"]))
		_:
			return false
	return true


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
	# No look-ahead while he rises: the intro hands over onto a camera with none.
	var hold := sim.body.dash.on() or _ability.leaping() or sim.emerge.active
	_follow.step_lead(_kaiju.position, sim.body_scale(), hold, delta)
	var nod := shake.turn(sim.body_scale(), motion).y
	var eye := _follow.eye()
	var aim := _follow.aim(_kaiju, sim.body_scale(), Vector2(camera_fov, nod), delta)
	var fov := camera_fov
	if sim.emerge.active:  # the run intro's shot, ending exactly on this camera (RunIntro)
		var frac := Engine.get_physics_interpolation_fraction()
		var shot := RunIntro.shot(sim, _kaiju_at, [eye, aim, fov], frac)
		eye = shot["eye"]
		aim = shot["aim"]
		fov = Num.f(shot["fov"])
		_hud.visible = get_tree().paused  # no HUD over the intro (the pause menu shows)
	_camera.fov = fov
	_camera.position = eye
	_camera.look_at(aim)
	_city.drawn_sight = _follow.sight()
	shake.apply(_camera, sim.body_scale(), motion)
