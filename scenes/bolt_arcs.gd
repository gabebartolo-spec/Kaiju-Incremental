class_name BoltArcs
extends RefCounted
## The breath's charge-up crackle (VFX_STYLE visual direction 11): a few short arcs of the same bolt
## crawling over the head, neck and back, re-rolled every `arc_every` seconds, from the breath's
## first frame to its last, so the strike reads as coming out of the croc and not out of the
## rubble when the camera behind it cannot see the jaw. Presentation only; tuning "fx" "bolt".

## How far up the body an arc may start (world units at body scale 1), and how long an arc is.
const RISE := Vector2(0.2, 1.8)
const LENGTH := Vector2(1.5, 3.0)
## How far an arc may stray sideways and up/down from straight back along the spine.
const STRAY := 0.8
const LIFT := Vector2(-0.3, 0.6)
## Midpoint-displacement rounds and first push of an arc's shape.
const ROUNDS := 3
const PUSH := 0.15

## The arcs now, as world polylines (BoltView draws them).
var lines: Array[PackedVector3Array] = []
var _row: Dictionary
var _cfg: Dictionary
var _scale: float
var _wait := 0.0


func _init(row: Dictionary, cfg: Dictionary, body_scale: float) -> void:
	_row = row
	_cfg = cfg
	_scale = body_scale


func clear() -> void:
	lines.clear()
	_wait = 0.0


## Advances the clock; re-rolls the arcs when their time is up. True when they changed.
func step(delta: float, mouth: Vector3, hit: Vector3, rng: RandomNumberGenerator) -> bool:
	_wait -= delta
	var count := Num.i(_row["arcs"])
	if count == 0 or _wait > 0.0:
		return false
	_wait = Num.f(_cfg["arc_every"])
	lines.clear()
	var back := mouth - hit
	back.y = 0.0
	back = back.normalized()
	for i: int in count:
		lines.append(_arc(mouth, back, rng))
	return true


func _arc(mouth: Vector3, back: Vector3, rng: RandomNumberGenerator) -> PackedVector3Array:
	var side := back.cross(Vector3.UP)
	var along := rng.randf_range(0.5, Num.f(_row["arc_reach"])) * _scale
	var up := rng.randf_range(RISE.x, RISE.y) * _scale
	var from := mouth + back * along + Vector3.UP * up
	var way := back + side * rng.randf_range(-STRAY, STRAY)
	way = (way + Vector3.UP * rng.randf_range(LIFT.x, LIFT.y)).normalized()
	var to := from + way * rng.randf_range(LENGTH.x, LENGTH.y) * _scale
	return BoltShape.place(BoltShape.channel(rng, ROUNDS, PUSH), from, to)
