class_name RunIntro
extends RefCounted
## The run intro (director 2026-10-20 #11: "a quick, dramatic camera shot, zoomed in on the water
## which begins to ripple and fount before our kaiju emerges, roaring with rage before the camera
## zooms out into the play angle and the run begins. the entire scene should run for no longer
## than 3 seconds"). Presentation only, read from the sim's own rise (Emergence), never a Tween
## or the clock (R 20.2): the camera starts low and close on the water to one side of the rise,
## holds as the head breaks the surface, then swings round and pulls out onto the gameplay
## camera, which it reaches as the sim says "kaiju_emerged". Tuning "intro" holds its numbers.
##
## Pacing (R 20.4): the full intro on a run with something new to show (Main: the first run, the
## first after an evolution); otherwise the short cut, which runs the rise's first ticks at once
## and the rest a whole number of ticks a frame, so it lasts at most "short_seconds". Any press
## skips: the rest of the rise runs "skip_ticks" sim ticks a frame. Either way the sim runs the
## very same ticks with the same (ignored) input, so a replay matches whether or not anyone
## skipped.

## Whether this run plays the whole intro (false: the short cut).
var full: bool
## Set by any press while the kaiju rises.
var skipped := false
var _sim: RampageSim
var _cfg: Dictionary
var _first_ticks := 1  # sim ticks the first frame runs (the short cut jumps in near the break)
var _rate := 1.0  # sim ticks per frame after it
var _owed := 0.0
var _started := false


func _init(sim: RampageSim, p_full: bool) -> void:
	_sim = sim
	full = p_full
	_cfg = Content.section("intro")
	if full or not sim.emerge.active:
		return
	var tps := float(Engine.physics_ticks_per_second)
	var from := maxf(0.0, sim.emerge.break_at(sim) - Num.f(_cfg["short_lead_seconds"]))
	_first_ticks = maxi(1, roundi(from * tps))
	# A whole number of ticks every frame: an uneven 1-2-1 cadence stuttered the body and camera.
	_rate = maxf(1.0, ceilf((sim.emerge.total() - from) / Num.f(_cfg["short_seconds"])))


## How many sim ticks this physics frame runs: 1 once the kaiju is out (and in the full intro).
func ticks() -> int:
	if not _sim.emerge.active:
		return 1
	if skipped:
		return Num.i(_cfg["skip_ticks"])
	if not _started:
		_started = true
		return _first_ticks
	_owed += _rate
	var n := floori(_owed)
	_owed -= n
	return n


## Any key, button or click while the kaiju rises skips the rest (pause and releases do not).
func on_input(event: InputEvent) -> void:
	if not _sim.emerge.active or event.is_echo() or not event.is_pressed():
		return
	if event.is_action("pause"):
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		skipped = true


## The intro's camera for this frame while the kaiju emerges: {"eye", "aim", "fov"}. `view`:
## "body", the drawn body's position; "eye", "aim", "fov", the gameplay camera this frame
## (Rampage's CameraFollow, already stepped, with its head-room tilt), which the shot ends on
## exactly, so the hand-over has no pop; "ahead", how far the head's crown stands ahead of the
## hips (world units, KaijuModel.head_ahead). `frac`: the share of a tick drawn past the last one.
## The shot (beat sheet A, research 20): low and close on the water in front of him, a quarter
## off his line ("yaw_deg"), pushing in while the water ripples and founts; the head bursts out
## roaring into a low-angle hero frame; from "pull_from_seconds" one eased pull-out swings round
## him and rises onto the gameplay camera behind him, in cylinder coordinates about the body so
## it never passes through him.
static func shot(sim: RampageSim, view: Dictionary, frac: float) -> Dictionary:
	var body: Vector3 = view["body"]
	var rest_eye: Vector3 = view["eye"]
	var rest_aim: Vector3 = view["aim"]
	var cfg: Dictionary = Content.section("intro")
	var emerge := sim.emerge
	var total := emerge.total()
	var t := minf(total, emerge.progress() * total + frac / Engine.physics_ticks_per_second)
	var s := sim.body_scale()
	var water := -Num.f(sim.city.get("river_depth", 0.0))
	var pull_from := Num.f(cfg["pull_from_seconds"])
	var x := clampf((t - pull_from) / maxf(0.001, total - pull_from), 0.0, 1.0)
	var w := x * x * x * (x * (x * 6.0 - 15.0) + 10.0)  # smootherstep: still at both ends
	# The pivot: the head (ahead of the hips) for the water shot, the body at the gameplay camera.
	var ahead := sim.facing * Num.f(view["ahead"])
	var head_at := Vector2(body.x + ahead.x, body.z + ahead.y)
	var pivot := head_at.lerp(Vector2(body.x, body.z), w)
	# A slow push in over the wait, ending at the break on the shot's distance.
	var wait := 1.0 - smoothstep(0.0, emerge.break_at(sim), t)
	var close := Num.f(cfg["distance"]) * s * (1.0 + Num.f(cfg["push_in"]) * wait)
	var front := atan2(sim.facing.y, sim.facing.x) + deg_to_rad(Num.f(cfg["yaw_deg"]))
	var back := rest_eye - Vector3(body.x, 0.0, body.z)
	var back_yaw := atan2(back.z, back.x)
	var yaw := front + wrapf(back_yaw - front, -PI, PI) * w
	var radius := lerpf(close, Vector2(back.x, back.z).length(), w)
	var eye := Vector3(pivot.x + cos(yaw) * radius, 0.0, pivot.y + sin(yaw) * radius)
	# The height leads the pull-out (done by two thirds of it): the eye is up before it swings.
	var xh := minf(1.0, x * 1.5)
	var up := xh * xh * xh * (xh * (xh * 6.0 - 15.0) + 10.0)
	eye.y = lerpf(_low_eye(sim, cfg, Num.f(view["ahead"]), front), rest_eye.y, up)
	var head_aim := Vector3(head_at.x, _aim_y(sim, cfg, water), head_at.y)
	var fov := lerpf(Num.f(cfg["fov"]), Num.f(view["fov"]), w)
	return {"eye": eye, "aim": head_aim.lerp(rest_aim, w), "fov": fov}


## The water shot's eye height: "height" over the water, or "clearance" over the shore or street
## under it, wherever the push-in puts it. One height for the whole shot, read about the rise
## point, so the eye never steps as it swings over a quay edge (a 1.6 m step jolted it).
static func _low_eye(sim: RampageSim, cfg: Dictionary, ahead: float, front: float) -> float:
	var s := sim.body_scale()
	var water := -Num.f(sim.city.get("river_depth", 0.0))
	var head := sim.emerge.rise_at + sim.facing * ahead
	var out := Vector2(cos(front), sin(front)) * Num.f(cfg["distance"]) * s
	var under := water
	for k: float in [1.0, 1.0 + Num.f(cfg["push_in"])]:
		under = maxf(under, sim.emerge.ground_at(head + out * k))
	return maxf(water + Num.f(cfg["height"]) * s, under + Num.f(cfg["clearance"]) * s)


## The water shot's aim height: the water over the head, then the head as it rises (a soft max,
## so the aim eases off the water as the head climbs; a hard one starts at a jerk).
static func _aim_y(sim: RampageSim, cfg: Dictionary, water: float) -> float:
	var s := sim.body_scale()
	var head := sim.stand_y + sim.reach_height() * Num.f(cfg["aim_head"])
	var low := water + Num.f(cfg["aim_height"]) * s
	var rise := head - low
	return low + 0.5 * (rise + sqrt(rise * rise + pow(Num.f(cfg["aim_soft"]) * s, 2.0)))
