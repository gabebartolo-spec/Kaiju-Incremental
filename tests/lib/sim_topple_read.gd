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
		for c: Vector3i in cells:
			if c.y == lowest:
				var p := b.chunk_world(c)
				base += Vector2(p.x, p.z)
				count += 1
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.z))
				hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.z))
				under = under or b.frame.top_below(c.x, c.z, c.y) >= 0
		(
			log
			. append(
				{
					"kind": str(e["kind"]),
					"landmark": b.landmark != "",
					"cells": cells.size(),
					"height": highest - lowest + 1,
					"span": mini(hi.x - lo.x, hi.y - lo.y) + 1,
					"under": under,
					"dir": e["dir"],
					"cut_dir": e["cut_dir"],
					"to_part": base / maxi(1, count) - sim.kaiju_pos,
				}
			)
		)


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
		if target.x < INF and sim.kaiju_pos.distance_to(target) > sim.stomp_radius() * 0.5:
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
## the kaiju"): every topple goes the way the support rule says (its cut_dir); a gutted drop, which
## has no rule direction, goes toward the kaiju whose chew cut it. And at least one seeded topple
## has its cut side facing the kaiju and falls toward it.
func _check_falls_by_physics(log: Array[Dictionary]) -> void:
	var wrong: Array[String] = []
	var count := 0
	var onto := 0
	var away := 0
	for f: Dictionary in log:
		if str(f["kind"]) != "topple":
			continue
		count += 1
		var dir: Vector2 = f["dir"]
		var cut: Vector2 = f["cut_dir"]
		var to_part: Vector2 = f["to_part"]
		if (cut != Vector2.ZERO and dir != cut) or (cut == Vector2.ZERO and dir.dot(to_part) >= 0.0):
			wrong.append("dir %s cut %s kaiju->part %s" % [dir, cut, to_part.round()])
		if dir.dot(to_part) < 0.0:
			onto += 1
		else:
			away += 1
	_check.call(
		wrong.is_empty() and count > 0,
		"all %d topples fall toward their cut side; not: %s" % [count, wrong]
	)
	_check.call(
		onto > 0 and away > 0,
		"seeded topples fall onto the kaiju (%d) as well as away from it (%d)" % [onto, away]
	)
