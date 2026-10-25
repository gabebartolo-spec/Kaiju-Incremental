class_name StompBeat
extends RefCounted
## A standing stomp played from its clip (ClipGait; the adult croc's Cascadeur stomp, D-199: no
## code lift). The "stomp" clip keys two stomps, left then right, each from its lift to the next
## foot's; a sim stomp (the stomp button) plays the named foot's part once and holds its end, so a
## press makes one stomp and the button held makes one per stomp_interval. The clip starts LEAD_S
## before the foot lifts, so its own footfall lands it inside the scene's wait
## (Rampage.STOMP_WAIT). Stomps faster than the clip's pace (upgrades shorten stomp_interval)
## play it faster, and a press that comes while the last stomp still plays hurries it to its end.
## Presentation only.

const CLIP := "stomp"
## Seconds before the foot lifts that a sim stomp starts the clip (the weight is already shifting).
const LEAD_S := 0.067
## The clip's own pace: one stomp per this many seconds (r10d: 42 frames at 30 fps, two stomps).
const KEYED_INTERVAL := 0.7
## Seconds a finished stomp holds its end for the next press before the idle takes over.
const HOLD_S := 0.3
## The most a stomp that is still playing is hurried (times its pace) to make room for the next.
const HURRY_MAX := 2.0

## How fast the clip plays (clip frames per frame of the file's fps; _pace = as keyed).
var rate := 1.0
## Seconds between the last two sim stomps.
var interval := KEYED_INTERVAL
var _clips: KaijuClips
var _lifts: Dictionary = {}  # "left" / "right" -> the clip frame that foot lifts
var _per_stomp := 1.0  # clip frames per stomp
var _pace := 1.0  # the rate that plays a stomp in KEYED_INTERVAL (the clip keeps its keyed frames)
var _until := 0.0  # the clip frame (unwrapped) the stomps asked for so far end on
var _since := INF  # seconds since the last sim stomp
var _held := 0.0  # seconds the clip has held its end


func _init(p_clips: KaijuClips) -> void:
	_clips = p_clips
	if not _clips.has_clip(CLIP):
		return
	var stomps := _clips.stomps_of(CLIP)
	for st: Dictionary in stomps:
		_lifts[str(st["side"])] = Num.f(st["lift"])
	_per_stomp = float(_clips.frames_of(CLIP)) / maxi(1, stomps.size())
	_pace = _per_stomp / (_clips.fps * KEYED_INTERVAL)


## True when the clips key a standing stomp for both feet.
func keyed() -> bool:
	return _lifts.has("left") and _lifts.has("right")


## A sim stomp names `side`; the clip is at frame t (`playing`: the stomp clip is on). Returns the
## frame to (re)start the clip from, or -1 when it plays on: the named foot's part follows the one
## that is playing (it hurries to its end when that is still under way).
func on_stomp(playing: bool, t: float, side: String) -> float:
	if _since < KEYED_INTERVAL * 4.0:
		interval = maxf(0.1, _since)
	_since = 0.0
	_held = 0.0
	var base := maxf(1.0, KEYED_INTERVAL / interval) * _pace
	var n := float(_clips.frames_of(CLIP))
	var want := fposmod(Num.f(_lifts.get(side, 0.0)) - LEAD_S * _clips.fps * _pace, n)
	if playing and absf(wrapf(want - fposmod(_until, n), -n * 0.5, n * 0.5)) < 0.5:
		_until += _per_stomp
		rate = base * clampf((_until - t) / _per_stomp, 1.0, HURRY_MAX)
		return -1.0
	rate = base
	_until = want + _per_stomp
	return want


## Runs the time since the last sim stomp on by dt (every frame, whatever plays).
func tick(dt: float) -> void:
	_since += dt


## The clip frame after dt more of the stomp from frame t: it stops on the end of the stomps
## asked for.
func advance(t: float, dt: float) -> float:
	var to := minf(t + dt * _clips.fps * rate, _until)
	if to >= _until:
		_held += dt
	return to


## True once the stomps asked for have played and their end has been held HOLD_S.
func done() -> bool:
	return _held >= HOLD_S
