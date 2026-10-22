class_name ClipStomp
extends RefCounted
## The steps a clip-driven kaiju (ClipGait) takes off its clip path: the quick catch step of a foot
## the body got away from, and the standing stomp. The sim stomps on a beat even while he stands,
## and the scene waits (Rampage.STOMP_WAIT) for the foot that delivers it to put the ring and
## cracks under it; the clips have no stomp, so standing it is lifted off the street here, alternate
## feet, and lands inside that wait. Both lift a foot, bring it to the clip's spot in an arc and put
## it down; the stomp hangs, then drives down, and lands as a full footfall. Presentation only.
## The stomp's seconds, lift (hip heights) and skew (above 1: it hangs longer, falls faster) are
## the "clip_stomp" tuning.

## A catch step: its seconds, and its lift in hip heights.
const RESTEP_SECONDS := 0.25
const RESTEP_LIFT := 0.06
## A stomp's weight as a footfall at the smallest body (an adult's is 1).
const WEIGHT_MIN := 0.4

## Seconds left of each foot's step; 0 when it is on the clip.
var left: Array[float] = [0.0, 0.0]
var _span: Array[float] = [RESTEP_SECONDS, RESTEP_SECONDS]
var _stomping: Array[bool] = [false, false]
var _next := 0  # the foot that stomps next
var _cfg := Content.section("clip_stomp")


func catching(i: int) -> bool:
	return left[i] > 0.0


## Foot i takes a catch step back to the clip.
func restep(i: int) -> void:
	_start(i, RESTEP_SECONDS, false)


## A sim stomp: the next foot in turn lifts. A stomp already in the air delivers this one too, and a
## foot busy with a catch step is skipped.
func stomp() -> void:
	for i: int in 2:
		if _stomping[i] and left[i] > 0.0:
			return
	for turn: int in 2:
		var i := (_next + turn) % 2
		if left[i] <= 0.0:
			_next = 1 - i
			_start(i, Num.f(_cfg["seconds"]), true)
			return


## Runs foot i's step on by dt; how far through it (0..1).
func advance(i: int, dt: float) -> float:
	left[i] = maxf(0.0, left[i] - dt)
	return 1.0 - left[i] / _span[i]


## How high foot i is above the clip's path, k of the way through its step (hip heights).
func rise(i: int, k: float) -> float:
	if _stomping[i]:
		return Num.f(_cfg["lift"]) * sin(PI * pow(k, Num.f(_cfg["skew"])))
	return RESTEP_LIFT * sin(PI * k)


## The strength of the footfall as foot i comes down (`plain` for a step; a stomp's is its weight
## at body scale s, BipedGait's), and the step is over.
func landing(i: int, plain: float, s: float) -> float:
	var weight := plain
	if _stomping[i]:
		weight = clampf(sqrt(s / BipedGait.ADULT_SCALE), WEIGHT_MIN, 1.0)
	_stomping[i] = false
	return weight


## Foot i is not coming down now (the clip has it in the air): a stomp that was waiting is over.
func forget(i: int) -> void:
	_stomping[i] = false


func _start(i: int, seconds: float, stomping: bool) -> void:
	left[i] = seconds
	_span[i] = seconds
	_stomping[i] = stomping
