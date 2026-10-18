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
## A ring landmark's arcs (Arcs): settle() first brings down every arc that lost a chunk.
var arcs: Arcs
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


## Keeps only the chunks a shape marks: one string per floor, a "1" per chunk that exists,
## x fastest then z (a landmark's baked chunks). Every other chunk is gone from the start.
func keep(layers: Array) -> void:
	for y: int in h:
		var row := str(layers[y]) if y < layers.size() else ""
		for z: int in d:
			for x: int in w:
				var k := x + z * w
				if k >= row.length() or row[k] != "1":
					remove(Vector3i(x, y, z))


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
	if arcs != null:
		for part: Dictionary in arcs.shed(self):
			var fallen: Array[Vector3i] = part["cells"]
			for c: Vector3i in fallen:
				remove(c)
			out.append(part)
	var grounded := _grounded()
	var loose := {}
	for y: int in h:
		for x: int in w:
			for z: int in d:
				var i := x + z * w + y * w * d
				if _hp[i] > 0.0 and grounded[i] == 0 and not loose.has(Vector3i(x, y, z)):
					var part := _component(Vector3i(x, y, z), loose)
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


## Every standing chunk joined to the ground floor (1 per chunk index), flooded over the raw
## strengths: a Dictionary of Vector3i and an alive() call per step cost the stadium ~10 ms a
## settle (lead, 2026-10-19).
func _grounded() -> PackedByteArray:
	var plan := w * d
	var seen := PackedByteArray()
	seen.resize(plan * h)
	var frontier := PackedInt32Array()
	for i: int in plan:
		if _hp[i] > 0.0:
			seen[i] = 1
			frontier.append(i)
	while not frontier.is_empty():
		var i := frontier[frontier.size() - 1]
		frontier.resize(frontier.size() - 1)
		var x := i % w
		var z := (i / w) % d
		var y := i / plan
		var next: Array[int] = [
			i - 1 if x > 0 else -1,
			i + 1 if x < w - 1 else -1,
			i - w if z > 0 else -1,
			i + w if z < d - 1 else -1,
			i - plan if y > 0 else -1,
			i + plan if y < h - 1 else -1,
		]
		for n: int in next:
			if n >= 0 and seen[n] == 0 and _hp[n] > 0.0:
				seen[n] = 1
				frontier.append(n)
	return seen


## The raw chunk strengths, by index() (Arcs counts over them without a call per chunk).
func standing() -> PackedFloat32Array:
	return _hp


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
## Each floor's mass and centre are summed once and every load is a running total from the top
## down: a rescan of all the floors above each one cost the stadium (28 x 28 x 13) ~66k alive()
## calls per settle, a frame stall at every hit (lead, 2026-10-19). The sums are of half-integers
## well under 2^23, exact in float, so the order of adding does not change the result.
func _topple_check() -> Dictionary:
	var floor_mass := PackedInt32Array()
	floor_mass.resize(h + 1)
	var floor_sum := PackedVector2Array()
	floor_sum.resize(h + 1)
	var plan := w * d
	for y: int in h:
		for z: int in d:
			for x: int in w:
				if _hp[x + z * w + y * plan] > 0.0:
					floor_mass[y] += 1
					floor_sum[y] += Vector2(x + 0.5, z + 0.5)
	for y: int in range(h - 1, -1, -1):
		floor_mass[y] += floor_mass[y + 1]
		floor_sum[y] += floor_sum[y + 1]
	for level: int in range(1, h):
		var mass := floor_mass[level]
		if mass == 0:
			return {}
		var com := floor_sum[level] / mass
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for x: int in w:
			for z: int in d:
				var k := x + z * w + level * plan
				if _hp[k] > 0.0 and _hp[k - plan] > 0.0:
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
