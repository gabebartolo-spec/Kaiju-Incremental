class_name CarvingCells
extends RefCounted
## Carving's per-cell loops (b2-3 part 3), split out to keep carving.gd small: a blow's wear, a
## new grid's chunk counts, a fallen part's bookkeeping and its drop. Each runs natively
## (KaijuSettle, native/src/kaiju_settle_parts.cpp) where the extension is loaded; the GDScript
## here stays the reference it is held to (run_carving_tests _check_replay, use_native).


## A blow's wear on grid g: per chunk in `spans` [x0, x1, z0, z1, floor] (grid columns), each
## column worn (Carving.wear_column) by damage x at[col] x mult where at[col] > 0 or, when `at`
## is empty, by amounts[chunk] x mult; what breaks goes into g.removed and g.mats.
static func wear(
	carving: Carving,
	g: Carving.Grid,
	spans: PackedInt32Array,
	at: PackedFloat32Array,
	amounts: PackedFloat32Array,
	damage: float,
	mult: float
) -> void:
	var f := g.frame
	var nat := VoxelSupport.native()
	var even := at.is_empty()
	if nat == null:
		for s: int in range(0, spans.size(), 5):
			for gz: int in range(spans[s + 2], spans[s + 3]):
				for gx: int in range(spans[s], spans[s + 1]):
					var col := gx + gz * f.w
					if even:
						carving.wear_column(g, col, spans[s + 4], amounts[s / 5] * mult)
					elif at[col] > 0.0:
						carving.wear_column(g, col, spans[s + 4], damage * at[col] * mult)
		return
	var got: Array = nat.call(
		"wear",
		f.cells,
		g.wear,
		at,
		amounts,
		spans,
		carving.strengths(),
		PackedFloat64Array([damage, mult, g.hp, carving.weakest()]),
		PackedInt32Array([f.w, f.d, f.h, g.bw, g.bd, g.floors, f.offset.y, f.res]),
		g.cx,
		g.cz,
		g.fy,
		g.live
	)
	f.cells = got[0]
	g.wear = got[1]
	g.live = got[2]
	var removed: PackedInt32Array = got[3]
	var mats: PackedByteArray = got[4]
	f.alive_count -= removed.size()
	g.removed.append_array(removed)
	g.mats.append_array(mats)


## Per chunk (Structure.index), the cells of g's grid in it.
static func counts(g: Carving.Grid, chunks: int) -> PackedInt32Array:
	var f := g.frame
	var nat := VoxelSupport.native()
	if nat != null:
		return nat.call("chunk_counts", f.cells, g.cx, g.cz, g.fy, _geo(g), chunks)
	var full := PackedInt32Array()
	full.resize(chunks)
	var bytes := f.cells
	for i: int in bytes.size():
		if bytes[i] != VoxelFrame.EMPTY:
			full[g.chunk(i)] += 1
	return full


## A part that fell out of g's grid: one cell less in each chunk it held (g.live), and
## [lo, hi (grid cells, Vector3i), base (Rect2i, the footprint of its lowest layer), under (true
## when a cell stands below that layer)].
static func fallen(g: Carving.Grid, index: PackedInt32Array) -> Array:
	var f := g.frame
	var nat := VoxelSupport.native()
	if nat != null:
		var got: Array = nat.call("part_info", index, f.cells, g.cx, g.cz, g.fy, _geo(g), g.live)
		g.live = got[0]
		var r: PackedInt32Array = got[1]
		return [
			Vector3i(r[0], r[1], r[2]),
			Vector3i(r[3], r[4], r[5]),
			Rect2i(r[6], r[7], r[8] - r[6], r[9] - r[7]),
			r[10] == 1
		]
	var plan := f.w * f.d
	var lo := Vector3i(f.w, f.h, f.d)
	var hi := -Vector3i.ONE
	for i: int in index:
		g.live[g.chunk(i)] -= 1
		var c := Vector3i(i % f.w, i / plan, (i / f.w) % f.d)
		lo = lo.min(c)
		hi = hi.max(c)
	var base := Rect2i(-1, -1, 0, 0)
	var under := false
	for i: int in index:
		if i / plan == lo.y:
			var x := i % f.w
			var z := (i / f.w) % f.d
			var cell := Rect2i(x, z, 1, 1)
			base = cell if base.position.x < 0 else base.merge(cell)
			under = under or f.column_top(x, z, lo.y) >= 0
	return [lo, hi, base, under]


## How far an island (already out of the grid) drops before it meets what stands below it,
## in sim units.
static func drop(f: VoxelFrame, index: PackedInt32Array) -> float:
	var nat := VoxelSupport.native()
	if nat != null:
		var r: PackedInt64Array = nat.call("land", index, f.cells, Vector3i(f.w, f.h, f.d))
		return maxf(0.5, float(r[8]) / f.res)
	var plan := f.w * f.d
	var low: Dictionary = {}
	for i: int in index:
		var col := i % plan
		var y := i / plan
		if not low.has(col) or y < Num.i(low[col]):
			low[col] = y
	var gap := f.h
	for col: int in low:
		var y: int = low[col]
		gap = mini(gap, y - f.column_top(col % f.w, col / f.w, y) - 1)
	return maxf(0.5, float(gap) / f.res)


static func _geo(g: Carving.Grid) -> PackedInt32Array:
	return PackedInt32Array([g.frame.w, g.frame.d, g.frame.h, g.bw, g.bd])


## One settled part in Collapse's part shape (Carving.settle): `info` is fallen()'s answer for it
## and `deaths` the chunks it took with it.
static func part_event(
	f: VoxelFrame, part: Dictionary, info: Array, deaths: Array[Vector3i]
) -> Dictionary:
	var index: PackedInt32Array = part["index"]
	var lo: Vector3i = info[0]
	var hi: Vector3i = info[1]
	var base: Rect2i = info[2]
	var under: bool = info[3]
	var dir: Vector2i = part["dir"]
	var span := hi - lo + Vector3i.ONE
	var event := {
		"cells": deaths,
		"kind": part["kind"],
		"pivot": part["pivot"],
		"dir": dir,
		"index": index,
		"mats": part["mats"],
		"low": float(lo.y) / f.res,
		"height": ceilf(float(span.y) / f.res),
		"width": float(span.z if dir.x != 0 else span.x) / f.res,
	}
	event["base"] = Rect2(
		Vector2(base.position + Vector2i(f.offset.x, f.offset.z)) / f.res,
		Vector2(base.size) / f.res
	)
	event["gutted"] = not under and span.y > mini(base.size.x, base.size.y)
	if str(part["kind"]) != "topple":
		event["drop"] = drop(f, index)
	return event
