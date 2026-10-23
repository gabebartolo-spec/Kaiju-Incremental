class_name SerpentTrail
extends RefCounted
## The serpent's body as the path its head took (D-198, research_serpent_slither 3c): the head's
## centreline is recorded every `spacing` of travel (by distance, never by time), and any point of
## the body sits on that path a distance behind the head. Nothing is recorded while the head stands
## still, so a stopped body is frozen; every body point replays the head's own path, so it never
## slides sideways or cuts a corner. Sample n sits at arc position n * spacing (the straight body
## laid out behind a new head has negative n). Pure: no Node, no clock, no randomness.

var spacing: float
## Arc position of the head: how far it has travelled since the trail was laid.
var head_s := 0.0
var head := Vector2.ZERO
var head_heading := Vector2(0, -1)
## The speed and turn rate the head had at its last move.
var head_speed := 0.0
var head_turn := 0.0
## Per sample (ring, by sample number): centreline point, heading, and the speed and turn rate
## (rad/s, signed as Vector2.angle_to) the head had as it passed there.
var _points := PackedVector2Array()
var _headings := PackedVector2Array()
var _speeds := PackedFloat32Array()
var _turns := PackedFloat32Array()
var _first := 0  # oldest sample still held
var _last := 0  # newest sample


## A trail `reach` long (the body length plus slack) recorded every `p_spacing`, with a straight
## body lying behind `at` against `heading`.
func _init(p_spacing: float, reach: float, at: Vector2, heading: Vector2) -> void:
	spacing = p_spacing
	var size := int(ceilf(reach / spacing)) + 2
	_points.resize(size)
	_headings.resize(size)
	_speeds.resize(size)
	_turns.resize(size)
	head = at
	head_heading = heading.normalized()
	_last = 0
	_first = 1 - size
	for n: int in range(_first, 1):
		_put(n, at + head_heading * (n * spacing), head_heading, Vector2.ZERO)


## The head moved in a straight line to `to` (heading `heading`, at `speed`, turning at `turn`):
## records every sample it passed, the heading, speed and turn changing evenly from the last move's
## over this one (so nothing a sample carries steps from one frame's move to the next).
func advance(to: Vector2, heading: Vector2, speed: float, turn: float) -> void:
	var from := head
	var from_s := head_s
	var from_heading := head_heading
	var from_speed := head_speed
	var from_turn := head_turn
	var step := from.distance_to(to)
	head_heading = heading
	head_speed = speed
	head_turn = turn
	if step <= 0.0:
		return
	head_s += step
	head = to
	while (_last + 1) * spacing <= head_s:
		_last += 1
		var t := (_last * spacing - from_s) / step
		var dir := from_heading.slerp(heading, t).normalized()
		var motion := Vector2(lerpf(from_speed, speed, t), lerpf(from_turn, turn, t))
		_put(_last, from.lerp(to, t), dir, motion)
		_first = maxi(_first, _last - _points.size() + 1)


## The centreline point `behind` the head along its path (clamped to the oldest sample held).
func at(behind: float) -> Vector2:
	var s := head_s - behind
	if s >= _last * spacing:
		var since := head_s - _last * spacing
		if since <= 0.0:
			return head
		return point(_last).lerp(head, (s - _last * spacing) / since)
	var n := clampi(floori(s / spacing), _first, _last - 1)
	return point(n).lerp(point(n + 1), clampf(s / spacing - n, 0.0, 1.0))


## How far behind the head the oldest sample lies.
func reach() -> float:
	return head_s - _first * spacing


func first() -> int:
	return _first


func last() -> int:
	return _last


func point(n: int) -> Vector2:
	return _points[posmod(n, _points.size())]


func heading_of(n: int) -> Vector2:
	return _headings[posmod(n, _headings.size())]


func speed_of(n: int) -> float:
	return _speeds[posmod(n, _speeds.size())]


func turn_of(n: int) -> float:
	return _turns[posmod(n, _turns.size())]


## motion: (speed, turn rate) as the head passed.
func _put(n: int, p: Vector2, heading: Vector2, motion: Vector2) -> void:
	var i := posmod(n, _points.size())
	_points[i] = p
	_headings[i] = heading
	_speeds[i] = motion.x
	_turns[i] = motion.y
