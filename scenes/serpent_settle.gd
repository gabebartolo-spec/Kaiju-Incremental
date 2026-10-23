class_name SerpentSettle
extends RefCounted
## What the drawn serpent does once its head has stopped (motion critic round 3: "an explicit,
## visible settle ... followed by a living idle ... so it never reads as switched off"; director
## D-210: "snake curls up into a defensive position, tongue flicking dangerously"). Over coil_s
## the body slides head first along one precomputed path (SerpentCoil: the outer ring first, then
## spiralling in and up, the neck rising out of the centre), every joint following the one ahead,
## so nothing passes through the forming coil. Then it idles on the coil: a breath (the girth and
## the rings swell by idle_breath every idle_breath_s), the raised head swaying slowly side to side
## (idle_track rad over idle_track_s), and every idle_gap_min to idle_gap_max s a burst of 2-3
## quick tongue flicks (a flick every flick_s) with a short jab of the head on the first (idle_jab
## m), spaced by a fixed hash so a replay lays the same ones. The sim head never travels.
## Presentation only (data/tuning.json "serpent").

## How far into the coil path (m) the head lowers from a rear it stopped in onto the outer ring.
const REAR_DROP := 6.0

## Seconds the head has stood still (0 while it moves).
var still := 0.0
## Height of each joint above the ground (m) as drawn now: the coil's stack, none while it moves.
var heights := PackedFloat32Array()
var _cfg: Dictionary
## The path the body slides along into the coil: the shape it stopped in (tail to head), then the
## coil path; (x, height, z) points and their distance along it (m).
var _track := PackedVector3Array()
var _arc := PackedFloat32Array()
## Where on the track the head stood when it stopped, and how much further the coil takes it (m).
var _start := 0.0
var _coil := 0.0
## The ring's centre (ground plane), for the breath.
var _centre := Vector2.ZERO
var _heading := Vector2.ZERO
var _line := PackedVector2Array()
var _lifted := PackedFloat32Array()


func _init(cfg: Dictionary) -> void:
	_cfg = cfg


## What a stop starts from, given each frame before `apply`: `heading` the way it faced, `line`
## the sim's centreline (head first; read only on the frame it stops), `lifted` each joint's
## height (a rear, a raised head).
func stop_at(heading: Vector2, line: PackedVector2Array, lifted: PackedFloat32Array) -> void:
	_heading = heading
	_line = line
	_lifted = lifted


## The joints to draw (head first): `laid` while the head moves; once it stops, sliding into the
## coil along its path (from what `stop_at` gave), then idling on it.
func apply(laid: PackedVector2Array, moving: bool, delta: float) -> PackedVector2Array:
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
		_lay_track(laid, _lifted, _heading, _line)
	still += delta
	var head := _start + _coil * smoothstep(0.0, 1.0, still / Num.f(_cfg["coil_s"]))
	var grow := (swell() - 1.0) / maxf(Num.f(_cfg["idle_breath"]), 0.0001)
	var spread := 1.0 + Num.f(_cfg["idle_ring_breath"]) * grow
	var out := PackedVector2Array()
	out.resize(laid.size())
	for j: int in laid.size():
		var p := _on_track(head - j * seg)
		out[j] = _centre + (Vector2(p.x, p.z) - _centre) * spread
		heights[j] = p.y
	return out


## The track for a stop: the body as it lies (tail to head, at the heights it stopped at), then the
## coil path from its head, the head lowering from any rear onto the outer ring over REAR_DROP m.
func _lay_track(
	laid: PackedVector2Array, lifted: PackedFloat32Array, heading: Vector2, line: PackedVector2Array
) -> void:
	_track = PackedVector3Array()
	for j: int in range(laid.size() - 1, -1, -1):
		var lift := lifted[j] if j < lifted.size() else 0.0
		_track.append(Vector3(laid[j].x, lift, laid[j].y))
	var way := (laid[0] - laid[1]).normalized()
	var coil := SerpentCoil.path(laid, way, line, heading, _cfg)
	var rear := lifted[0] if lifted.size() > 0 else 0.0
	var along := 0.0
	for i: int in range(1, coil.size()):
		along += coil[i].distance_to(coil[i - 1])
		var p := coil[i]
		p.y += rear * (1.0 - smoothstep(0.0, REAR_DROP, along))
		_track.append(p)
	_centre = SerpentCoil.centre(laid, way, line, heading, _cfg)[0]
	_arc = PackedFloat32Array([0.0])
	for i: int in range(1, _track.size()):
		_arc.append(_arc[i - 1] + _track[i].distance_to(_track[i - 1]))
	_start = _arc[laid.size() - 1]
	_coil = _arc[_arc.size() - 1] - _start


## The point `s` m along the track (before its start: carried on straight back from it).
func _on_track(s: float) -> Vector3:
	if s <= 0.0:
		return _track[0] + (_track[0] - _track[1]).normalized() * -s
	var lo := 0
	var hi := _arc.size() - 1
	if s >= _arc[hi]:
		return _track[hi]
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _arc[mid] <= s:
			lo = mid
		else:
			hi = mid
	var f := (s - _arc[lo]) / maxf(_arc[hi] - _arc[lo], 0.000001)
	return _track[lo].lerp(_track[hi], f)


## How far the cobra's hood is spread (0..1): it spreads as the neck rises out of the coil.
func hood() -> float:
	if still <= 0.0:
		return 0.0
	return smoothstep(0.75, 1.0, still / Num.f(_cfg["coil_s"]))


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
