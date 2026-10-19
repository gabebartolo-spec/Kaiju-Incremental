extends RefCounted
## CAPTURE ONLY, NOT SHIPPED: a stand-in for WP1's VoxelFrame so WP5's physics view can be driven
## before the sim grid lands (copied from the destruction spike's spike/carve_grid.gd, branch
## claude/destruction-proto). One hollow office block as a fine grid (one byte per cell, 0 empty,
## x fastest then z then y, RES cells per unit), carved by spheres; settle() returns events in
## Structure.settle()'s shape: islands as "drop", then Structure's topple rule on cell layers
## ({cells, kind, pivot (grid cells), dir: Vector2i} + "mats"). Swap for VoxelFrame when WP1 pushes.
@warning_ignore_start("integer_division")

const EMPTY := 0
const WALL := 1
const SLAB := 2
const GLASS := 3
const COLUMN := 4

var site: CarveSite
var cells := PackedByteArray()
var w: int
var d: int
var h: int


## The spike's office block: a slab per floor, shell walls with window bands, columns inside.
func _init(p_site: CarveSite) -> void:
	site = p_site
	w = site.size.x
	h = site.size.y
	d = site.size.z
	var res := site.res
	cells.resize(w * d * h)
	for y: int in h:
		for z: int in d:
			for x: int in w:
				var edge := x == 0 or z == 0 or x == w - 1 or z == d - 1
				var m := EMPTY
				if y % res == 0:
					m = SLAB
				elif edge:
					var bay := (x + z) % res
					m = GLASS if (y % res >= 2 and bay != 0 and y >= res) else WALL
				elif x % (2 * res) == res and z % (2 * res) == res:
					m = COLUMN
				cells[x + z * w + y * w * d] = m


## Removes every cell in the sphere: {"cells": indices (scan order), "mats": their materials}.
func carve(centre: Vector3, radius: float) -> Dictionary:
	var removed := PackedInt32Array()
	var mats := PackedByteArray()
	var res := site.res
	var c := (centre - site.origin) * res
	var r := radius * res
	var lo := (c - Vector3.ONE * r).floor()
	var hi := (c + Vector3.ONE * r).ceil()
	for y: int in range(maxi(0, int(lo.y)), mini(h, int(hi.y) + 1)):
		for z: int in range(maxi(0, int(lo.z)), mini(d, int(hi.z) + 1)):
			for x: int in range(maxi(0, int(lo.x)), mini(w, int(hi.x) + 1)):
				var i := x + z * w + y * w * d
				if cells[i] == EMPTY:
					continue
				if Vector3(x + 0.5, y + 0.5, z + 0.5).distance_squared_to(c) <= r * r:
					mats.append(cells[i])
					cells[i] = EMPTY
					removed.append(i)
	return {"cells": removed, "mats": mats}


## Every part that lost support, removed from the grid.
func settle() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := _grounded()
	for start: int in cells.size():
		if cells[start] != EMPTY and seen[start] == 0:
			out.append(_take(_island(start, seen), "drop", Vector3.ZERO, Vector2i.ZERO))
	var tip := _topple()
	if not tip.is_empty():
		out.append(tip)
	return out


func _take(part: PackedInt32Array, kind: String, pivot: Vector3, dir: Vector2i) -> Dictionary:
	var mats := PackedByteArray()
	mats.resize(part.size())
	for k: int in part.size():
		mats[k] = cells[part[k]]
		cells[part[k]] = EMPTY
	return {"cells": part, "kind": kind, "pivot": pivot, "dir": dir, "mats": mats}


func _grounded() -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(cells.size())
	var frontier := PackedInt32Array()
	frontier.resize(cells.size())
	var top := 0
	for i: int in w * d:
		if cells[i] != EMPTY:
			seen[i] = 1
			frontier[top] = i
			top += 1
	while top > 0:
		top -= 1
		top = _spread(frontier[top], seen, frontier, top)
	return seen


func _island(start: int, seen: PackedByteArray) -> PackedInt32Array:
	var part := PackedInt32Array()
	part.resize(cells.size())
	part[0] = start
	seen[start] = 1
	var n := 1
	var k := 0
	while k < n:
		n = _spread(part[k], seen, part, n)
		k += 1
	part.resize(n)
	return part


## Marks cell i's solid, unseen neighbours and writes them to `out` from `top`; the new top.
func _spread(i: int, seen: PackedByteArray, out: PackedInt32Array, top: int) -> int:
	var plan := w * d
	var x := i % w
	var z := (i / w) % d
	var y := i / plan
	if x > 0 and seen[i - 1] == 0 and cells[i - 1] != EMPTY:
		seen[i - 1] = 1
		out[top] = i - 1
		top += 1
	if x < w - 1 and seen[i + 1] == 0 and cells[i + 1] != EMPTY:
		seen[i + 1] = 1
		out[top] = i + 1
		top += 1
	if z > 0 and seen[i - w] == 0 and cells[i - w] != EMPTY:
		seen[i - w] = 1
		out[top] = i - w
		top += 1
	if z < d - 1 and seen[i + w] == 0 and cells[i + w] != EMPTY:
		seen[i + w] = 1
		out[top] = i + w
		top += 1
	if y > 0 and seen[i - plan] == 0 and cells[i - plan] != EMPTY:
		seen[i - plan] = 1
		out[top] = i - plan
		top += 1
	if y < h - 1 and seen[i + plan] == 0 and cells[i + plan] != EMPTY:
		seen[i + plan] = 1
		out[top] = i + plan
		top += 1
	return top


## Structure._topple_check on cell layers: the lowest layer whose load has its centre of mass
## outside the cells holding it up from the layer below topples over that edge.
func _topple() -> Dictionary:
	var plan := w * d
	var mass := PackedInt32Array()
	mass.resize(h + 1)
	var sum := PackedVector2Array()
	sum.resize(h + 1)
	for y: int in h:
		for z: int in d:
			for x: int in w:
				if cells[x + z * w + y * plan] != EMPTY:
					mass[y] += 1
					sum[y] += Vector2(x + 0.5, z + 0.5)
	for y: int in range(h - 1, -1, -1):
		mass[y] += mass[y + 1]
		sum[y] += sum[y + 1]
	for level: int in range(1, h):
		if mass[level] == 0:
			return {}
		var com := sum[level] / mass[level]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for z: int in d:
			for x: int in w:
				var k := x + z * w + level * plan
				if cells[k] != EMPTY and cells[k - plan] != EMPTY:
					lo = lo.min(Vector2(x, z))
					hi = hi.max(Vector2(x + 1, z + 1))
		if lo.x == INF:
			continue
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
		var part := PackedInt32Array()
		for i: int in range(level * plan, cells.size()):
			if cells[i] != EMPTY:
				part.append(i)
		return _take(part, "topple", pivot, dir)
	return {}
