extends "res://tests/lib/momentum_base.gd"
## The titan's run (Momentum, D-337, director 2026-10-27: "running wont have a sprint button, it
## should be momentum based, at high momentum he can crash right through smaller buildings, and
## collide with a bang into bigger ones"), the croc's entry (powers.momentum.titans.croc): always
## on; at crash_min he crashes through what stands under his shoulder without slowing or spending
## it; at slam_min his first touch of anything at or over it is one slam (a dent, momentum 0, the
## body stopped); below the thresholds nothing changes (D-280); the croc's bars are the consts.
## Player-effect fixture "croc.momentum": the same seeded charge with the run on and off. Seeded:
## every sim is Seeds.make("army", 0) (leap_base._croc) on a hand-made layout; the claws are idle.

## The croc's bars (lead 2026-10-27): full from a standstill, a turn's keep, its rate (D-328).
const FULL_BY_S := 1.5
const TURN_S := 2.0
const TURN_KEEPS := 0.7
## "Unchanged": the snapped turn made within one step of the same time with and without momentum.
const SAME_TURN_S := 1.0 / 60.0
const MAX_S := 5.0
## Spent after a slam: seconds pushed on into a building DEEP x WIDE cells (he is still in it).
const PUSH_S := 3.0
const DEEP := 16
const WIDE := 8


func suite_name() -> String:
	return "Momentum"


func run_checks() -> void:
	await _t("_check_entries")
	await _t("_check_crash_through")
	await _t("_check_slam")
	await _t("_check_spent_by_buildings")
	await _t("_check_below_threshold")
	await _t("_check_relative_to_size")
	await _t("_check_build_and_turn")
	await _t("_check_turn_rate")
	await _t("_check_replay")
	await _t("_check_old_save")


## The reptilian plays the croc's entry; a species with no titan entry builds no momentum; a
## titan whose crash height is its body's (the serpent's shape) crashes under its discs' top.
func _check_entries() -> void:
	var titans: Dictionary = Content.tuning()["powers"]["momentum"]["titans"]
	var croc := _croc({}, [])
	var entry: Dictionary = titans["croc"]
	check(croc.powers.run.titan == entry, "the reptilian plays the croc's momentum entry")
	var bug := croc.powers.run
	bug.use_species("insectoid")
	check(not bug.active(), "a species with no titan entry has no momentum")
	var serpent := entry.duplicate()
	serpent["crash_height"] = "body"
	croc.powers.run.titan = serpent
	var top := 0.0
	for d: Array in croc.body.discs():
		top = maxf(top, Num.f(d[3]))
	check(
		is_equal_approx(croc.powers.run.crash_height(), top * croc.body_scale()),
		"a 'body' crash height is the body's top (%.2f)" % croc.powers.run.crash_height()
	)


## (a) A straight charge down a street of short buildings: he passes through every one (each
## carved along his path) as fast as down the open street, momentum at or over crash_min, no
## slam. croc.momentum: without the run the same street takes him less far.
func _check_crash_through() -> void:
	var titan := _titan()
	var row := _row()
	var open := _charge(_runner({}, []), 0)
	var on := _charge(_runner({}, row), ROW)
	var off := _charge(_runner({}, row, false), ROW)
	var lost: Array[int] = on["lost"]
	var last_face := Num.f(row[ROW - 1]["z"]) - WIDTH * 0.5
	var least: int = lost.min()
	var snout := Num.f(on["z"]) - _snout({})
	check(
		least > 0 and snout < last_face,
		(
			"(a) he passes through the row, each building carved: %s (snout z %.1f, last face z %.1f)"
			% [on, snout, last_face]
		)
	)
	var free := 30.0 - Num.f(open["z"])
	var made := 30.0 - Num.f(on["z"])
	check(
		made >= free * 0.999,
		"(a) the row does not slow him: %.2f units vs %.2f down the open street" % [made, free]
	)
	check(
		Num.f(on["low"]) >= Num.f(titan["crash_min"]) and Num.i(on["slams"]) == 0,
		(
			"(a) momentum stays at or over crash_min %.2f (least %.2f), no slam (%d)"
			% [Num.f(titan["crash_min"]), Num.f(on["low"]), Num.i(on["slams"])]
		)
	)
	check(
		30.0 - Num.f(off["z"]) < made,
		(
			"croc.momentum: the run takes him further down the row (%.1f vs %.1f off)"
			% [made, 30.0 - Num.f(off["z"])]
		)
	)


## (b) A charge into a building over his shoulder: one slam at his momentum's strength, a dent,
## momentum 0 and the body stopped where it was. croc.momentum: without the run, no slam.
func _check_slam() -> void:
	var titan := _titan()
	var tall: Array[Dictionary] = [_block(Vector2(0.0, _ahead_of_snout({}, LEAD)), WIDTH, TALL)]
	var sim := _runner({}, tall)
	var slams: Array[Dictionary] = []
	var hit := {"moved": -1.0, "dent": 0, "after": -1.0}
	for _n: int in roundi(CHARGE_S / DT):
		var was := sim.kaiju_pos
		var alive := sim.buildings[0].frame.alive_count
		var had := slams.size()
		for event: Dictionary in sim.step(DT, NORTH, false, 0):
			if str(event["type"]) == "slam":
				slams.append(event)
		if had == 0 and not slams.is_empty():
			hit["moved"] = was.distance_to(sim.kaiju_pos)
			hit["dent"] = alive - sim.buildings[0].frame.alive_count
			hit["after"] = sim.powers.momentum
	check(slams.size() == 1, "(b) one slam into the tall building (%d)" % slams.size())
	var first: Dictionary = slams[0] if not slams.is_empty() else {}
	check(
		(
			Num.i(first.get("building", -1)) == 0
			and Num.f(first.get("strength", 0.0)) >= Num.f(titan["slam_min"]) * Num.f(titan["hit"])
		),
		"(b) the slam is on the tall building at its momentum's strength: %s" % [first]
	)
	check(
		Num.i(hit["dent"]) > 0, "(b) the slam dents the building (%d chunks)" % Num.i(hit["dent"])
	)
	check(
		Num.f(hit["after"]) == 0.0 and Num.f(hit["moved"]) == 0.0,
		"(b) momentum spent and he stops: %s" % [hit]
	)
	var off := _charge(_runner({}, tall, false), 1)
	check(Num.i(off["slams"]) == 0, "croc.momentum: without the run, no slam (%s)" % [off])


## Slam and stop, momentum spent (lead 2026-10-27 on D-337): it never builds while his body touches
## a building he is not crashing through. Charged into a deep tall building and pushed on into it
## PUSH_S, he slams once, not again as he breaks on through it; pushing from a standstill against a
## short building that dwarfs him builds none, and it holds him as it does with no run.
func _check_spent_by_buildings() -> void:
	var titan := _titan()
	var deep := _tiered(Vector2(0.0, 30.0 - _snout({}) - LEAD - DEEP * 0.5), WIDE, TALL, 1)
	deep["d"] = DEEP
	var sim := _runner({}, [deep])
	var out := {"slams": 0, "pushed": 0, "top": 0.0}
	for _n: int in roundi((CHARGE_S + PUSH_S) / DT):
		out["slams"] = Num.i(out["slams"]) + _count(sim.step(DT, NORTH, false, 0), "slam")
		if Num.i(out["slams"]) > 0:
			out["pushed"] = Num.i(out["pushed"]) + 1
			out["top"] = maxf(Num.f(out["top"]), sim.powers.momentum)
		if Num.i(out["pushed"]) >= roundi(PUSH_S / DT):
			break
	out["broken"] = sim.body.broken
	check(
		(
			Num.i(out["slams"]) == 1
			and Num.i(out["pushed"]) >= roundi(PUSH_S / DT)
			and Num.f(out["top"]) < Num.f(titan["slam_min"])
		),
		(
			"pushed on into the tall building %.0f s after the slam: one slam, momentum spent: %s"
			% [PUSH_S, out]
		)
	)
	var short: Array[Dictionary] = [
		_tiered(Vector2(0.0, _ahead_of_snout({}, -0.25)), WIDTH, SHORT, DWARFS)
	]
	var pushed := _runner({}, short)
	var ref := _runner({}, short, false)
	var held := {"same": true, "top": 0.0}
	for _n: int in roundi(PUSH_S / DT):
		pushed.step(DT, NORTH, false, 0)
		ref.step(DT, NORTH, false, 0)
		var same := (
			pushed.kaiju_pos == ref.kaiju_pos and pushed.chunks_destroyed == ref.chunks_destroyed
		)
		held["same"] = held["same"] == true and same
		held["top"] = maxf(Num.f(held["top"]), pushed.powers.momentum)
	var as_off: bool = held["same"]
	check(
		as_off and Num.f(held["top"]) < Num.f(titan["crash_min"]),
		(
			"pushing %.0f s against a building that holds him builds no run (held as with none): %s"
			% [PUSH_S, held]
		)
	)


## (c) Below crash_min and slam_min nothing changes (D-280): from a standstill into a short and a
## tall building just ahead, the walk goes step for step as it does with no run at all; no slam,
## the body breaks into it, and he is never stopped. A short building of a tier that dwarfs him
## holds him as it does with no run (he chews it).
func _check_below_threshold() -> void:
	var titan := _titan()
	var under := minf(Num.f(titan["crash_min"]), Num.f(titan["slam_min"]))
	var build := DT / Num.f(titan["build_seconds"])
	for kind: Vector2i in [Vector2i(SHORT, 1), Vector2i(TALL, 1), Vector2i(SHORT, DWARFS)]:
		var floors := kind.x
		var layout: Array[Dictionary] = [
			_tiered(Vector2(0.0, _ahead_of_snout({}, 1.0)), WIDTH, floors, kind.y)
		]
		var sim := _runner({}, layout)
		var ref := _runner({}, layout, false)
		var out := {"steps": 0, "same": true, "stopped": 0, "slams": 0}
		while sim.powers.momentum + build < under and Num.i(out["steps"]) < roundi(MAX_S / DT):
			var was := sim.kaiju_pos
			out["slams"] = Num.i(out["slams"]) + _count(sim.step(DT, NORTH, false, 0), "slam")
			ref.step(DT, NORTH, false, 0)
			var same := (
				sim.kaiju_pos == ref.kaiju_pos and sim.chunks_destroyed == ref.chunks_destroyed
			)
			out["same"] = out["same"] == true and same
			out["stopped"] = Num.i(out["stopped"]) + int(sim.kaiju_pos == was)
			out["steps"] = Num.i(out["steps"]) + 1
		out["broken"] = sim.chunks_destroyed
		out["momentum"] = snappedf(sim.powers.momentum, 0.01)
		var same_walk: bool = out["same"]
		var held_ok := kind.y == DWARFS or Num.i(out["stopped"]) == 0  # a dwarfing one holds him
		check(
			same_walk and Num.i(out["slams"]) == 0 and held_ok,
			(
				"(c) under the threshold a %d-floor tier-%d building is met as without the run: %s"
				% [floors, kind.y, out]
			)
		)
		check(Num.i(out["broken"]) > 0, "(c) the body breaks into it as today: %s" % [out])


## Relative to his size: a building between the young croc's shoulder and the Behemoth's slams
## the young croc and is crashed through by the Behemoth.
func _check_relative_to_size() -> void:
	var runs: Array[Dictionary] = []
	for stage: String in ["young", "Behemoth"]:
		var levels: Dictionary = STAGES[stage]
		var block := _block(Vector2(0.0, _ahead_of_snout(levels, LEAD)), WIDTH, BETWEEN)
		var layout: Array[Dictionary] = [block]
		var sim := _runner(levels, layout)
		var out := _charge(sim, 1)
		out["crash_height"] = snappedf(sim.powers.run.crash_height(), 0.01)
		runs.append(out)
	check(
		Num.i(runs[0]["slams"]) == 1 and Num.i(runs[1]["slams"]) == 0,
		"a %d-floor building slams the young croc, not the Behemoth: %s" % [BETWEEN, runs]
	)
	var lost: Array[int] = runs[1]["lost"]
	check(
		lost[0] > 0 and Num.f(runs[1]["low"]) >= Num.f(_titan()["crash_min"]),
		"the Behemoth crashes through it: %s" % [runs[1]]
	)


## The croc builds full momentum from a standstill within FULL_BY_S walking straight; then a 90
## degree turn taken over TURN_S (the stick swung north to east, then held until the body faces
## it) keeps at least TURN_KEEPS of it at its lowest.
func _check_build_and_turn() -> void:
	var sim := _runner({}, [])
	var steps := 0
	while sim.powers.momentum < 1.0 and steps < roundi(MAX_S / DT):
		sim.step(DT, NORTH, false, 0)
		steps += 1
	check(
		steps * DT <= FULL_BY_S,
		"full momentum from a standstill in %.2f s (bar %.1f s)" % [steps * DT, FULL_BY_S]
	)
	var start := sim.powers.momentum
	var low := start
	var n := roundi(TURN_S / DT)
	for i: int in n:
		sim.step(DT, NORTH.rotated(0.5 * PI * (i + 1) / n), false, 0)
		low = minf(low, sim.powers.momentum)
	for _i: int in roundi(1.0 / DT):
		if absf(sim.facing.angle_to(EAST)) < Num.f(sim.body.cfg["turn_min"]):
			break
		sim.step(DT, EAST, false, 0)
		low = minf(low, sim.powers.momentum)
	check(
		start >= 1.0 and absf(sim.facing.angle_to(EAST)) < Num.f(sim.body.cfg["turn_min"]),
		"the gentle turn starts at full momentum (%.2f) and ends facing east" % start
	)
	check(
		low >= TURN_KEEPS * start,
		(
			"a 90 degree turn over %.0f s keeps %.0f%% of full momentum (bar %.0f%%)"
			% [TURN_S, 100.0 * low / maxf(start, 0.001), 100.0 * TURN_KEEPS]
		)
	)


## Momentum leaves the turn's rate alone (D-328, turns keep their weight): at each stage the same
## walk-up, then the stick snapped 90 degrees with full momentum and with none, makes the turn in
## the same time to within one step.
func _check_turn_rate() -> void:
	var times := {}
	for stage: String in STAGES:
		var pair: Array[float] = []
		var levels: Dictionary = STAGES[stage]
		for full: bool in [true, false]:
			var sim := _runner(levels, [])
			var titan := sim.powers.run.titan
			sim.powers.run.titan = {}
			_walk(sim, FULL_BY_S, NORTH)  # the same walk-up for both, with no run
			if full:
				sim.powers.run.titan = titan
				sim.powers.run.value = 1.0
			pair.append(_turn_time(sim))
		times[stage] = pair
	var worst := 0.0
	for stage: String in times:
		var pair: Array[float] = times[stage]
		worst = maxf(worst, absf(pair[0] - pair[1]))
	check(
		worst <= SAME_TURN_S + 0.0001,
		"a snapped 90 degree turn takes the same time with momentum and without (s): %s" % [times]
	)


## Seconds the body takes to face east once the stick snaps there.
func _turn_time(sim: RampageSim) -> float:
	var steps := 0
	var near := Num.f(sim.body.cfg["turn_min"])
	while absf(sim.facing.angle_to(EAST)) >= near and steps < roundi(MAX_S / DT):
		sim.step(DT, EAST, false, 0)
		steps += 1
	return snappedf(steps * DT, 0.0001)


## The same seeded charge down the row replays to the same place and the same broken chunks.
func _check_replay() -> void:
	var runs: Array[Dictionary] = []
	for _n: int in 2:
		runs.append(_charge(_runner({}, _row()), ROW))
	check(runs[0] == runs[1], "the same seeded charge replays (%s / %s)" % [runs[0], runs[1]])


## A save from before the run was always on (v5, the Momentum node bought to its top) loads as
## it is: the node kept at its level, and it boosts the run (full momentum sooner).
func _check_old_save() -> void:
	var save := SaveFile.new_save("reptilian")
	save["levels"] = {"r_tail": 1, "r_momentum": 4}
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(save))  # as the file holds it
	var loaded := SaveFile.migrate(parsed)
	var levels: Dictionary = loaded.get("levels", {})
	check(
		Num.i(levels.get("r_momentum", 0)) == 4,
		"an old save keeps its Momentum node at level 4: %s" % [levels]
	)
	var full_s: Array[float] = []
	for owned: Dictionary in [{}, levels]:
		var sim := _runner(owned, [])
		var steps := 0
		while sim.powers.momentum < 1.0 and steps < roundi(MAX_S / DT):
			sim.step(DT, NORTH, false, 0)
			steps += 1
		full_s.append(steps * DT)
	check(
		full_s[1] < full_s[0],
		"the loaded node boosts the run: full in %.2f s vs %.2f s without" % [full_s[1], full_s[0]]
	)
