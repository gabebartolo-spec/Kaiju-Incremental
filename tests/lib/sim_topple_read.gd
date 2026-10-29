extends RefCounted
## The sim suite's collapse readability checks (PR #89 motion review of CI capture 39277970463),
## split out to keep the runner small. In the capture's tower take the young reptilian's chew and
## claw swipes ate a 13-floor tower's whole base in one tick, and the 9 floors above dropped half
## a second and vanished: no topple, no crumble. And towers the swipe undermined toppled toward
## the kaiju (D-096, superseded by D-099). Over seeded runs (the tower take at 60 Hz as the capture
## plays it, and scripted rampages with Claws): every gutted tower part (nothing under it, taller
## than deep) topples instead of dropping as one piece, and every topple falls toward its
## cut-away side (D-099).

## The capture's tower take (tools/capture/capture_contact.gd --tower), in 60 Hz steps.
const TAKE_DT := 1.0 / 60.0
const TAKE_STEPS := 720
const TAKE_LEAD_IN := 20
## Scripted rampages with Claws 5, by run index, and their step cap at 30 Hz.
const RUNS := 2
const RUN_DT := 1.0 / 30.0
const RUN_STEPS := 30 * 120

var _check: Callable
var _make: Callable


## check: the runner's check; make(species, levels, run_index, tuning) -> RampageSim.
func _init(p_check: Callable, make: Callable) -> void:
	_check = p_check
	_make = make


func run() -> void:
	var notes: Array[Dictionary] = []
	_tower_take(notes)
	for run: int in RUNS:
		_rampage(run, notes)
	_check_gutted_topple(notes)
	_check_falls_by_physics(notes)
	_check_supports(notes)


## Every fall_start in a run, with the kaiju's position and the part's measures at that tick.
func _note(sim: RampageSim, events: Array[Dictionary], log: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		if str(e["type"]) != "fall_start":
			continue
		var b := sim.buildings[Num.i(e["building"])]
		var cells: Array[Vector3i] = e["cells"]
		var lowest := 9999
		var highest := 0
		for c: Vector3i in cells:
			lowest = mini(lowest, c.y)
			highest = maxi(highest, c.y)
		var base := Vector2.ZERO
		var lo := Vector2i(9999, 9999)
		var hi := Vector2i(-1, -1)
		var under := false
		var count := 0
		var support := ""  # a settle-time support's verdict
		for c: Vector3i in cells:
			if c.y == lowest:
				var p := b.chunk_world(c)
				base += Vector2(p.x, p.z)
				count += 1
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.z))
				hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.z))
				under = under or b.frame.top_below(c.x, c.z, c.y) >= 0
		var size := Vector2i(highest - lowest + 1, mini(hi.x - lo.x, hi.y - lo.y) + 1)
		if e.has("index"):  # a carved part (D-094 WP7): measured on its fine cells instead
			var index: PackedInt32Array = e["index"]
			var fine := _fine(b, sim.carving.frame(Num.i(e["building"])), index)
			size = fine[0]
			under = fine[1]
			if str(e["kind"]) == "drop":
				# Read at settle time (the drop lands on what stood under it then): a later blow
				# in the same step can take that support before this note is made.
				var pivot: Vector3 = e["pivot"]
				under = Num.f(e["drop"]) < pivot.y - 0.01
				if e.get("under", false) == true:  # held at the settle: check the cell itself
					support = _support(sim.carving.frame(Num.i(e["building"])), e, events)
					under = under or support == "ok"
			base = fine[2]
			count = 1
		(
			log
			. append(
				{
					"kind": str(e["kind"]),
					"landmark": b.landmark != "",
					"support": support,
					"cells": cells.size(),
					"height": size.x,
					"span": size.y,
					"under": under,
					"dir": e["dir"],
					"cut_dir": e["cut_dir"],
					"to_part": base / maxi(1, count) - sim.kaiju_pos,
				}
			)
		)


## A carved part (already out of its grid) measured on its fine cells: [Vector2i(height, the
## narrower side of its lowest layer) in cells, true when a cell stands under that layer, the
## world centre (x, z) of that layer].
static func _fine(b: RampageSim.Building, f: VoxelFrame, index: PackedInt32Array) -> Array:
	var plan := f.w * f.d
	var low := f.h
	var top := -1
	for i: int in index:
		low = mini(low, i / plan)
		top = maxi(top, i / plan)
	var lo := Vector2i(f.w, f.d)
	var hi := Vector2i(-1, -1)
	var sum := Vector2.ZERO
	var count := 0
	var under := false
	for i: int in index:
		if i / plan != low:
			continue
		var c := Vector2i(i % f.w, (i / f.w) % f.d)
		lo = lo.min(c)
		hi = hi.max(c)
		sum += Vector2(c) + Vector2(0.5, 0.5)
		count += 1
		under = under or f.column_top(c.x, c.y, low) >= 0
	var mid := sum / maxi(1, count) + Vector2(f.offset.x, f.offset.z)
	var p := b.local_to_world(Vector3(mid.x, 0.0, mid.y) / f.res)
	var size := Vector2i(top - low + 1, mini(hi.x - lo.x, hi.y - lo.y) + 1)
	return [size, under, Vector2(p.x, p.z)]


## The capture's tower take: south of the nearest tall tier-2 tower, chewing north into it.
func _tower_take(log: Array[Dictionary]) -> void:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	var best := -1
	var best_d := INF
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.tier == 2 and b.landmark == "" and b.height >= 10 and mini(b.w, b.d) >= 4:
			var d := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
			if d < best_d:
				best = i
				best_d = d
	var t := sim.buildings[best]
	sim.kaiju_pos = Vector2(t.x, t.z + t.d * 0.5 + sim.body.length() * 0.6)
	sim.facing = Vector2(0, -1)
	sim.body.heading = sim.facing
	for n: int in TAKE_STEPS:
		var move := sim.facing if n >= TAKE_LEAD_IN else Vector2.ZERO
		_note(sim, sim.step(TAKE_DT, move, false), log)


## A scripted rampage with Claws 5 (the runner's autoplay: walk to the nearest standing chunk).
func _rampage(run: int, log: Array[Dictionary]) -> void:
	var sim: RampageSim = _make.call("reptilian", {"claws": 5}, run, {})
	var target := Vector2(INF, INF)
	for n: int in RUN_STEPS:
		if sim.over:
			return
		if n % 15 == 0:
			target = sim.nearest_standing(sim.kaiju_pos)
		var move := Vector2.ZERO
		if target.x < INF and not sim.body.stomp_reaches(target):
			move = (target - sim.kaiju_pos).normalized()
		_note(sim, sim.step(RUN_DT, move, sim.ability_ready_in <= 0.0), log)


## A part with nothing under it that is taller than it is deep is a tower whose base is gone:
## it topples, it never drops and vanishes as one block.
func _check_gutted_topple(log: Array[Dictionary]) -> void:
	var dropped: Array[String] = []
	var toppled := 0
	for f: Dictionary in log:
		var gutted: bool = f["under"] != true and Num.i(f["height"]) > Num.i(f["span"])
		if f["landmark"] == true or not gutted:
			continue
		if str(f["kind"]) == "drop":
			dropped.append("%d cells %d high %d deep" % [f["cells"], f["height"], f["span"]])
		else:
			toppled += 1
	_check.call(
		dropped.is_empty() and toppled > 0,
		(
			"every gutted tower part topples (%d) instead of dropping as one block: %s"
			% [toppled, dropped]
		)
	)


## D-099 (director 2026-10-20, "towers fall by real physics, toward the cut-away side, even onto
## the kaiju") with b2-5 (D-387): every topple falls along one of the four level directions,
## its cut side (cut_dir; a gutted drop's is toward the kaiju whose chew cut it), either side
## of that, or away; the seeded mix sends some off their cut side. And seeded topples fall onto
## the kaiju as well as away from it.
func _check_falls_by_physics(log: Array[Dictionary]) -> void:
	var wrong: Array[String] = []
	var count := 0
	var onto := 0
	var away := 0
	var off_cut := 0
	for f: Dictionary in log:
		if str(f["kind"]) != "topple":
			continue
		count += 1
		var dir: Vector2 = f["dir"]
		var cut: Vector2 = f["cut_dir"]
		var to_part: Vector2 = f["to_part"]
		if cut == Vector2.ZERO:  # gutted: its cut side faces the kaiju
			cut = (
				Vector2(-signf(to_part.x), 0.0)
				if absf(to_part.x) > absf(to_part.y)
				else Vector2(0.0, -signf(to_part.y))
			)
		if absf(dir.x) + absf(dir.y) != 1.0 or absf(dir.x * dir.y) != 0.0:
			wrong.append("dir %s cut %s kaiju->part %s" % [dir, cut, to_part.round()])
		off_cut += 1 if dir != cut else 0
		if dir.dot(to_part) < 0.0:
			onto += 1
		else:
			away += 1
	_check.call(
		wrong.is_empty() and count > 0,
		"all %d topples fall along a level direction; not: %s" % [count, wrong]
	)
	_check.call(
		off_cut > 0 or count < 4,
		"b2-5: some of %d seeded topples fall off their cut side (%d)" % [count, off_cut]
	)
	_check.call(
		onto > 0 and away > 0,
		"seeded topples fall onto the kaiju (%d) as well as away from it (%d)" % [onto, away]
	)


## A carved part the sim found held at its settle (fall_start "under") names the cell that held
## it ("support"): it must sit in a column of the part's lowest layer, below that layer, and be
## solid that step (still in the grid, or carved or fallen in the same step's events). "ok", or
## what is wrong with it.
static func _support(f: VoxelFrame, e: Dictionary, events: Array[Dictionary]) -> String:
	var s := Num.i(e.get("support", -1))
	if s < 0:
		return "no support cell"
	var plan := f.w * f.d
	var index: PackedInt32Array = e["index"]
	var low := f.h
	for i: int in index:
		low = mini(low, i / plan)
	var column := false
	for i: int in index:
		column = column or (i / plan == low and i % plan == s % plan)
	if not column or s / plan >= low:
		return "cell %d not under the part's lowest layer" % s
	if f.cells[s] != VoxelFrame.EMPTY:
		return "ok"
	for other: Dictionary in events:
		var kind := str(other["type"])
		if (kind != "cells_carved" and kind != "fall_start") or other == e:
			continue
		if Num.i(other["building"]) == Num.i(e["building"]) and other.has("index"):
			var gone: PackedInt32Array = other["index"]
			if gone.has(s):
				return "ok"
	return "cell %d was not solid that step" % s


## Every settle-time support a carved part names checks out (_support).
func _check_supports(log: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var held := 0
	for f: Dictionary in log:
		var verdict := str(f["support"])
		if verdict == "ok":
			held += 1
		elif verdict != "":
			bad.append(verdict)
	print("  carved parts held at their settle: %d checked, %d wrong" % [held, bad.size()])
	_check.call(bad.is_empty(), "every settle-time support sits under its part: %s" % [bad])
