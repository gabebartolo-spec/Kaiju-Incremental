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
## true (the game's own flow): _ready builds the scene in stages, a frame each, behind a
## LoadingOverlay, and nothing runs until it is done (b2-30). false (tests, captures): all at once.
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
## Where the sim centred each stomp (its event's "at"), in step with stomp_ring_at, for the tests.
var stomp_sim_at: Array[Vector2] = []
## The gameplay camera at rest (data/tuning.json "camera"): offset from the kaiju's focus, FOV.
var camera_rest := CameraTuning.offset()
var camera_fov := CameraTuning.fov()
## The camera's shake (trauma); any hit adds to it through add_trauma.
var shake := CameraShake.new()
## Pad rumble (D-259): footfalls, stomps, collapses, the breath (PadRumble).
var rumble: PadRumble
var run_index := 0  # the run number (setup's p_run): it seeds each bolt
## Main: the whole intro (the first run, the first after an evolution) or its short cut (RunIntro).
var full_intro := true
var _land := StompLanding.new(shake)  # a standing stomp's cracks and camera kick
var _city: CityView
var _powers: PowersView
var _blasts: BlastFx
var _cues: PowerCues
var _hud: RampageHud
## Slow motion when a landmark falls, and the sim's pace through it (LandmarkSlowmo).
var _slowmo: LandmarkSlowmo
var _kaiju: KaijuModel
var _kaiju_at := Vector3.ZERO
var _follow := CameraFollow.new(Vector3.ZERO, camera_rest)
var _ability := RampageAbility.new()
var _camera: Camera3D
var _far_depth: FarDepth  ## the far blur, locked on the kaiju (D-163)
var _aim: BreathAim
var _step_dip := 0.0
var _tank_nodes: Dictionary = {}
var _tanks: TankYard
var _rail: RailView
var _fx_rng: RandomNumberGenerator
## Physics steps run: autoplay paces on this, never the engine clock (same run every time).
var _steps := 0
var _stomp_radius := 0.0
## The foot a walking stomp falls on (the sim names it from its step clock); "" when any will do.
var _stomp_side := ""
## Seconds a sim stomp waits for the foot that delivers it; past that it is heard but not seen.
var _stomp_wait := 0.0
var _reader := RunInput.new()  # this frame's presses (held move D-259, the rise's latch)
var _rise: RampageRise  # the run's opening: the rise from the sea bay and the intro
## How far the stick pushed on the last sim step (the walk cycle's pace between steps).
var _move_len := 0.0


## stats: final run stats; layout: CityGrowth.layout for stats.size; p_run: army seed, time of day.
func setup(p_species: Dictionary, stats: Dictionary, layout: Array[Dictionary], p_run: int) -> void:
	species = p_species
	run_index = p_run
	GraphicsPresets.start_run(PlayerSettings.graphics_row())  # counts: this run, not mid-run
	Content.set_time(Content.time_for_run(p_run))
	var ability: Dictionary = species["ability"]
	sim = RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", p_run))
	sim.ability_type = str(ability["type"])
	sim.army_units.taskforce.carried = city_seconds  # rampage time in this city so far (D-160)
	sim.body.use_species(str(species["id"]))  # first: the rise is placed by the body's length
	sim.emerge.start(sim, RampageRise.keyed(sim, str(species["id"])))  # from the bay, D-270
	_fx_rng = Seeds.make("fx", p_run)
	sfx = Sfx.new(Seeds.make("sfx", p_run))
	_cues = PowerCues.new(sim, sfx)


## Returns once the scene is built (flow suites and captures started through Main wait here).
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


## setup() builds sfx, _ready() adds it later: freed in between, nothing frees it (debt row 2).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(sfx) and sfx.get_parent() == null:
		sfx.free()


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
	_aim = BreathAim.new(sim, Color(str(colors["eye"])))  # where a ready breath will burn
	add_child(_aim)
	add_child(sfx)
	sfx.set_size_tier(sim.size_tier())
	_kaiju = KaijuModel.new(str(species["id"]), colors, KaijuModel.stage_for(sim.size_tier()))
	add_child(_kaiju)
	if not await stages.next(self):
		return
	ability_fx.attach_body(_kaiju)
	_powers = PowersView.new(sim, _city, _kaiju, Color(str(colors["eye"])))
	add_child(_powers)
	_rise = RampageRise.new(self, _city.fx, _kaiju, full_intro)
	_blasts = BlastFx.attach(self, sim, _city, sfx, Seeds.derive(_fx_rng, 0xB1A5))
	_add_vehicles()
	_kaiju_at = _to_world(sim.kaiju_pos) + Vector3(0, sim.stand_y, 0)  # under the river at first
	_kaiju.position = _kaiju_at
	_follow.focus = _kaiju_at
	_kaiju.scale = Vector3.ONE * sim.body_scale()
	_kaiju.set_grip_finder(
		func(at: Vector3, r: float) -> Vector3: return KaijuGrip.point(sim, at, r)
	)
	_kaiju.foot_planted.connect(_on_footfall)
	_ability.bind(self, _city, _kaiju)
	_add_camera()
	_start_sound()
	_add_overlays()
	_place_camera(1.0)  # after the HUD: the intro hides it
	if stages.overlay != null:
		stages.overlay.queue_free()
	is_loaded = true
	loaded.emit()
	get_node("/root/EventBus").emit_signal("run_started", str(species["id"]))


func _add_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = camera_fov
	add_child(_camera)
	_camera.current = true


## The vignette and colour fringe (D-142, they read the sim), then the HUD above them.
func _add_overlays() -> void:
	add_child(PostFx.new(self))
	add_child(DeathView.new(sim, _city, _kaiju, add_trauma))  # his overload as he dies
	_far_depth = FarDepth.new(_camera)  # the far blur on the camera (D-163)
	_hud = RampageHud.new(sim, species, _city.street)
	_hud.beat_done.connect(finished.emit)
	_hud.photo = photo_mode
	rumble = PadRumble.new(sim)
	_kaiju.foot_planted.connect(rumble.footfall)
	add_child(_hud)
	_slowmo = LandmarkSlowmo.new(sim, _hud)  # the world slows when a landmark falls
	add_child(_slowmo)


func _physics_process(delta: float) -> void:
	if not is_loaded or sim.over:
		return
	# Slow motion (LandmarkSlowmo, D-259) steps the sim by whole ticks, on fewer of them: a tick it
	# sits out only draws (steps -1: the tanks' every-tenth-step crush must not repeat).
	var dt := _slowmo.sim_dt(delta)
	var ticks := _step(dt) if dt > 0.0 else 1
	if dt <= 0.0:
		_slowmo.sit_out(delta)
	_present(delta * ticks, _steps if dt > 0.0 else -1)  # the legs keep pace with the ticks run


## This frame's sim ticks of `dt` and presses (more in the intro's short cut, RunIntro); ticks run.
func _step(dt: float) -> int:
	var now := _slowmo.merge(_reader.read(self, _steps, dt), dt)
	_steps += 1
	var wading := sim.emerge.risen() >= 1.0 and sim.emerge.active
	var move: Vector2 = now["move"]
	var signature: bool = now["signature"]
	var ran := _rise.run_ticks(func() -> void: _step_sim(dt, move, signature, now))
	_move_len = 1.0 if wading else (0.0 if sim.body.dash.on() else move.length())
	return ran


func _step_sim(dt: float, move: Vector2, signature: bool, now: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	var events := sim.step(dt, move, signature, RunInput.buttons(now))
	_note_cost("sim.step", t0)
	for event: Dictionary in events:
		var t1 := Time.get_ticks_usec()
		if not _rise.on_event(event, _kaiju, _hud):  # the rise's own (RampageRise) first
			_on_event(event)
		_note_cost(str(event["type"]), t1)


## One tick's drawing, stepped or not (`delta` is the tick's own, slowed by the time scale).
func _present(delta: float, steps: int) -> void:
	_kaiju_at = _ability.place(delta, _move_len, _kaiju_at)
	_cues.update(ability_fx, _kaiju_at, _to_world(sim.facing))
	_powers.update(delta, _kaiju_at)
	_tanks.update(delta, _kaiju_at, steps)
	_hud.refresh()


func _process(delta: float) -> void:
	if not is_loaded:
		return
	_place_camera(delta)
	_far_depth.follow(_kaiju_at)
	shake.update(delta)
	if _stomp_wait > 0.0:
		_stomp_wait -= delta
		if _stomp_wait <= 0.0:  # no foot came down: the sound, no ring or cracks
			sfx.stomp(_power("stomp_damage"), false)


## The pause menu's photo mode (PhotoMode, D-259): the gameplay camera flies free round the frozen
## kaiju; the breath's aim hides while it is up.
func photo_mode() -> PhotoMode:
	var hide: Array[Node3D] = [_aim]
	var rest := (camera_rest * CameraTuning.zoom(sim.body_scale())).length()
	return PhotoMode.new(_camera, _kaiju_at, rest, hide)


## Shakes the camera (CameraShake): `amount` trauma from a hit at `at` (Vector3.INF: at the
## kaiju), fading with its distance from the camera's focus. Explosions and every other hit use it.
func add_trauma(amount: float, at := Vector3.INF) -> void:
	shake.add(amount, at, _follow.focus, sim.body_scale())


## Worst time (usec) spent per sim step and per event kind; read by the benchmark tool.
func _note_cost(what: String, since: int) -> void:
	cost_usec[what] = maxi(Num.i(cost_usec.get(what, 0)), Time.get_ticks_usec() - since)


## The army's tanks (their voxels built once now, so the first spawn reuses them), the
## helicopters' voxels (the gunships' and the leader's own), and the railway.
func _add_vehicles() -> void:
	TankModel.new().free()
	HelicopterModel.warm()
	_tanks = TankYard.new(self, sim, _city, _tank_nodes)
	_rail = RailView.new(self, sim, _city)
	add_child(_rail)


func _to_world(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


func _on_event(event: Dictionary) -> void:
	_blasts.on_event(event, _kaiju_at)
	rumble.on_event(event)
	WildlifeView.feed(_city.wildlife, event, _kaiju_at)  # birds scatter, the whale dives
	match str(event["type"]):
		"stomp":
			_land.lift(_kaiju, str(event.get("side", "")))
			# The sim decides the damage now; the ring, cracks and crush wait for the foot that
			# delivers the stomp (_on_footfall), so they land where and when a foot does.
			_stomp_radius = Num.f(event["radius"])
			stomp_sim_at.append(event["at"])
			_stomp_side = str(event["side"]) if event["on_foot"] else ""
			_stomp_wait = STOMP_WAIT
			add_trauma(shake.source("stomp"))
		"ability":
			_kaiju.roar()
			_ability.play(event, _kaiju_at, _power("ability_damage"))
		"chunks_broken":
			var cells: Array[Vector3i] = event["cells"]
			_on_chunks_broken(Num.i(event["building"]), cells, Num.f(event.get("pay", 1.0)))
		"fall_start", "cells_promoted", "cells_carved":
			_city.on_cells(event)
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
			_slowmo.stop()  # the end beat runs at normal speed (D-259)
			_hud.run_over(str(event["reason"]))
		_:
			_powers.on_event(event, _kaiju_at)
			_rail.on_event(event)
			_ability.on_event(event)  # the croc's leap (LeapView) and slam (SlamView)


## No number floats up for the biomass (D-284: "Remove them entirely"); the HUD counts it.
func _on_chunks_broken(index: int, cells: Array[Vector3i], _pay: float) -> void:
	_city.chunks_broken(index, cells, _kaiju_at)


## How far an upgraded stat is above the species' own value (1 = not upgraded).
func _power(stat_name: String) -> float:
	var base: Dictionary = species["stats"]
	return ability_fx.power(sim.stat(stat_name), Num.f(base[stat_name]))


## Every footfall kicks a little dust, nudges the camera and sounds a step (or the stomp that
## was waiting for this foot), so what you hear lands with what you see.
func _on_footfall(side: String, strength: float, at: Vector3) -> void:
	var stomped := _stomp_wait > 0.0 and side != "tail" and _stomp_side in ["", side]
	if stomped:
		_land_stomp(side, at)
	sfx.footstep(strength)
	var size := sim.body_scale() * (0.2 + strength)
	if side != "tail":  # a tail slam throws its own puffs (Fx.shockwave)
		_city.footfall(at, FOOTFALL_DUST * size, sim.body_scale())
	var ring := _stomp_radius * 1.3 * Fx.STOMP_RING if stomped else FOOTFALL_RING * size
	_city.fx.shockwave(at, ring, side == "tail", stomped)
	var dip := FOOTFALL_DIP * maxf(FOOTFALL_DIP_FLOOR, sim.body_scale()) * strength
	_step_dip = maxf(_step_dip, dip)


## The waiting stomp lands under the foot that delivers it: cracks (if heavy enough), the street
## crushed around that foot, one dust ripple. Sound is released by the same footfall (Sfx.footstep).
func _land_stomp(side: String, at: Vector3) -> void:
	_stomp_wait = 0.0
	rumble.stomp()
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
	_follow.turn_with(sim.facing, not sim.emerge.active, delta)  # D-330, D-259
	var hold := sim.body.dash.on() or _ability.leaping() or sim.emerge.active  # rise: no lead
	_follow.step_lead(_kaiju.position, sim.body_scale(), hold, delta)
	var nod := shake.turn(sim.body_scale(), motion).y
	var aim := _follow.aim(_kaiju, sim.body_scale(), Vector2(camera_fov, nod), delta)
	var view := {"body": _kaiju_at, "eye": _follow.eye(), "aim": aim, "fov": camera_fov}
	if sim.emerge.active:  # the run intro's shot, ending exactly on this camera (RunIntro)
		view = _rise.shot(view, _follow, _hud)
	RampageRise.aim_camera(_camera, RunIntro.above_water(sim, view), _blasts.jitter() * motion)
	shake.apply(_camera, sim.body_scale(), motion)
