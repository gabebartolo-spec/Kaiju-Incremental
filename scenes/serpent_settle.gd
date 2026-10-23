class_name SerpentSettle
extends RefCounted
## What the drawn serpent does once its head has stopped (motion critic round 3: "an explicit,
## visible settle ... followed by a living idle ... so it never reads as switched off"). Over
## settle_s its curves ease by settle_ease (each joint drawn toward the body's mean line, none at
## the head) and its tail curls in, drawing the tip tail_pull girths nearer the head. Then it
## idles: a gentle sway travels down the body (idle_sway m at the tail, none at the head, one
## sweep every idle_sway_s, idle_sway_waves waves along it) and it breathes (its girth swells by
## idle_breath every idle_breath_s), both fading in over idle_fade_s. The head never travels.
## Presentation only (data/tuning.json "serpent").

## How many joints each side make the body's mean line.
const REACH := 10
## The tail's last share of the body that curls in, and bisection steps for its curl.
const CURL_SHARE := 0.25
const CURL_STEPS := 24
const CURL_MOST := 3.0

## Seconds the head has stood still (0 while it moves).
var still := 0.0
var _cfg: Dictionary
var _from := PackedVector2Array()
var _to := PackedVector2Array()


func _init(cfg: Dictionary) -> void:
	_cfg = cfg


## The joints to draw (head first): `laid` while the head moves; once it stops, settling from
## the shape it stopped in, then idling about the settled shape.
func apply(laid: PackedVector2Array, moving: bool, delta: float, seg: float) -> PackedVector2Array:
	if moving:
		still = 0.0
		return laid
	if still == 0.0:
		_from = laid.duplicate()
		_to = settled(laid, seg)
	still += delta
	var k := smoothstep(0.0, Num.f(_cfg["settle_s"]), still)
	var out := PackedVector2Array()
	out.resize(_from.size())
	for j: int in _from.size():
		out[j] = _from[j].lerp(_to[j], k)
	return _sway(SerpentSettle.keep_lengths(out, seg))


## How much thicker the body is drawn now (its breath; 1 while it moves).
func swell() -> float:
	var t := still - Num.f(_cfg["settle_s"])
	if t <= 0.0:
		return 1.0
	var breath := 0.5 - 0.5 * cos(TAU * t / Num.f(_cfg["idle_breath_s"]))
	return 1.0 + Num.f(_cfg["idle_breath"]) * _fade(t) * breath


## The shape a body stopped in `points` settles into: curves eased, tail curled in.
func settled(points: PackedVector2Array, seg: float) -> PackedVector2Array:
	var eased := points.duplicate()
	var last := eased.size() - 1
	var ease := Num.f(_cfg["settle_ease"])
	for j: int in range(1, last + 1):
		var reach := mini(REACH, mini(j, last - j))
		var mean := Vector2.ZERO
		for i: int in range(j - reach, j + reach + 1):
			mean += points[i]
		mean /= float(2 * reach + 1)
		eased[j] = points[j].lerp(mean, ease * minf(1.0, j / 4.0))
	eased = SerpentSettle.keep_lengths(eased, seg)
	return _curl(eased, Num.f(_cfg["tail_pull"]) * Num.f(_cfg["head_width"]))


## The tail's last CURL_SHARE curled in (the way that draws it nearer the head), just enough that
## its tip comes `pull` m nearer the head.
func _curl(points: PackedVector2Array, pull: float) -> PackedVector2Array:
	var last := points.size() - 1
	var from := int(last * (1.0 - CURL_SHARE))
	var reach := points[0].distance_to(points[last])
	var half := CURL_MOST * 0.5  # curl the way that draws the tip in
	var near_plus := points[0].distance_to(_curled(points, from, half)[last])
	var side := (
		1.0 if near_plus < points[0].distance_to(_curled(points, from, -half)[last]) else -1.0
	)
	var lo := 0.0
	var hi := CURL_MOST
	for _i: int in CURL_STEPS:
		var mid := (lo + hi) * 0.5
		var tip := _curled(points, from, side * mid)[last]
		if reach - points[0].distance_to(tip) < pull:
			lo = mid
		else:
			hi = mid
	return _curled(points, from, side * (lo + hi) * 0.5)


## `points` with the segments past `from` turned progressively, `angle` in all at the tip.
static func _curled(points: PackedVector2Array, from: int, angle: float) -> PackedVector2Array:
	var out := points.duplicate()
	var last := points.size() - 1
	for j: int in range(from + 1, last + 1):
		var t := float(j - from) / (last - from)
		var along := points[j] - points[j - 1]
		out[j] = out[j - 1] + along.rotated(-angle * t * t)
	return out


## The idle's travelling sway on top of the settled body (none until the settle is done).
func _sway(points: PackedVector2Array) -> PackedVector2Array:
	var t := still - Num.f(_cfg["settle_s"])
	if t <= 0.0:
		return points
	var out := points.duplicate()
	var last := out.size() - 1
	var size := Num.f(_cfg["idle_sway"]) * _fade(t)
	var waves := Num.f(_cfg["idle_sway_waves"])
	for j: int in range(1, last + 1):
		var along := (points[j - 1] - points[mini(j + 1, last)]).normalized()
		var at := float(j) / last
		var phase := TAU * (t / Num.f(_cfg["idle_sway_s"]) - waves * at)
		out[j] = points[j] + along.orthogonal() * size * at * at * sin(phase)
	return out


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
