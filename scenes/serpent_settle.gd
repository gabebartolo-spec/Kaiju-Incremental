class_name SerpentSettle
extends RefCounted
## What the drawn serpent does once its head has stopped (motion critic round 3: "an explicit,
## visible settle ... followed by a living idle ... so it never reads as switched off"; director
## D-210: "snake curls up into a defensive position, tongue flicking dangerously"). Over coil_s the
## body slides head first along one precomputed path (SerpentCoil: the outer ring first, then
## spiralling in and up, the neck rising out of the centre), every joint following the one ahead, so
## nothing passes through the forming coil; the stretch still lying where it stopped is drawn taut
## as it is pulled in (fully by stop_taut of the way into the coil; none at its head end), so the
## thin tail is not whipped round the old S's bends at the slide's speed (round 5 critic: "no needle
## whip"). A body that stopped bunched up (shortened, `squash`) lengthens again as the head leads it
## in: its tail holds still until the head has gone the shortfall, so the coil forms from the whole
## body and the tail never slides back out. Then it idles on the coil: a breath (the girth and the
## rings swell by idle_breath every idle_breath_s), the raised head swaying slowly side to side
## (idle_track rad over idle_track_s), and every idle_gap_min to idle_gap_max s a burst of 2-3 quick
## tongue flicks (a flick every flick_s, the tongue wagging tongue_wag rad side to side as it
## flicks) with a short jab of the head on the first (idle_jab m), spaced by a fixed hash so a
## replay lays the same ones. The sim head never travels. Presentation only (data/tuning.json
## "serpent").

## How far into the coil path (m) the head lowers from a rear it stopped in onto the outer ring.
const REAR_DROP := 6.0
## How far into the coil (its share) the stopped front, reared and raised, has come down onto the
## ground (it would otherwise pass beside the forming rings at their height).
const SETTLE_DOWN := 0.35
## The taut shape: the stopped body averaged over this many joints each way, this many times; it
## eases back to the body as it lies over TAUT_TAPER m before the head.
const TAUT_REACH := 6
const TAUT_PASSES := 6
const TAUT_TAPER := 8.0
## The tuck (round 7 critic: the tail's end "stands up as a thin leaf-shaped blade" off the coil as
## it is reeled in): as the stopped stretch goes taut, its last HUG_LEN m before the head's stop are
## drawn onto a curve that hooks in from the stop and runs round the outer ring HUG_IN m inside its
## outer radius, on the ground under the raised turn above it, so the tail's end slides in under
## the last ring rather than sticking out of the coil. Past that the curve steers for the taut
## stretch HUG_LOOK m further on until it is within HUG_SNAP m of it, then follows it. The curve
## steers HUG_STEER of its radial gap a metre (at most HUG_TURN of a right angle in), bending no
## tighter than HUG_BEND m round the hook, min_bend_widths body widths after, in HUG_STEP m steps.
const HUG_LEN := 6.0
const HUG_IN := 0.5
const HUG_STEER := 1.5
const HUG_TURN := 2.0
const HUG_BEND := 1.2
const HUG_LOOK := 4.0
const HUG_SNAP := 0.4
const HUG_STEP := 0.25

## Seconds the head has stood still (0 while it moves).
var still := 0.0
## How much of its length the body is drawn at as it moves (1: all), set before `apply`.
var squash := 1.0
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
## The stopped body (tail to head, as the track starts), its taut shape, and the two blended now.
var _lay := PackedVector3Array()
var _taut := PackedVector3Array()
var _now := PackedVector3Array()
## The rear the head stopped in (m) and how much of the stop's raise is left now (1 to 0).
var _rear := 0.0
var _lower := 1.0
## The body's shortening as it stopped (`squash` then) and its joint spacing at full length (m).
var _squash_at := 1.0
var _seg := 0.0


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
		_squash_at = squash
		_seg = seg / squash
	still += delta
	var drawn_in := smoothstep(0.0, 1.0, still / Num.f(_cfg["coil_s"]))
	var head := _start + _coil * drawn_in
	seg = _lengthened(_coil * drawn_in, laid.size() - 1)
	var taut := Num.f(_cfg["stop_taut"])
	var pull := smoothstep(0.0, taut, drawn_in) if taut > 0.0 else 0.0
	_lower = 1.0 - smoothstep(0.0, SETTLE_DOWN, drawn_in)
	for i: int in _lay.size():
		_now[i] = _lay[i].lerp(_taut[i], pull)
		_now[i].y = _lay[i].y * _lower
	var grow := (swell() - 1.0) / maxf(Num.f(_cfg["idle_breath"]), 0.0001)
	var spread := 1.0 + Num.f(_cfg["idle_ring_breath"]) * grow
	var out := PackedVector2Array()
	out.resize(laid.size())
	for j: int in laid.size():
		var p := _on_track(head - j * seg)
		out[j] = _centre + (Vector2(p.x, p.z) - _centre) * spread
		heights[j] = p.y
	return out


## The joint spacing (m) once the head has gone `gone` m into the coil: from the stop's shortened
## spacing back to the full one as the head goes the shortfall (`count` segments), so the tail
## holds still until then.
func _lengthened(gone: float, count: int) -> float:
	var short := count * _seg * (1.0 - _squash_at)
	if short <= 0.0:
		return _seg
	return _seg * lerpf(_squash_at, 1.0, minf(gone / short, 1.0))


## The track for a stop: the body as it lies (tail to head, at the heights it stopped at), then the
## coil path from its head (the head lowering from any rear onto the outer ring over REAR_DROP m,
## that rear itself settling as the coil begins: `_on_track`).
func _lay_track(
	laid: PackedVector2Array, lifted: PackedFloat32Array, heading: Vector2, line: PackedVector2Array
) -> void:
	_track = PackedVector3Array()
	_lay = PackedVector3Array()
	for j: int in range(laid.size() - 1, -1, -1):
		var lift := lifted[j] if j < lifted.size() else 0.0
		_lay.append(Vector3(laid[j].x, lift, laid[j].y))
		_track.append(Vector3(laid[j].x, 0.0, laid[j].y))  # its heights are kept in _lay
	var way := (laid[0] - laid[1]).normalized()
	var coil := SerpentCoil.path(laid, way, line, heading, _cfg)
	var ring: Vector2 = SerpentCoil.centre(laid, way, line, heading, _cfg)[0]
	_rear = lifted[0] if lifted.size() > 0 else 0.0
	_lower = 1.0
	for i: int in range(1, coil.size()):
		_track.append(coil[i])
	_centre = ring
	_arc = PackedFloat32Array([0.0])
	for i: int in range(1, _track.size()):
		_arc.append(_arc[i - 1] + _track[i].distance_to(_track[i - 1]))
	_start = _arc[laid.size() - 1]
	_coil = _arc[_arc.size() - 1] - _start
	_now = _lay.duplicate()
	_taut = _lay.duplicate()
	for _pass: int in TAUT_PASSES:
		var was := _taut.duplicate()
		for i: int in was.size():
			var sum := Vector3.ZERO
			var n := 0
			for k: int in range(maxi(i - TAUT_REACH, 0), mini(i + TAUT_REACH, was.size() - 1) + 1):
				sum += was[k]
				n += 1
			_taut[i] = sum / n
	var last := _lay.size() - 1
	for i: int in _lay.size():
		var keep := 1.0 - smoothstep(0.0, TAUT_TAPER, _arc[last] - _arc[i])
		_taut[i] = _taut[i].lerp(_lay[i], keep)
		_taut[i].y = _lay[i].y
	_tuck(laid[0], way)


## The stopped stretch's taut shape near the head's stop (at `stop`, facing `way`) drawn onto the
## tuck: a curve from the stop round under the outer ring, then back onto the taut stretch.
func _tuck(stop: Vector2, way: Vector2) -> void:
	var last := _lay.size() - 1
	var length := _arc[last]
	var taut := _taut.duplicate()
	var curve := _hug_curve(stop, way, taut)
	var joined := float(curve.size() - 1) * HUG_STEP  # where the curve meets the taut stretch
	var meets := _nearest_back(taut, curve[curve.size() - 1])
	for i: int in _lay.size():
		var back := length - _arc[i]
		if back < joined:
			var on := curve[int(back / HUG_STEP)]
			_taut[i] = Vector3(on.x, taut[i].y, on.y)
		else:
			var p := _back_on(taut, minf(meets + back - joined, length))
			_taut[i] = Vector3(p.x, taut[i].y, p.z)


## The tuck's curve from the stop (facing back along -`way`): round the ring, then steering for
## the taut stretch `taut` until within HUG_SNAP m of it (or the stretch's length is used up).
func _hug_curve(stop: Vector2, way: Vector2, taut: PackedVector3Array) -> PackedVector2Array:
	var radius := Num.f(_cfg["coil_radius"]) - HUG_IN
	var wide := HUG_STEP / (Num.f(_cfg["min_bend_widths"]) * Num.f(_cfg["girth"]))
	var round_way := 1.0 if (stop - _centre).orthogonal().dot(-way) > 0.0 else -1.0
	var curve := PackedVector2Array([stop])
	var at := stop
	var facing := -way
	for k: int in range(1, ceili(_arc[_arc.size() - 1] / HUG_STEP)):
		var want: Vector2
		var most := HUG_STEP / HUG_BEND
		if k * HUG_STEP < HUG_LEN:
			var out := at - _centre
			var gap := clampf((out.length() - radius) * HUG_STEER, -HUG_TURN, HUG_TURN)
			want = out.orthogonal().normalized() * round_way - out.normalized() * gap
		else:
			most = wide
			var near := _nearest_back(taut, at)
			var p := _back_on(taut, near)
			if Vector2(p.x, p.z).distance_to(at) < HUG_SNAP and k * HUG_STEP > HUG_LEN + HUG_LOOK:
				break
			var aim := _back_on(taut, near + HUG_LOOK)
			want = Vector2(aim.x, aim.z) - at
		facing = facing.rotated(clampf(facing.angle_to(want), -most, most))
		at += facing * HUG_STEP
		curve.append(at)
	return curve


## How far behind the head's stop (by the stopped body's arc) the point of `shape` nearest `p` is.
func _nearest_back(shape: PackedVector3Array, p: Vector2) -> float:
	var last := shape.size() - 1
	var best := INF
	var back := 0.0
	for i: int in range(last, 0, -1):
		var a := Vector2(shape[i].x, shape[i].z)
		var b := Vector2(shape[i - 1].x, shape[i - 1].z)
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if q.distance_to(p) < best:
			best = q.distance_to(p)
			var f := a.distance_to(q) / maxf(a.distance_to(b), 0.000001)
			back = _arc[last] - lerpf(_arc[i], _arc[i - 1], f)
	return back


## The point of `shape` (the stopped stretch, tail to head as `_lay`) `back` m behind the head's
## stop, by the stopped body's own arc.
func _back_on(shape: PackedVector3Array, back: float) -> Vector3:
	var last := shape.size() - 1
	for i: int in range(last, 0, -1):
		var near := _arc[last] - _arc[i]
		var far := _arc[last] - _arc[i - 1]
		if back <= far:
			return shape[i].lerp(shape[i - 1], (back - near) / maxf(far - near, 0.000001))
	return shape[0]


## The point `s` m along the track (before its start: carried on straight back from it). The
## stretch where the body stopped is read off its shape now (`_now`), back from the head's stop.
func _on_track(s: float) -> Vector3:
	if s < _start:
		return _on_now(_start - s)
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
	var p := _track[lo].lerp(_track[hi], f)
	p.y += _rear * _lower * (1.0 - smoothstep(0.0, REAR_DROP, s - _start))
	return p


## The point `back` m behind the head's stop along the stopped stretch as drawn now (past its
## tail: carried on straight).
func _on_now(back: float) -> Vector3:
	var i := _now.size() - 1
	var left := back
	while i > 0:
		var step := _now[i].distance_to(_now[i - 1])
		if step >= left:
			return _now[i].lerp(_now[i - 1], left / maxf(step, 0.000001))
		left -= step
		i -= 1
	if _now.size() < 2:
		return _now[0]
	return _now[0] + (_now[0] - _now[1]).normalized() * left


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
	var look := 0.85 * sin(TAU * t / each) + 0.15 * sin(TAU * t / (each * 2.3) + 1.3)
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


## How far the tongue is turned off the head's way now (rad, about the head's up): side to side
## once each flick, the next flick the other way round.
func tongue_wag() -> float:
	var t := idle_time()
	var burst := _burst(t)
	if burst.x < 0.0:
		return 0.0
	var u := (t - burst.x) / Num.f(_cfg["flick_s"])
	if u < 0.0 or u >= burst.y:
		return 0.0
	var turn := 1.0 if int(u) % 2 == 0 else -1.0
	return Num.f(_cfg["tongue_wag"]) * turn * sin(TAU * fposmod(u, 1.0))


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
