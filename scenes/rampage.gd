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
## Where the sim centred each stomp (its event's "at"), in step with stomp_ring_at, for the tests.
var stomp_sim_at: Array[Vector2] = []
## The gameplay camera at rest (data/tuning.json "camera"): offset from the kaiju's focus, FOV.
var camera_rest := CameraTuning.offset()
var camera_fov := CameraTuning.fov()
## The camera's shake (trauma); any hit adds to it through add_trauma.
var shake := CameraShake.new()
## Pad rumble (D-259): footfalls, stomps, collapses, the breath (PadRumble).
var rumble: PadRumble
## Main: the whole intro (the first run, the first after an evolution) or its short cut (RunIntro).
var full_intro := true
var run_index := 0  # the run number (setup's p_run): it seeds each bolt
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
var _reader := RunInput.new()  # this frame's presses (held move D-259, the rise's latch)
var _rise: RampageRise  # the run's opening: the rise from the river and the intro
## How far the stick pushed on the last sim step (the walk cycle's pace between steps).
var _move_len := 0.0
## Sim ticks the last step ran (the intro's short cut and skip run several): the legs keep going.
var _ticks := 1


## stats: final run stats; layout: CityGrowth.layout for stats.size; p_run seeds the army and
## picks the time of day.
func setup(p_species: Dictionary, stats: Dictionary, layout: Array[Dictionary], p_run: int) -> void:
	species = p_species
	run_index = p_run
	GraphicsPresets.start_run(PlayerSettings.graphics_row())  # counts: this run, not mid-run
	Content.set_time(Content.time_for_run(p_run))
	var ability: Dictionary = species["ability"]
	sim = RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", p_run))
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
	_land.bind(self, _city)
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
	if dt > 0.0:
		_step(dt)
	else:
		_slowmo.sit_out(delta)
		_ticks = 1
	_present(delta, _steps if dt > 0.0 else -1)


## One sim step of `dt` with this tick's presses (and any kept from ticks the slow motion sat out).
## The rise's intro may run several sim ticks in it (RunIntro.ticks): the first live tick takes the
## presses, once.
func _step(dt: float) -> void:
	var now := _slowmo.merge(_reader.read(self, _steps, dt), dt)
	var move: Vector2 = now["move"]
	var signature: bool = now["signature"]
	_steps += 1
	var buttons := RunInput.buttons(now)
	var wading := sim.emerge.risen() >= 1.0 and sim.emerge.active
	_ticks = _rise.intro.ticks()  # the intro's short cut and skip run the rise's ticks faster
	for k: int in _ticks:
		if k > 0 and not sim.emerge.active:
			break  # the first live tick takes this frame's presses, once
		_step_sim(dt, move, signature, buttons)
	_move_len = 1.0 if wading else (0.0 if sim.body.dash.on() else move.length())


func _step_sim(dt: float, move: Vector2, signature: bool, buttons: int) -> void:
	var t0 := Time.get_ticks_usec()
	var events := sim.step(dt, move, signature, buttons)
	_note_cost("sim.step", t0)
	for event: Dictionary in events:
		var t1 := Time.get_ticks_usec()
		_on_event(event)
		_note_cost(str(event["type"]), t1)


func _input(event: InputEvent) -> void:
	if _rise != null:
		_rise.intro.on_input(event)


## One tick's drawing, stepped or not (`delta` is the tick's own, slowed by the time scale).
func _present(delta: float, steps: int) -> void:
	_kaiju_at = _ability.place(delta * _ticks, _move_len, _kaiju_at)  # the legs keep going
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
	if _land.wait_out(delta):  # no foot came down: the sound, no ring or cracks
		sfx.stomp(_power("stomp_damage"), false)


## The pause menu's photo mode (PhotoMode, D-259): the gameplay camera flies free round the frozen
## kaiju; the breath's aim and the floating numbers hide while it is up.
func photo_mode() -> PhotoMode:
	var hide: Array[Node3D] = [_aim]
	for node: Node in get_tree().get_nodes_in_group(CityView.FLOAT_TEXT):
		hide.append(node as Node3D)
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
## helicopters' voxels, and the railway.
func _add_vehicles() -> void:
	TankModel.new().free()
	HelicopterModel.new().free()
	_tanks = TankYard.new(self, sim, _city, _tank_nodes)
	_rail = RailView.new(self, sim, _city)
	add_child(_rail)


func _to_world(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


func _on_event(event: Dictionary) -> void:
	_blasts.on_event(event, _kaiju_at)
	rumble.on_event(event)
	match str(event["type"]):
		"stomp":
			_land.on_stomp(_kaiju, event)
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
			_slowmo.stop()  # the end beat runs at normal speed (D-259)
			_hud.run_over(str(event["reason"]))
		_:
			if _rise.on_event(event, _kaiju, _hud):
				return
			_powers.on_event(event, _kaiju_at)
			_rail.on_event(event)
			_ability.leap.on_event(event)  # the croc's leap on the dash button (LeapView)


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


## Every footfall dips the camera a little; StompLanding does the rest (dust, ring, sound).
func _on_footfall(side: String, strength: float, at: Vector3) -> void:
	_step_dip = maxf(_step_dip, _land.footfall(side, strength, at))


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
	var rest := CameraTuning.turned(camera_rest, sim.body.view.turn) * zoom  # at his back (D-330)
	_follow.step(_kaiju.focus(), rest - Vector3(0, _step_dip * zoom * motion, 0), delta)
	var hold := sim.body.dash.on() or _ability.leaping() or sim.emerge.active  # rise: no lead
	_follow.step_lead(_kaiju.position, sim.body_scale(), hold, delta)
	var nod := shake.turn(sim.body_scale(), motion).y
	var aim := _follow.aim(_kaiju, sim.body_scale(), Vector2(camera_fov, nod), delta)
	var view := {"body": _kaiju_at, "eye": _follow.eye(), "aim": aim, "fov": camera_fov}
	if sim.emerge.active:  # the run intro's shot, ending exactly on this camera (RunIntro)
		view = _rise.shot(view, _follow)
		_hud.visible = get_tree().paused  # no HUD over the intro (the pause menu shows)
	RampageRise.aim_camera(_camera, view, _blasts.jitter() * motion)  # + a blast's shake
	_city.drawn_sight = _follow.sight()
	shake.apply(_camera, sim.body_scale(), motion)
