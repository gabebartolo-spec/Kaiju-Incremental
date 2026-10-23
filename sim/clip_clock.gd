class_name ClipClock
extends RefCounted
## Which baked clip a clip-animated kaiju plays and where in it (D-208: the one chooser, the sim's
## for a heavy body, so its contact volume rides the pose that is drawn; ClipGait runs one of its
## own for a body no sim feeds): it idles, walks, turns on the spot and roars, cross-fading between
## them over BLEND_SECONDS. The walk's frame comes from the caller (the sim's step clock, or the
## distance walked); a roar plays to its end; a standing body whose heading has run TURN_TRIGGER
## ahead of its body turns on the spot with a turn clip. Pure, no randomness.

const BLEND_SECONDS := 0.25
## Heading error (rad) that makes a standing kaiju turn on the spot with a turn clip.
const TURN_TRIGGER := 0.6
## Frames of lead-in kept before the part of a turn clip that carries its yaw, and of settle
## after it (the tail's whip settles about half a second after the body stops).
const TURN_PAD := 6
const TURN_SETTLE := 24

## The clip playing ("idle", "walk", "turn_left", "turn_right" or "roar") and its time (frames).
var state := "idle"
var time := 0.0
## The clip faded out of, its time, and how far the fade is (1: done).
var from := ""
var from_time := 0.0
var blend := 1.0
## A roar on the move keeps the walk on the legs (a heavy body, D-201): whether it does now, and
## the walk frame the legs are at.
var legs_on := false
var legs_t := 0.0
var _frames := {}  # clip -> frames
var _loops := {}  # clip -> true when it loops
var _spans := {}  # turn clip -> Vector2(first, last frame of its yaw)
var _fps := 24.0
var _roar_queued := false


## meta: {"fps", "clips": {name: [frames, loops]}, "spans": {turn: [first, last]}}.
func _init(meta: Dictionary) -> void:
	_fps = Num.f(meta["fps"])
	var clips: Dictionary = meta["clips"]
	for clip: String in clips:
		var row: Array = clips[clip]
		_frames[clip] = Num.i(row[0])
		_loops[clip] = row[1] == true
	var spans: Dictionary = meta["spans"]
	for turn: String in spans:
		var span: Array = spans[turn]
		_spans[turn] = Vector2(Num.f(span[0]), Num.f(span[1]))


## A roar starts at the next step, from whatever the kaiju is doing, and plays to its end.
func roar() -> void:
	_roar_queued = true


## Advances dt seconds. moving: the body walks; turn_err: its heading's lead over its body (rad,
## + to the left, as the presentation's yaw counts); walk_at(entering: bool) -> the walk frame now
## (entering: the walk starts this step).
func step(dt: float, moving: bool, turn_err: float, walk_at: Callable) -> void:
	if _roar_queued:
		_roar_queued = false
		_go("roar", 0.0)
	elif state == "roar" or state.begins_with("turn"):
		if _ends(moving):
			_settle(moving, walk_at)
	else:
		_choose(moving, turn_err, walk_at)
	if state == "walk":
		time = Num.f(walk_at.call(false))
	else:
		time += dt * _fps
	blend = minf(1.0, blend + dt / BLEND_SECONDS)
	legs_on = state == "roar" and moving
	if state == "walk":
		legs_t = time
	elif legs_on:
		legs_t = Num.f(walk_at.call(false))


## Out of the idle or the walk: walking when the body moves, a standing turn when its heading has
## run ahead of its body, else the idle.
func _choose(moving: bool, turn_err: float, walk_at: Callable) -> void:
	if moving:
		if state != "walk":
			_go("walk", Num.f(walk_at.call(true)))
	elif absf(turn_err) > TURN_TRIGGER and _spans.has("turn_left"):
		var turn := "turn_left" if turn_err > 0.0 else "turn_right"
		var span: Vector2 = _spans[turn]
		_go(turn, maxf(0.0, span.x - TURN_PAD))
	elif state != "idle":
		_go("idle", 0.0)


## True when a roar has played to its end, or a standing turn has settled (or the body walks off).
func _ends(moving: bool) -> bool:
	if state == "roar":
		return time >= Num.f(_frames.get(state, 1)) - 1.0
	var span: Vector2 = _spans[state]
	return moving or time >= span.y + TURN_SETTLE


## Out of a roar or a turn: into the walk if the body walks, else the idle.
func _settle(moving: bool, walk_at: Callable) -> void:
	if moving:
		_go("walk", Num.f(walk_at.call(true)))
	else:
		_go("idle", 0.0)


## True while a standing turn's clip plays.
func turning() -> bool:
	return state.begins_with("turn")


## The clip's length in frames.
func frames_of(clip: String) -> int:
	return Num.i(_frames.get(clip, 1))


## The state as a plain row (tests: reload-then-continue compares these).
func snapshot() -> Array:
	return [state, time, from, from_time, blend, legs_on, legs_t, _roar_queued]


func _go(next: String, at: float) -> void:
	from = state
	from_time = time
	blend = 0.0
	state = next
	time = at
