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
## and the rest a little faster, so it lasts "short_seconds". Any press skips: the rest of the
## rise runs "skip_ticks" sim ticks a frame. Either way the sim runs the very same ticks with the
## same (ignored) input, so a replay matches whether or not anyone skipped.

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
	_rate = maxf(1.0, (sim.emerge.total() - from) / Num.f(_cfg["short_seconds"]))


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


## The intro's camera for this frame while the kaiju emerges: {"eye", "aim", "fov"}. It ends
## exactly on the gameplay camera at rest: `follow`'s focus plus its rest offset, its aim
## (CameraFollow, already stepped this frame) and `rest_fov`; `frac` is the share of a tick drawn
## past the last one.
static func shot(sim: RampageSim, follow: CameraFollow, rest_fov: float, frac: float) -> Dictionary:
	var focus := follow.focus
	var rest_eye := follow.focus + follow.rest
	var rest_aim := follow.look_at(sim.body_scale())
	var cfg: Dictionary = Content.section("intro")
	var emerge := sim.emerge
	var total := emerge.total()
	var t := minf(total, emerge.progress() * total + frac / Engine.physics_ticks_per_second)
	var s := sim.body_scale()
	var water := -Num.f(sim.city.get("river_depth", 0.0))
	var pull_from := Num.f(cfg["pull_from_seconds"])
	var w := smoothstep(pull_from, total, t)  # 0: the water shot, 1: the gameplay camera
	var rest := rest_eye - focus
	var behind := Vector2(rest.x, rest.z)
	# A slow push in over the wait, ending at the break on the shot's distance; then one pull-out.
	var wait := 1.0 - smoothstep(0.0, emerge.break_at(sim), t)
	var close := Num.f(cfg["distance"]) * s * (1.0 + Num.f(cfg["push_in"]) * wait)
	# The shot turns about the head (where the water founts and it breaks the surface), then about
	# the body as it pulls out: yaw 90 looks along the river, across the bay's open water.
	var ahead := sim.facing * Num.f(cfg["aim_ahead"]) * s
	var head_at := Vector2(focus.x + ahead.x, focus.z + ahead.y)
	var pivot := head_at.lerp(Vector2(focus.x, focus.z), w)
	var yaw := deg_to_rad(Num.f(cfg["yaw_deg"])) * (1.0 - w)
	var side := behind.normalized().rotated(yaw) * lerpf(close, behind.length(), w)
	var eye := Vector3(pivot.x + side.x, 0.0, pivot.y + side.y)
	eye.y = lerpf(water + Num.f(cfg["height"]) * s, rest_eye.y, w)
	# It looks at the water over the head, then follows the head up as it rises.
	var head := sim.stand_y + sim.reach_height() * Num.f(cfg["aim_head"])
	var low := water + Num.f(cfg["aim_height"]) * s
	# A soft max, so the aim eases off the water as the head climbs (a hard one starts at a jerk).
	var rise := head - low
	var soft := Num.f(cfg["aim_soft"]) * s
	var aim_y := low + 0.5 * (rise + sqrt(rise * rise + soft * soft))
	var head_aim := Vector3(head_at.x, aim_y, head_at.y)
	var fov := lerpf(Num.f(cfg["fov"]), rest_fov, w)
	return {"eye": eye, "aim": head_aim.lerp(rest_aim, w), "fov": fov}
