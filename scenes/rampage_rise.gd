class_name RampageRise
extends RefCounted
## The run's opening, for Rampage (split out of it at its 400-line cap, D-159): the rise from the
## river's splashes (RiverView), the intro's ripples and fount (IntroWater), its pacing
## (RunIntro), the head's crown the water and the camera centre on (head_at), the
## rise's events and the intro's camera shot. Presentation only: it reads the sim's Emergence.

## The intro's pacing: whole or short cut, and any press skips.
var intro: RunIntro
## The head's crown: x how far ahead of the hips, y how high over the feet (world units).
var head := Vector2.ZERO
## The last intro frame's gameplay camera and the shot drawn instead ({eye, aim, fov}; tests).
var play_view: Dictionary = {}
var shot_view: Dictionary = {}
var _run: Rampage
var _cfg: Dictionary = Content.section("intro")


## For `run` (its sim set up): adds the water's nodes to it over the city's `fx`; `full`: the
## whole intro (Main: the first run, the first after an evolution) or its short cut.
func _init(run: Rampage, fx: Fx, kaiju: KaijuModel, full: bool) -> void:
	_run = run
	var sim := run.sim
	var height := Num.f(_cfg["aim_head"]) * Num.f(sim.city["kaiju_height"])
	head = head_at(kaiju, Vector2(Num.f(_cfg["aim_ahead"]), height)) * sim.body_scale()
	run.add_child(RiverView.new(sim, fx, head.x))
	run.add_child(IntroWater.new(sim, fx, head.x))
	intro = RunIntro.new(sim, full)


## The rise's events (Emergence) on the run's city, kaiju and HUD; false for any other event.
func on_event(event: Dictionary, city: CityView, kaiju: KaijuModel, hud: RampageHud) -> bool:
	match str(event["type"]):
		"deck_burst":
			city.deck_burst()
			_run.add_trauma(_run.shake.source("drop"))
		"surface_break":  # the head breaks the water: he roars with rage (#11, R 20.3)
			kaiju.roar(Num.f(_cfg["roar_jaw_seconds"]))
			Sfx.roar(_run)
		"kaiju_emerged":
			hud.fade_in(Num.f(_cfg["hud_fade_seconds"]))
		_:
			return false
	return true


## The intro's camera this frame (RunIntro.shot): `view` holds the drawn body ("body") and the
## gameplay camera it ends on ("eye", "aim", "fov"); `follow` frames the drawn head.
func shot(view: Dictionary, follow: CameraFollow) -> Dictionary:
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
