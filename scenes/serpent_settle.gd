class_name SerpentSettle
extends RefCounted
## How the drawn serpent settles when its head stops (motion critic, round 2: "a 0.3-0.5 s settle
## (tail catches up, curves relax, head eases to a halt) instead of freezing"): over settle_s the
## body's curves relax (settle_relax, more toward the tail), each segment kept its length from the
## still head back, so the tail draws up along the body. Then it holds; the head never moves.
## Presentation only (data/tuning.json "serpent").

## How many joints each side a joint is averaged with for the relaxed shape.
const REACH := 10

## Seconds the head has stood still (0 while it moves).
var still := 0.0
var _cfg: Dictionary
var _from := PackedVector2Array()
var _to := PackedVector2Array()


func _init(cfg: Dictionary) -> void:
	_cfg = cfg


## The joints to draw (head first): `laid` while the head moves, else settling from the shape it
## stopped in toward its relaxed shape.
func apply(laid: PackedVector2Array, moving: bool, delta: float, seg: float) -> PackedVector2Array:
	if moving:
		still = 0.0
		return laid
	if still == 0.0:
		_from = laid.duplicate()
		_to = relaxed(laid, Num.f(_cfg["settle_relax"]), seg)
	still += delta
	var k := smoothstep(0.0, Num.f(_cfg["settle_s"]), still)
	var out := PackedVector2Array()
	out.resize(_from.size())
	for j: int in _from.size():
		out[j] = _from[j].lerp(_to[j], k)
	return keep_lengths(out, seg)


## `points` (head first) with their bends eased: each joint drawn toward the mean of the joints
## within REACH of it (fewer near the ends, evenly both sides) by `strength`, scaled from none
## at the head to all of it at the tail.
static func relaxed(points: PackedVector2Array, strength: float, seg: float) -> PackedVector2Array:
	var out := points.duplicate()
	var last := out.size() - 1
	for j: int in range(1, last + 1):
		var sum := Vector2.ZERO
		var reach := mini(REACH, mini(j, last - j))  # even both sides: the ends are not pulled in
		var lo := j - reach
		var hi := j + reach
		for k: int in range(lo, hi + 1):
			sum += points[k]
		var mean := sum / float(hi - lo + 1)
		out[j] = points[j].lerp(mean, strength * float(j) / last)
	return keep_lengths(out, seg)


## The chain rebuilt from its head with every segment `seg` long, each joint along the way it lies.
static func keep_lengths(points: PackedVector2Array, seg: float) -> PackedVector2Array:
	var out := points.duplicate()
	for j: int in range(1, out.size()):
		var dir := points[j] - out[j - 1]
		if dir.length() > 0.0:
			out[j] = out[j - 1] + dir.normalized() * seg
	return out
