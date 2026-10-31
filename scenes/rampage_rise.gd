class_name RampageRise
extends Node
## The run's opening, for Rampage (split out of it at its 400-line cap, D-159): the rise from the
## sea bay (D-270): its splashes (RiverView), the intro's ripples and fount (IntroWater), its
## pacing (RunIntro: the ticks a frame runs, any press skips), the head's crown the water and the
## camera centre on (head_at), the rise's events and the intro's camera shot, and a body's keyed
## rise clip (rise, D-270: on the sim's clock, then the roar). Presentation only: it
## reads the sim's Emergence. It adds itself to the run.

## The intro's pacing: whole or short cut, and any press skips.
var intro: RunIntro
## The head's crown: x how far ahead of the hips, y how high over the feet (world units).
var head := Vector2.ZERO
## The last intro frame's gameplay camera and the shot drawn instead ({eye, aim, fov}; tests).
var play_view: Dictionary = {}
var shot_view: Dictionary = {}
var _run: Rampage
var _kaiju: KaijuModel
var _keyed := false  # the body plays a keyed rise clip (then roars as it ends)
var _roared := false
var _cfg: Dictionary = Content.section("intro")


## For `run` (its sim set up): adds the water's nodes to it over the city's `fx`; `full`: the
## whole intro (Main: the first run, the first after an evolution) or its short cut.
func _init(run: Rampage, fx: Fx, kaiju: KaijuModel, full: bool) -> void:
	_run = run
	_kaiju = kaiju
	var sim := run.sim
	_keyed = sim.emerge.active and sim.emerge.keyed_rise and rise(kaiju, 0.0)
	var height := Num.f(_cfg["aim_head"]) * Num.f(sim.city["kaiju_height"])
	head = head_at(kaiju, Vector2(Num.f(_cfg["aim_ahead"]), height)) * sim.body_scale()
	run.add_child(RiverView.new(sim, fx, head.x))
	run.add_child(IntroWater.new(sim, fx, head.x))
	run.add_child(WaterView.new(sim))
	run.add_child(OceanWaves.new())
	intro = RunIntro.new(sim, full)
	run.add_child(self)


## Runs this frame's sim ticks through `step` (one, or the intro's short cut and skip's faster
## run, RunIntro.ticks); the first live tick takes the frame's presses, once. Returns the ticks.
func run_ticks(step: Callable) -> int:
	var ran := 0
	for k: int in intro.ticks():
		if k > 0 and not _run.sim.emerge.active:
			break
		step.call()
		ran += 1
	return maxi(1, ran)


func _input(event: InputEvent) -> void:
	intro.on_input(event)


## The keyed rise clip on the sim's rise clock, then the roar the clip ends on.
func _process(_delta: float) -> void:
	var emerge := _run.sim.emerge
	if not _keyed or _roared:
		return
	if emerge.risen() < 1.0:
		var frac := Engine.get_physics_interpolation_fraction() / Engine.physics_ticks_per_second
		rise(_kaiju, emerge.progress() * emerge.total() + frac)
	else:
		_roared = true
		_kaiju.roar()
		Sfx.roar(_run)


## The rise from the sea bay on `kaiju`: its keyed clip (KaijuModel.RISE_CLIP) `seconds` into it,
## on the sim's clock (Emergence); false for a body without it, which keeps the sim's own rise
## (D-199: the keyer's). Here, not on KaijuModel, at its public-method cap.
static func rise(kaiju: KaijuModel, seconds: float) -> bool:
	for node: Node in kaiju.find_children("*", "KaijuRig", true, false):
		var gait := (node as KaijuRig).gait as ClipGait
		if gait != null and gait.clips.has_clip(KaijuModel.RISE_CLIP):
			gait.state = KaijuModel.RISE_CLIP
			gait.clip_time = seconds * gait.clips.fps
			return true
	return false


## Seconds of the keyed rise clip the body of `species_id` plays at the sim's stage (the first
## stage up with a rig, as KaijuModel); 0 without one (Emergence's own rise).
static func keyed(sim: RampageSim, species_id: String) -> float:
	var stages: Array[String] = ["baby", "adolescent", "adult"]
	for i: int in range(stages.find(KaijuModel.stage_for(sim.size_tier())), stages.size()):
		var base := "res://assets/kaiju/%s_%s" % [species_id, stages[i]]
		if FileAccess.file_exists(base + ".rig.json"):
			var clips := KaijuClips.read(base + ".kclip")
			if clips == null or not clips.has_clip(KaijuModel.RISE_CLIP):
				return 0.0
			return float(clips.frames_of(KaijuModel.RISE_CLIP) - 1) / clips.fps
	return 0.0


## The rise's events (Emergence) on the run's kaiju and HUD; false for any other event.
func on_event(event: Dictionary, kaiju: KaijuModel, hud: RampageHud) -> bool:
	match str(event["type"]):
		"surface_break":  # the head breaks the water: he roars with rage (#11, R 20.3)
			if not _keyed:  # a keyed rise roars as its clip ends (_process)
				kaiju.roar()  # the Cascadeur roar clip
				Sfx.roar(_run)
		"kaiju_emerged":
			hud.fade_in(Num.f(_cfg["hud_fade_seconds"]))
		_:
			return false
	return true


## The intro's camera this frame (RunIntro.shot): `view` holds the drawn body ("body") and the
## gameplay camera it ends on ("eye", "aim", "fov"); `follow` frames the drawn head. No HUD over
## the intro (`hud` shows only with the pause menu).
func shot(view: Dictionary, follow: CameraFollow, hud: RampageHud) -> Dictionary:
	hud.visible = _run.get_tree().paused
	view["head"] = head
	view["head_box"] = follow.head.head_box()
	play_view = view
	shot_view = RunIntro.shot(_run.sim, view, Engine.get_physics_interpolation_fraction())
	return shot_view


## Puts `camera` where `view` says ({eye, aim, fov}: the gameplay camera or the intro's shot),
## its aim moved by `jitter` (a blast's own shake).
static func aim_camera(camera: Camera3D, view: Dictionary, jitter: Vector3) -> void:
	var eye: Vector3 = view["eye"]
	var aim: Vector3 = view["aim"]
	camera.fov = Num.f(view["fov"])
	camera.position = eye
	camera.look_at(aim + jitter)


## Where the kaiju's head crown (its rig's "head1" bone, the first of it to break the water as it
## rises) stands: x how far ahead of its hips along its facing, y how high over its feet, in model
## units (x body scale for the world); `fallback` for a body without that bone (moved here from
## KaijuModel, at its public-method cap). The intro founts the water over it and frames it.
static func head_at(kaiju: KaijuModel, fallback: Vector2) -> Vector2:
	for node: Node in kaiju.find_children("*", "Node3D", true, false):
		var rig := node as KaijuRig
		if rig == null or not rig.has_bone("head1") or not rig.has_bone(rig.bone_names()[0]):
			continue
		var head := kaiju.to_local(rig.bone("head1").global_position)
		var hips := kaiju.to_local(rig.bone(rig.bone_names()[0]).global_position)
		return Vector2(hips.z - head.z, head.y)  # the model faces -z; to_local undoes its scale
	return fallback
