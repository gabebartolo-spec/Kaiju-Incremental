class_name StompBeat
extends RefCounted
## A standing stomp played from its clip (ClipGait; the adult croc's Cascadeur stomp, D-199: no
## code lift). The "stomp" clip keys two stomps, left then right, each from its lift to the next
## foot's; a sim stomp (the stomp button) plays the named foot's part once and holds its end, so a
## press makes one stomp and the button held makes one per stomp interval. The clip plays at the
## sim's stomp speed (RampageSim.stomp_speed: 0.80x of the keyed pace, Frenzy raises it to 0.90x;
## director 2026-10-26: "it looks too fast, it makes it looks weightless rather than titanic"),
## never faster, and the sim's interval is the clip's own length at that speed, so a stomp always
## plays out whole. The clip starts LEAD_S (at the keyed pace) before the foot lifts, so its own
## footfall lands it inside the scene's wait (Rampage.STOMP_WAIT over the speed). Presentation only.

const CLIP := "stomp"
## Seconds (at the keyed pace) before the foot lifts that a sim stomp starts the clip.
const LEAD_S := 0.067
## The clip's own pace: one stomp per this many seconds (r10d: 42 frames at 30 fps, two stomps).
const KEYED_INTERVAL := 0.7
## Seconds a finished stomp holds its end for the next press before the idle takes over.
const HOLD_S := 0.3

## How fast the clip plays (clip frames per frame of the file's fps; _pace x speed).
var rate := 1.0
## The stomp speed (share of the keyed pace) the next stomp plays at.
var speed := 1.0
var _clips: KaijuClips
var _lifts: Dictionary = {}  # "left" / "right" -> the clip frame that foot lifts
var _per_stomp := 1.0  # clip frames per stomp
var _pace := 1.0  # the rate that plays a stomp in KEYED_INTERVAL (the clip keeps its keyed frames)
var _until := 0.0  # the clip frame (unwrapped) the stomps asked for so far end on
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


## A sim stomp names `side` (`playing`: the stomp clip is on). Returns the
## frame to (re)start the clip from, or -1 when it plays on: the named foot's part follows the one
## that is playing, at the same speed.
func on_stomp(playing: bool, side: String) -> float:
	_held = 0.0
	rate = _pace * speed
	var n := float(_clips.frames_of(CLIP))
	var want := fposmod(Num.f(_lifts.get(side, 0.0)) - LEAD_S * _clips.fps * _pace, n)
	if playing and absf(wrapf(want - fposmod(_until, n), -n * 0.5, n * 0.5)) < 0.5:
		_until += _per_stomp
		return -1.0
	_until = want + _per_stomp
	return want


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
