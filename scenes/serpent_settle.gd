class_name SerpentSettle
extends RefCounted
## What the drawn serpent does once its head has stopped (motion critic round 3: "an explicit,
## visible settle ... followed by a living idle ... so it never reads as switched off"; director
## D-210: "snake curls up into a defensive position, tongue flicking dangerously"). Over coil_s
## the body draws itself into a defensive coil (SerpentCoil), the head end first and the tail
## last, its head raised and drawn back in an S ready to strike. Then it idles on the coil: a slow
## breath (the girth swells by idle_breath every idle_breath_s), the head tracking slowly side to
## side (idle_track rad over idle_track_s), and now and then a burst of 2-3 quick tongue flicks
## (a flick every flick_s) with a short jab of the head on the first (idle_jab m). Bursts come every
## idle_gap_min to idle_gap_max s, spaced by a fixed hash so a replay lays the same ones. The
## head never travels. Presentation only (data/tuning.json "serpent").

## Seconds the head has stood still (0 while it moves).
var still := 0.0
## Height of each joint above the ground (m) as drawn now: the coil's stack, none while it moves.
var heights := PackedFloat32Array()
var _cfg: Dictionary
var _from := PackedVector2Array()
var _to := PackedVector2Array()
var _to_height := PackedFloat32Array()


func _init(cfg: Dictionary) -> void:
	_cfg = cfg


## The joints to draw (head first): `laid` while the head moves; once it stops, drawing itself
## into the coil from the shape it stopped in, then idling on it. `heading`: the way it faced.
func apply(
	laid: PackedVector2Array, moving: bool, delta: float, heading: Vector2
) -> PackedVector2Array:
	var seg := laid[0].distance_to(laid[1])
	if heights.size() != laid.size():
		heights.resize(laid.size())
		heights.fill(0.0)
	if moving:
		still = 0.0
		var ease := exp(-delta / Num.f(_cfg["coil_uncoil_s"]))
		for j: int in heights.size():  # the stack settles back to the ground as it sets off
			heights[j] *= ease
		return laid
	if still == 0.0:
		_from = laid.duplicate()
		var made := SerpentCoil.target(laid, heading, seg, _cfg)
		_to = made[0]
		_to_height = made[1]
	still += delta
	var out := PackedVector2Array()
	out.resize(_from.size())
	var span := maxf(Num.f(_cfg["coil_s"]) * (1.0 - Num.f(_cfg["coil_stagger"])), 0.0001)
	var last := maxf(1.0, _from.size() - 1.0)
	for j: int in _from.size():
		var late := Num.f(_cfg["coil_s"]) * Num.f(_cfg["coil_stagger"]) * j / last
		var k := smoothstep(0.0, 1.0, (still - late) / span)
		out[j] = _from[j].lerp(_to[j], k)
		heights[j] = k * _to_height[j]
	return SerpentSettle.keep_lengths(out, seg)


## Seconds into the idle (none until the coil is made).
func idle_time() -> float:
	return maxf(still - Num.f(_cfg["coil_s"]), 0.0)


## How much thicker the body is drawn now (its breath; 1 while it moves).
func swell() -> float:
	var t := idle_time()
	if t <= 0.0:
		return 1.0
	var breath := 0.5 - 0.5 * cos(TAU * t / Num.f(_cfg["idle_breath_s"]))
	return 1.0 + Num.f(_cfg["idle_breath"]) * _fade(t) * breath


## How far the idle head is turned off the way it faces (rad, signed): a slow look about.
func tracking() -> float:
	var t := idle_time()
	var each := Num.f(_cfg["idle_track_s"])
	var look := 0.7 * sin(TAU * t / each) + 0.3 * sin(TAU * t / (each * 0.37) + 1.3)
	return Num.f(_cfg["idle_track"]) * _fade(t) * look


## How far the head jabs forward now (m): the first flick of each burst.
func jab() -> float:
	var t := idle_time()
	var burst := _burst(t)
	if burst.x < 0.0:
		return 0.0
	var u := clampf((t - burst.x) / Num.f(_cfg["flick_s"]), 0.0, 1.0)
	return Num.f(_cfg["idle_jab"]) * _fade(t) * pow(sin(PI * u), 2.0)


## How far the tongue is out now (0 in, 1 fully out): quick flicks, two or three to a burst.
func tongue() -> float:
	var t := idle_time()
	var burst := _burst(t)
	if burst.x < 0.0:
		return 0.0
	var each := Num.f(_cfg["flick_s"])
	var u := (t - burst.x) / each
	if u < 0.0 or u >= burst.y:
		return 0.0
	return pow(sin(PI * fposmod(u, 1.0)), 0.7)


## The burst under way at idle time `t`, or the one before it just ended: (its start, its flicks),
## start < 0 before the first. Bursts start idle_first s in, then every idle_gap_min..max s.
func _burst(t: float) -> Vector2:
	var start := Num.f(_cfg["idle_first"])
	var k := 0
	while t >= start + _gap(k):
		start += _gap(k)
		k += 1
	if t < start:
		return Vector2(-1.0, 0.0)
	return Vector2(start, 2.0 + floorf(_hash(k * 7 + 3) * 2.0))  # 2 or 3 flicks


## Seconds from the start of burst `k` to the start of the next.
func _gap(k: int) -> float:
	return lerpf(Num.f(_cfg["idle_gap_min"]), Num.f(_cfg["idle_gap_max"]), _hash(k))


## A fixed pseudo-random number in 0..1 for `n` (no clock, no random state: replays agree).
static func _hash(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898 + 78.233) * 43758.5453, 1.0)


func _fade(t: float) -> float:
	return smoothstep(0.0, Num.f(_cfg["idle_fade_s"]), t)


## The chain rebuilt from its head with every segment `seg` long, each joint along the way it lies.
static func keep_lengths(points: PackedVector2Array, seg: float) -> PackedVector2Array:
	var out := points.duplicate()
	for j: int in range(1, out.size()):
		var dir := points[j] - out[j - 1]
		if dir.length() > 0.0:
			out[j] = out[j - 1] + dir.normalized() * seg
	return out
