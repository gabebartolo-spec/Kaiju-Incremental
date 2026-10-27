extends "res://tests/lib/leap_base.gd"
## The titan's run (Momentum, D-337, director 2026-10-27: "running wont have a sprint button, it
## should be momentum based, at high momentum he can crash right through smaller buildings, and
## collide with a bang into bigger ones"), the croc's entry (powers.momentum.titans.croc): always
## on; at crash_min he crashes through what stands under his shoulder without slowing or spending
## it; at slam_min his first touch of anything at or over it is one slam (a dent, momentum 0, the
## body stopped); below the thresholds nothing changes (D-280). The croc's bars (lead 2026-10-27):
## full momentum from a standstill within 1.5 s walking straight, a 90 degree turn taken over 2 s at
## full keeps at least 70% of it, and the turn's rate unchanged (D-328). Player-effect fixture
## "croc.momentum": the same seeded charge with the run on and off. Seeded by design: every sim is
## Seeds.make("army", 0) (leap_base._croc) on a hand-made layout; the claws are idle (ClawSwipe
## rakes on its own clock), so each check measures the body.

const NORTH := Vector2(0.0, -1.0)
const EAST := Vector2(1.0, 0.0)
## The charge: the croc at (0, 30) walks north CHARGE_S; the first building's near face stands
## LEAD beyond his snout (he meets it at full momentum), the rest of a row GAP apart.
const CHARGE_S := 6.0
const LEAD := 9.0
const GAP := 6.0
const ROW := 4
const WIDTH := 3  # cells a side
const SHORT := 2  # floors: under the young croc's shoulder (about 3.1)
const TALL := 8  # floors: over it
const BETWEEN := 5  # floors: over the young croc's shoulder, under the Behemoth's (about 6.5)
## The croc's bars (lead 2026-10-27).
const FULL_BY_S := 1.5
const TURN_S := 2.0
const TURN_KEEPS := 0.7
## "Unchanged": the snapped turn made within one step of the same time with and without momentum.
const SAME_TURN_S := 1.0 / 60.0
const MAX_S := 5.0


func suite_name() -> String:
	return "Momentum"


func run_checks() -> void:
	await _t("_check_entries")
	await _t("_check_crash_through")
	await _t("_check_slam")
	await _t("_check_below_threshold")
	await _t("_check_relative_to_size")
	await _t("_check_build_time")
	await _t("_check_gentle_turn")
	await _t("_check_turn_rate")
	await _t("_check_replay")
	await _t("_check_old_save")


## The croc at `levels` on `layout`, the claws idle, with the run on (his entry) or off (none).
func _runner(levels: Dictionary, layout: Array[Dictionary], on: bool = true) -> RampageSim:
	var sim := _croc(levels, layout)
	sim.stats["swipe_damage"] = 0.0
	if not on:
		sim.powers.run.titan = {}
	return sim


## The croc's entry, as the reptilian plays it.
func _titan() -> Dictionary:
	return _croc({}, []).powers.run.titan


## The z of a WIDTH-deep building's centre whose near face stands `lead` beyond the snout of the
## croc at `levels` standing at (0, 30) facing north.
func _ahead_of_snout(levels: Dictionary, lead: float) -> float:
	var probe := _croc(levels, [])
	var front := 0.0
	for d: Array in probe.body.discs():
		front = maxf(front, Num.f(d[0]) + Num.f(d[1]))
	return 30.0 - front * probe.body_scale() - lead - WIDTH * 0.5


## A row of ROW short buildings up the street from LEAD beyond the young croc's snout.
func _row() -> Array[Dictionary]:
	var first := _ahead_of_snout({}, LEAD)
	var row: Array[Dictionary] = []
	for n: int in ROW:
		row.append(_block(Vector2(0.0, first - n * GAP), WIDTH, SHORT))
	return row


## Walks `sim` north CHARGE_S: where he ended (z), the least momentum on a step that broke
## something, the slams, and the chunks each of the first `count` buildings lost.
func _charge(sim: RampageSim, count: int) -> Dictionary:
	var full: Array[int] = []
	for n: int in count:
		full.append(sim.buildings[n].frame.alive_count)
	var low := INF
	var slams := 0
	for _n: int in roundi(CHARGE_S / DT):
		var before := sim.chunks_destroyed
		slams += _count(sim.step(DT, NORTH, false, 0), "slam")
		if sim.chunks_destroyed > before:
			low = minf(low, sim.powers.momentum)
	var lost: Array[int] = []
	for n: int in count:
		lost.append(full[n] - sim.buildings[n].frame.alive_count)
	return {"z": snappedf(sim.kaiju_pos.y, 0.001), "low": low, "slams": slams, "lost": lost}


func _count(events: Array[Dictionary], kind: String) -> int:
	var n := 0
	for event: Dictionary in events:
		if str(event["type"]) == kind:
			n += 1
	return n


func _walk(sim: RampageSim, seconds: float, stick: Vector2) -> void:
	for _n: int in roundi(seconds / DT):
		sim.step(DT, stick, false, 0)


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
	check(
		least > 0 and Num.f(on["z"]) < last_face,
		(
			"(a) he passes through the row, each building carved: %s (last face z %.1f)"
			% [on, last_face]
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


## (c) Below crash_min and slam_min nothing changes (D-280): from a standstill into a short and a
## tall building just ahead, the walk goes step for step as it does with the thresholds out of
## reach; no slam, the body breaks into it, and he is never stopped.
func _check_below_threshold() -> void:
	var titan := _titan()
	var under := minf(Num.f(titan["crash_min"]), Num.f(titan["slam_min"]))
	var build := DT / Num.f(titan["build_seconds"])
	for floors: int in [SHORT, TALL]:
		var layout: Array[Dictionary] = [
			_block(Vector2(0.0, _ahead_of_snout({}, 1.0)), WIDTH, floors)
		]
		var sim := _runner({}, layout)
		var ref := _runner({}, layout)
		var never := ref.powers.run.titan.duplicate()
		never["crash_min"] = INF
		never["slam_min"] = INF
		ref.powers.run.titan = never
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
		check(
			same_walk and Num.i(out["slams"]) == 0 and Num.i(out["stopped"]) == 0,
			(
				"(c) under the threshold a %d-floor building is met as without the run: %s"
				% [floors, out]
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


## The croc builds full momentum from a standstill within FULL_BY_S walking straight.
func _check_build_time() -> void:
	var sim := _runner({}, [])
	var steps := 0
	while sim.powers.momentum < 1.0 and steps < roundi(MAX_S / DT):
		sim.step(DT, NORTH, false, 0)
		steps += 1
	check(
		steps * DT <= FULL_BY_S,
		"full momentum from a standstill in %.2f s (bar %.1f s)" % [steps * DT, FULL_BY_S]
	)


## A 90 degree turn taken over TURN_S at full momentum (the stick swung north to east, then held
## until the body faces it) keeps at least TURN_KEEPS of it at its lowest.
func _check_gentle_turn() -> void:
	var sim := _runner({}, [])
	_walk(sim, FULL_BY_S, NORTH)
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
