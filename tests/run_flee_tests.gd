extends "res://tests/lib/runner.gd"
## Flee suite: a civilian running from the kaiju never steps closer to it (director 2026-11-03:
## "civilians sometimes flee toward the kaiju; they must never do that"). Civilians are placed
## fleeing on pavements all round the kaiju, and on the pavements into dead ends with the kaiju
## at the open end, then walked frame by frame with the GDScript loop and (when built) the native
## one. Seeded by design: Seeds "city", "army" and "civilians" 0, fixed kaiju spots, a fixed step.
##   godot --headless --path . --script tests/run_flee_tests.gd

const Replay := preload("res://tests/lib/street_replay.gd")
const FRAMES := 240  # four seconds: past several corners at a run
const WARY_OVER_CALM := 1.9  # the band past calm_radius checked: within wary_radius
const CALM_FRAMES := 1200  # twenty seconds: out past calm_radius and a few corners on
const EPS := 0.001  # m: float rounding of a step


func suite_name() -> String:
	return "Flee"


func run_checks() -> void:
	await _t("_check_flee_round_kaiju")
	await _t("_check_flee_dead_ends")
	await _t("_check_flee_moving_kaiju")
	await _t("_check_calmed_keep_away")


## Civilians on every pavement within 20 m of three kaiju spots, all fleeing: none ever gets
## closer to the still kaiju, by either walk.
func _check_flee_round_kaiju() -> void:
	for native: bool in _walks():
		var run := Replay.new(self, 1, "high", native)
		run.step_everyone()
		var worst := 0.0
		var placed := 0
		for spot: int in 3:
			var k := _corner_at(run, spot)
			run.sim.kaiju_pos = k
			placed += _place_round(run, k)
			worst = maxf(worst, _walk_still(run, k))
		check(placed > 50, "%d civilians placed fleeing (native %s)" % [placed, native])
		check(worst <= EPS, "none got closer (worst %.4f m, native %s)" % [worst, native])
		run.finish()


## Civilians on the pavement into a dead end, the kaiju just past its open end: none may turn at
## the dead end and run back toward the kaiju.
func _check_flee_dead_ends() -> void:
	for native: bool in _walks():
		var run := Replay.new(self, 1, "high", native)
		run.step_everyone()
		var pav: Pavements = run.street._pavements
		var ends := PackedInt32Array()
		for n: int in pav.nodes.size():
			if pav.links[n].size() == 1:
				ends.append(n)
		check(ends.size() > 0, "the city has dead-end pavements (%d)" % ends.size())
		var worst := 0.0
		var placed := 0
		for e: int in ends.slice(0, 8):
			var m: int = pav.links[e][0]
			var a := pav.nodes[m]
			var b := pav.nodes[e]
			var k := a + (a - b).normalized() * 3.0
			run.sim.kaiju_pos = k
			for i: int in run.street.pos.size():
				if run.street.cop[i] == 1 or i % 4 != 0:
					continue
				run.street.pos[i] = a.lerp(b, float(i % 10) / 10.0)
				var inward := i % 8 == 0  # half head into the dead end, half toward the kaiju
				run.street.from_node[i] = m if inward else e
				run.street.to_node[i] = e if inward else m
				placed += 1
			_panic_all(run)
			worst = maxf(worst, _walk_still(run, k))
		check(placed > 0, "%d civilians placed between kaiju and dead end" % placed)
		check(worst <= EPS, "none ran back toward it (worst %.4f m, native %s)" % [worst, native])
		run.finish()


## The kaiju walks its line through the city (stomps and braces included): every fleeing
## civilian's step leads away from where the kaiju stands that frame.
func _check_flee_moving_kaiju() -> void:
	for native: bool in _walks():
		var run := Replay.new(self, 1, "high", native)
		run.step_everyone()
		var worst := 0.0
		var steps := 0
		for f: int in 900:
			var before: PackedVector2Array = run.street.pos.duplicate()
			var was: PackedByteArray = run.street.fleeing.duplicate()
			run.step()
			var k := run.sim.kaiju_pos
			if run.street.pos.size() != before.size():
				continue  # someone left: the indices moved
			for i: int in before.size():
				if was[i] == 1 and run.street.fleeing[i] == 1 and run.street.cop[i] == 0:
					var moved := run.street.pos[i] - before[i]
					if moved.length() > 0.0:
						steps += 1
						worst = maxf(worst, -moved.dot((before[i] - k).normalized()))
		check(steps > 1000, "fleeing steps measured: %d (native %s)" % [steps, native])
		check(worst <= EPS, "no step led toward it (worst %.4f m, native %s)" % [worst, native])
		run.finish()


## Civilians that fled a still kaiju and calmed past calm_radius never walk back toward it while
## within wary_radius (D-453: they used to turn at the next corner and come back to re-panic).
func _check_calmed_keep_away() -> void:
	for native: bool in _walks():
		var run := Replay.new(self, 1, "high", native)
		run.step_everyone()
		var k := _corner_at(run, 1)
		run.sim.kaiju_pos = k
		var placed := _place_round(run, k)
		var st := run.street
		var calm := StreetSteps.panic_radius(st) * st.tune("calm_radius") / st.tune("panic_radius")
		var wary := calm * WARY_OVER_CALM  # inside wary_radius (64 m over 32 for an adult)
		var worst := 0.0
		var calmed := 0
		for f: int in CALM_FRAMES:
			var before: PackedVector2Array = run.street.pos.duplicate()
			var was: PackedByteArray = run.street.fleeing.duplicate()
			run.sim.kaiju_pos = k
			run.street._process(Replay.DT)
			if run.street.pos.size() != before.size():
				continue
			for i: int in before.size():
				if run.street.cop[i] == 1 or before[i].distance_to(k) > wary:
					continue
				if was[i] == 1 and run.street.fleeing[i] == 0:
					calmed += 1
				var closer := before[i].distance_to(k) - run.street.pos[i].distance_to(k)
				worst = maxf(worst, closer)
		check(
			placed > 50 and calmed > 20,
			"%d placed, %d calmed (native %s)" % [placed, calmed, native]
		)
		check(worst <= EPS, "none came back (worst %.4f m, native %s)" % [worst, native])
		run.finish()


## The walks to check: the GDScript loop, and the native one when the extension is built.
func _walks() -> Array[bool]:
	var out: Array[bool] = [false]
	if StreetWalk.available():
		out.append(true)
	return out


## A linked corner of the city, the spot-th of three spread through it.
func _corner_at(run: Replay, spot: int) -> Vector2:
	var pav: Pavements = run.street._pavements
	var linked := PackedInt32Array()
	for n: int in pav.nodes.size():
		if not pav.links[n].is_empty():
			linked.append(n)
	return pav.nodes[linked[linked.size() * (spot + 1) / 4]]


## Every civilian goes onto a pavement starting within 20 m of k, part way along, either way.
func _place_round(run: Replay, k: Vector2) -> int:
	var pav: Pavements = run.street._pavements
	var segs: Array[Vector2i] = []
	for a: int in pav.nodes.size():
		for b: int in pav.links[a]:
			if pav.nodes[a].distance_to(k) < 20.0:
				segs.append(Vector2i(a, b))
	if segs.is_empty():
		return 0
	var placed := 0
	for i: int in run.street.pos.size():
		if run.street.cop[i] == 1:
			continue
		var s := segs[i % segs.size()]
		run.street.pos[i] = pav.nodes[s.x].lerp(pav.nodes[s.y], float((i * 7) % 10) / 10.0)
		run.street.from_node[i] = s.x
		run.street.to_node[i] = s.y
		placed += 1
	_panic_all(run)
	return placed


## Everyone not an officer runs now: fleeing, no gawk.
func _panic_all(run: Replay) -> void:
	for i: int in run.street.pos.size():
		if run.street.cop[i] == 0:
			run.street.fleeing[i] = 1
			run.street.pinned_until[i] = 0.0


## FRAMES of the street with the kaiju still at k: the most any fleeing civilian got closer to it
## in one frame (m; 0 when none did).
func _walk_still(run: Replay, k: Vector2) -> float:
	var worst := 0.0
	for f: int in FRAMES:
		var before: PackedVector2Array = run.street.pos.duplicate()
		var was: PackedByteArray = run.street.fleeing.duplicate()
		run.sim.kaiju_pos = k
		run.street._process(Replay.DT)
		if run.street.pos.size() != before.size():
			continue
		for i: int in before.size():
			if was[i] == 1 and run.street.fleeing[i] == 1 and run.street.cop[i] == 0:
				var closer := before[i].distance_to(k) - run.street.pos[i].distance_to(k)
				worst = maxf(worst, closer)
	return worst
