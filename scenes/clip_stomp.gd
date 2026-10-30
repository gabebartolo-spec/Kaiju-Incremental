class_name ClipStomp
extends RefCounted
## The steps a clip-driven kaiju (ClipGait) takes off its clip path: the quick catch step of a foot
## the body got away from, and the standing stomp. The sim stomps on a beat even while he stands,
## and the scene waits (Rampage.STOMP_WAIT) for the foot that delivers it to put the ring and
## cracks under it; the clips have no stomp, so standing it is lifted off the street here, alternate
## feet, and lands inside that wait. Both lift a foot, bring it to the clip's spot in an arc and put
## it down. The stomp eases up off the street, hangs a beat, then drives down and lands as a full
## footfall that sinks the body a little and lets it back up. Each stomp's height and time vary a
## few percent by a hash of its number (never the sim's RNG), so the beat is not a metronome.
## "clip_stomp" tuning: seconds (the whole stomp), lift (hip heights), rise and hang (shares of the
## seconds; the rest is the fall), vary (+- share), dip (hip heights), dip_attack and dip_s (s).

## A catch step: its seconds, and its lift in hip heights.
const RESTEP_SECONDS := 0.25
const RESTEP_LIFT := 0.06
## The stomps keyed in Cascadeur (r13f), left foot and right: a gait with them plays one standing
## (its own lift, plant and body dip) instead of lifting the foot here.
const KEYED: Array[String] = ["stomp_l", "stomp_r"]
## A stomp's weight as a footfall at the smallest body (an adult's is 1).
const WEIGHT_MIN := 0.4
## The weight settling as he stops walking: the body sinks SETTLE_DIP hip heights over SETTLE_IN
## seconds and comes back up over SETTLE_OUT, into the idle's breath (motion critic 2026-10-23: the
## stop "looks like a freeze").
const SETTLE_DIP := 0.05
const SETTLE_IN := 0.2
const SETTLE_OUT := 0.5

## Seconds left of each foot's step; 0 when it is on the clip.
var left: Array[float] = [0.0, 0.0]
## The foot the latest stomp() lifted (0 left, 1 right); -1 when it lifted none.
var lifted := -1
var _span: Array[float] = [RESTEP_SECONDS, RESTEP_SECONDS]
var _lift: Array[float] = [1.0, 1.0]  # this step's share of the full stomp lift
var _stomping: Array[bool] = [false, false]
var _keyed: Array[bool] = [false, false]  # a keyed stomp's foot, still to land
var _next := 0  # the foot that stomps next
var _count := 0  # stomps begun, the hash's input
var _since := INF  # seconds since a stomp landed (the body's dip)
var _settle := INF  # seconds since he stopped walking
var _cfg := Content.section("clip_stomp")


func catching(i: int) -> bool:
	return left[i] > 0.0


## A keyed stomp's foot is still to land (its clip holds until then).
func pending() -> bool:
	return _keyed[0] or _keyed[1]


## The clip in `state` plays to its end: a roar, or a keyed stomp whose foot is still to land.
func holds(state: String) -> bool:
	return state == "roar" or (KEYED.has(state) and pending())


## Standing, `state` gives way to the idle: a landed keyed stomp's tail only once `done`.
func leaves(state: String, done: bool) -> bool:
	return state != "idle" and (done or not KEYED.has(state))


## He stops walking: the body's weight settles (dip()).
func settle() -> void:
	_settle = 0.0


## Foot i takes a catch step back to the clip.
func restep(i: int) -> void:
	_start(i, RESTEP_SECONDS, 1.0, false)


## A sim stomp: standing, the next foot in turn lifts. A stomp already in the air delivers this one
## too, and a foot busy with a catch step is skipped. With the keyed stomps (`keyed`) the foot is
## left to its clip, returned for the gait to play; else "".
func stomp(standing: bool, keyed: bool) -> String:
	lifted = -1
	if not standing:
		return ""
	for i: int in 2:
		if (_stomping[i] and left[i] > 0.0) or _keyed[i]:
			return ""
	for turn: int in 2:
		var i := (_next + turn) % 2
		if left[i] <= 0.0:
			_next = 1 - i
			_count += 1
			lifted = i
			if keyed:
				_keyed[i] = true
				return KEYED[i]
			var vary := Num.f(_cfg["vary"])
			_start(
				i, Num.f(_cfg["seconds"]) * (1.0 + vary * _hashed(0)), 1.0 + vary * _hashed(1), true
			)
			return ""
	return ""


## The sim names the foot that stomps next ("left" or "right"; anything else leaves it be).
func prefer(side: String) -> void:
	if side == "left" or side == "right":
		_next = 0 if side == "left" else 1


## Runs foot i's step on by dt; how far through it (0..1).
func advance(i: int, dt: float) -> float:
	left[i] = maxf(0.0, left[i] - dt)
	return 1.0 - left[i] / _span[i]


## How high foot i is above the clip's path, k of the way through its step (hip heights). A stomp
## eases up (no snap at the start), hangs, then falls faster and faster into the street.
func rise(i: int, k: float) -> float:
	if not _stomping[i]:
		return RESTEP_LIFT * sin(PI * k)
	var up := Num.f(_cfg["rise"])
	var top := up + Num.f(_cfg["hang"])
	var h := smoothstep(0.0, 1.0, k / up)
	if k > top:
		h = 1.0 - pow((k - top) / (1.0 - top), 2.0)
	return Num.f(_cfg["lift"]) * _lift[i] * clampf(h, 0.0, 1.0)


## The strength of the footfall as foot i comes down (`plain` for a step; a stomp's is its weight
## at body scale s, BipedGait's, and it starts the body's dip), and the step is over.
func landing(i: int, plain: float, s: float) -> float:
	var weight := plain
	if _stomping[i] or _keyed[i]:
		weight = clampf(sqrt(s / BipedGait.ADULT_SCALE), WEIGHT_MIN, 1.0)
		_since = 0.0 if _stomping[i] else _since  # a keyed stomp dips the body itself
	_stomping[i] = false
	_keyed[i] = false
	return weight


## Foot i is not coming down now (the clip has it in the air): a stomp that was waiting is over (a
## keyed one is in the air on its clip).
func forget(i: int) -> void:
	_stomping[i] = false


## How far the body sits below the clip's pose now, dt on (hip heights): down fast as a stomp
## lands, back up over dip_s; or settling as he stops (settle()).
func dip(dt: float) -> float:
	_since += dt
	var attack := Num.f(_cfg["dip_attack"])
	var back := Num.f(_cfg["dip_s"])
	var k := _since / attack if _since < attack else 1.0 - (_since - attack) / back
	var stomp_dip := Num.f(_cfg["dip"]) * smoothstep(0.0, 1.0, clampf(k, 0.0, 1.0))
	_settle += dt
	var down := smoothstep(0.0, SETTLE_IN, _settle)
	var up := smoothstep(SETTLE_IN, SETTLE_IN + SETTLE_OUT, _settle)
	return maxf(stomp_dip, SETTLE_DIP * (down - up))


func _start(i: int, seconds: float, lift: float, stomping: bool) -> void:
	left[i] = seconds
	_span[i] = seconds
	_lift[i] = lift
	_stomping[i] = stomping


## A repeatable number in -1..1 from the stomp's count (`salt` makes two of them independent).
func _hashed(salt: int) -> float:
	return float(absi(hash(_count * 7919 + salt * 104729)) % 2001) / 1000.0 - 1.0
