class_name PostFxState
extends RefCounted
## What the two post effects show right now (D-142, tuning "post_fx"): the vignette's colour and
## strength, and the colour fringe's size. Presentation only, stepped by the frames' own delta (no
## clock), fed by what the scene already shows: the kaiju's health share, a stomp's radius, a
## collapse's length, a hit's share of max health. PostFx draws the numbers.
##
## The vignette is always on: a dark edge. Under low health the edge turns red and pulses. The
## fringe is a split-second burst on a top-tier impact only, with a cooldown, so it can never be
## always on. The player's camera-motion setting scales the fringe (0 shows none).

## The vignette's colour and the opacity at the screen corner (always the calm dark edge).
var vignette_color := Color.BLACK
var vignette_alpha := 0.0
## The low-health red band: its colour, and its opacity at the very screen edge this frame (0 above
## the line and between beats).
var red_color := Color.RED
var red_alpha := 0.0
## The fringe's red-blue split at the screen edge, in pixels at 1080 lines (0 = none).
var fringe_px := 0.0
## How far into the low-health state the edge is, 0..1 (eased, so crossing the line never pops).
var low := 0.0

var _vig: Dictionary
var _low_cfg: Dictionary
var _fringe: Dictionary
var _phase := 0.0
var _t := -1.0  # seconds into the running fringe; negative when none
var _since := INF  # seconds since the last fringe began
var _last_hp := 1.0


func _init() -> void:
	var cfg := Content.section("post_fx")
	_vig = cfg["vignette"]
	_low_cfg = cfg["low_health"]
	_fringe = cfg["fringe"]
	vignette_color = Color(str(_vig["color"]))
	red_color = Color(str(_low_cfg["color"]))
	vignette_alpha = Num.f(_vig["strength"])


## True while a fringe is showing.
func fringe_on() -> bool:
	return _t >= 0.0


## A stomp of `radius` (world units) lands. True when it began a fringe.
func stomp(radius: float) -> bool:
	return radius >= Num.f(_fringe["stomp_min_radius"]) and _begin()


## A falling building part collapses along `length` (world units). True when it began a fringe.
func collapse(length: float) -> bool:
	return length >= Num.f(_fringe["collapse_min_length"]) and _begin()


## The kaiju lost `share` of its max health in one frame. True when it began a fringe.
func hurt(share: float) -> bool:
	return share >= Num.f(_fringe["hit_hp_fraction"]) and _begin()


## A falling part lands (a sim `fall_land` event): a topple of a tall part earns the fringe.
func fall(event: Dictionary) -> bool:
	if str(event["kind"]) != "topple" or event["scrap"] == true:
		return false
	var from: Vector2 = event["from"]
	var to: Vector2 = event["to"]
	return collapse(from.distance_to(to))


func _begin() -> bool:
	if _since < Num.f(_fringe["cooldown_s"]):
		return false
	_t = 0.0
	_since = 0.0
	return true


## One frame: `hp_share` is health over max health (0..1), `motion` the player's 0..1
## camera-motion setting.
func update(delta: float, hp_share: float, motion: float) -> void:
	_since += delta
	hurt(_last_hp - hp_share)  # a heavy hit: a big share of max health gone since the last frame
	_last_hp = hp_share
	var below := Num.f(_low_cfg["below"])
	var full := Num.f(_low_cfg["full_at"])
	var goal := clampf((below - hp_share) / maxf(below - full, 0.001), 0.0, 1.0)
	low = move_toward(low, goal, Num.f(_low_cfg["fade_per_s"]) * delta)
	_phase = fposmod(_phase + Num.f(_low_cfg["pulse_hz"]) * delta, 1.0)
	var beat := 0.5 - 0.5 * cos(_phase * TAU)  # 0 .. 1 .. 0 once a period
	red_alpha = Num.f(_low_cfg["alpha"]) * low * pow(beat, Num.f(_low_cfg["pulse_sharp"]))
	fringe_px = 0.0
	if _t < 0.0:
		return
	_t += delta
	var seconds := maxf(Num.f(_fringe["seconds"]), 0.001)
	if _t >= seconds:
		_t = -1.0
		return
	fringe_px = Num.f(_fringe["peak_px"]) * _envelope(_t / seconds) * clampf(motion, 0.0, 1.0)


## 0..1..0 over a fringe's life: a quick rise to the peak at `attack`, then an ease out.
func _envelope(u: float) -> float:
	var attack := clampf(Num.f(_fringe["attack"]), 0.01, 0.99)
	if u < attack:
		return u / attack
	var rest := 1.0 - (u - attack) / (1.0 - attack)
	return rest * rest
