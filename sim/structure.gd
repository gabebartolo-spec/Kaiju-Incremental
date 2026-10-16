class_name Structure
extends RefCounted
## A building as a real structure: a grid of chunks (one sim unit each way, one floor tall),
## each with its own strength. Nothing has a health bar; what stands is whatever is still
## held up. settle() finds what has lost support:
##  - "drop":   a part no longer connected to the ground falls straight down;
##  - "topple": a grounded part whose centre of mass hangs past what holds it up (a tower with
##              its base eaten away on one side) tips over its supporting edge, like Jenga.
## Pure and deterministic: same damage, same collapse.

var w: int
var d: int
var h: int
var max_hp: float
var alive_count: int
var _hp: PackedFloat32Array


func _init(p_w: int, p_d: int, p_h: int, chunk_hp: float) -> void:
	w = p_w
	d = p_d
	h = p_h
	max_hp = chunk_hp
	_hp = PackedFloat32Array()
	_hp.resize(w * d * h)
	_hp.fill(chunk_hp)
	alive_count = w * d * h


func index(c: Vector3i) -> int:
	return c.x + c.z * w + c.y * w * d


func inside(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < w and c.y < h and c.z < d


func alive(c: Vector3i) -> bool:
	return inside(c) and _hp[index(c)] > 0.0


## Damages one chunk; true if it broke now.
func damage(c: Vector3i, amount: float) -> bool:
	if not alive(c):
		return false
	var i := index(c)
	_hp[i] -= amount
	if _hp[i] <= 0.0:
		alive_count -= 1
		return true
	return false


func remove(c: Vector3i) -> void:
	if alive(c):
		_hp[index(c)] = 0.0
		alive_count -= 1


## Highest standing chunk in column (x, z) below `below_y`, or -1.
func top_below(x: int, z: int, below_y: int) -> int:
	for y: int in range(mini(below_y, h) - 1, -1, -1):
		if alive(Vector3i(x, y, z)):
			return y
	return -1


## Removes and returns every part that lost support, as
## {"cells": Array[Vector3i], "kind": "drop"|"topple", "pivot": Vector3 (local), "dir": Vector2i}.
func settle() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var grounded := {}
	var frontier: Array[Vector3i] = []
	for x: int in w:
		for z: int in d:
			var c := Vector3i(x, 0, z)
			if alive(c):
				grounded[c] = true
				frontier.append(c)
	_flood(frontier, grounded)
	var loose := {}
	for y: int in h:
		for x: int in w:
			for z: int in d:
				var c := Vector3i(x, y, z)
				if alive(c) and not grounded.has(c) and not loose.has(c):
					var part := _component(c, loose)
					out.append(
						{"cells": part, "kind": "drop", "pivot": Vector3.ZERO, "dir": Vector2i.ZERO}
					)
	for part: Dictionary in out:
		var cells: Array[Vector3i] = part["cells"]
		for c: Vector3i in cells:
			remove(c)
	var tipping := _topple_check()
	if not tipping.is_empty():
		var cells: Array[Vector3i] = tipping["cells"]
		for c: Vector3i in cells:
			remove(c)
		out.append(tipping)
	return out


func _flood(frontier: Array[Vector3i], seen: Dictionary) -> void:
	var dirs: Array[Vector3i] = [
		Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK
	]
	while not frontier.is_empty():
		var c: Vector3i = frontier.pop_back()
		for step: Vector3i in dirs:
			var n := c + step
			if alive(n) and not seen.has(n):
				seen[n] = true
				frontier.append(n)


func _component(start: Vector3i, seen: Dictionary) -> Array[Vector3i]:
	var local := {start: true}
	var frontier: Array[Vector3i] = [start]
	_flood(frontier, local)
	var cells: Array[Vector3i] = []
	for c: Vector3i in local:
		cells.append(c)
		seen[c] = true
	return cells


## Lowest floor whose load (everything standing at or above it) has its centre of mass outside
## the chunks holding it up from the floor below. Returns the toppling part, or {}.
func _topple_check() -> Dictionary:
	for level: int in range(1, h):
		var mass := 0
		var com := Vector2.ZERO
		for y: int in range(level, h):
			for x: int in w:
				for z: int in d:
					if alive(Vector3i(x, y, z)):
						mass += 1
						com += Vector2(x + 0.5, z + 0.5)
		if mass == 0:
			return {}
		com /= mass
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for x: int in w:
			for z: int in d:
				if alive(Vector3i(x, level - 1, z)) and alive(Vector3i(x, level, z)):
					lo = Vector2(minf(lo.x, x), minf(lo.y, z))
					hi = Vector2(maxf(hi.x, x + 1), maxf(hi.y, z + 1))
		if lo.x == INF:
			continue  # nothing touches across this floor: settle()'s drop handles it
		var over := Vector2(
			com.x - hi.x if com.x > hi.x else (com.x - lo.x if com.x < lo.x else 0.0),
			com.y - hi.y if com.y > hi.y else (com.y - lo.y if com.y < lo.y else 0.0)
		)
		if over == Vector2.ZERO:
			continue
		var dir := Vector2i(signi(roundi(over.x * 100.0)), 0)
		if absf(over.y) > absf(over.x):
			dir = Vector2i(0, signi(roundi(over.y * 100.0)))
		var pivot := Vector3(
			hi.x if dir.x > 0 else (lo.x if dir.x < 0 else com.x),
			level,
			hi.y if dir.y > 0 else (lo.y if dir.y < 0 else com.y)
		)
		var cells: Array[Vector3i] = []
		for y: int in range(level, h):
			for x: int in w:
				for z: int in d:
					if alive(Vector3i(x, y, z)):
						cells.append(Vector3i(x, y, z))
		return {"cells": cells, "kind": "topple", "pivot": pivot, "dir": dir}
	return {}
