extends "res://tests/lib/powers_base.gd"
## Fire suite: fire that spreads building to building (FireSpread, D-126, D-129). Every fire node
## has a player-effect fixture: the same seeded scene with the node owned and without it plays
## out differently. Plus: no burning shell is ever left, burn-outs pay burn_pay of a smash, the
## breath, beam and stray shells light fires, the same seed replays the same fires, and the
## per-tick cost at the adult city. Headless.
##   godot --headless --path . --script tests/run_fire_tests.gd

const FireStage := preload("res://tests/lib/fire_stage.gd")
const CurveCheck := preload("res://tests/lib/fx_curve_check.gd")
const ABLAZE := {"r_ablaze": 1}
## Two 3 x 3 x 4 blocks a 1 m street apart, the kaiju 15 m off (in reach of nothing).
const KAIJU_AT := Vector2(-15, 0)


func suite_name() -> String:
	return "Fire"


func run_checks() -> void:
	await _t("_check_spread")
	await _t("_check_off_without_ablaze")
	await _t("_check_landmarks_burn")
	await _t("_check_burn_pay")
	await _t("_check_firebreak")
	await _t("_check_alarm")
	await _t("_check_front")
	await _t("_check_embers")
	await _t("_check_firestorm")
	await _t("_check_lights")
	await _h("FireStage", func() -> void: FireStage.new(check).run())
	await _h("FxCurve", func() -> void: CurveCheck.check(check))


func _pair(levels: Dictionary, gap: float = 1.0) -> RampageSim:
	return _sim(
		"reptilian",
		levels,
		[_b(0, 0, Vector3i(3, 3, 4)), _b(3 + gap, 0, Vector3i(3, 3, 4))],
		KAIJU_AT
	)


## Steps `seconds` idle; returns {"building:event" -> first second it happened}.
func _times(sim: RampageSim, seconds: float) -> Dictionary:
	var first := {}
	for i: int in roundi(seconds / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
			var kind := str(event["type"])
			if kind.begins_with("fire_"):
				var key := "%d:%s" % [Num.i(event["building"]), kind]
				if not first.has(key):
					first[key] = i * DT
	return first


## Lit, one block burns, the next one over glows 1-3 s and then burns, and both burn out and
## collapse to nothing: no burning shell (#111).
func _check_spread() -> void:
	var sim := _pair(ABLAZE)
	sim.powers.fire.ignite(0)
	var t := _times(sim, 30.0)
	var glow := Num.f(t.get("1:fire_glow", -1.0))
	var burn := Num.f(t.get("1:fire_burning", -1.0))
	check(
		(
			t.has("0:fire_burnt")
			and glow >= 0.0
			and burn - glow >= 1.0 - DT
			and burn - glow <= 3.0 + DT
		),
		(
			"a lit block burns and the one across the street glows %.1f s first, then burns: %s"
			% [burn - glow, t]
		)
	)
	check(
		(
			t.has("1:fire_burnt")
			and _alive(sim, 0) == 0
			and _alive(sim, 1) == 0
			and sim.falls.is_empty()
		),
		(
			"both burn out and collapse: no burning shell left (%d, %d chunks standing)"
			% [_alive(sim, 0), _alive(sim, 1)]
		)
	)
	check(not t.has("2:fire_glow"), "the far block never heats")


## Without City Ablaze nothing catches: not a lit block, a shell or the breath.
func _check_off_without_ablaze() -> void:
	var sim := _pair({})
	sim.powers.fire.ignite(0)
	sim.powers.fire.shelled(Vector2(4, 0))
	var t := _times(sim, 20.0)
	check(
		t.is_empty() and _alive(sim, 0) == 36,
		"without City Ablaze no fire starts or spreads: %s" % [t]
	)


## Landmarks burn (director 2026-10-25: "Yes, landmarks burn"; powers.fire.spread_landmarks on):
## a burning neighbour heats a landmark, which glows and then burns like any block. The same
## scene with the flag turned off leaves it standing (the control that fails on the old default).
func _check_landmarks_burn() -> void:
	var lit := _pair(ABLAZE)
	lit.buildings[1].landmark = "test_landmark"
	lit.powers.fire.ignite(0)
	var t := _times(lit, 30.0)
	check(
		t.has("1:fire_glow") and t.has("1:fire_burning"),
		"a burning neighbour ignites a landmark by default: %s" % [t]
	)
	var held := _pair(ABLAZE)
	held.buildings[1].landmark = "test_landmark"
	held.powers.fire.cfg = held.powers.fire.cfg.duplicate()
	held.powers.fire.cfg["spread_landmarks"] = false
	held.powers.fire.ignite(0)
	var kept := _times(held, 30.0)
	check(
		not kept.has("1:fire_glow") and _alive(held, 1) == 36,
		"with spread_landmarks off the landmark stands: %s" % [kept]
	)


## A burn-out pays burn_pay of the same building knocked down (its ground floor broken the
## same way, cell by cell, the same collapse), counted until every piece has landed: the first
## burn-out, so the conflagration is 1. The rooftop squad is army, paid in full either way.
func _check_burn_pay() -> void:
	var burnt := _sim("reptilian", ABLAZE, [_b(0, 0, Vector3i(3, 3, 6))], KAIJU_AT)
	var knocked := _sim("reptilian", ABLAZE, [_b(0, 0, Vector3i(3, 3, 6))], KAIJU_AT)
	for sim: RampageSim in [burnt, knocked]:
		sim.army_units.squads.clear()
	burnt.powers.fire.ignite(0)
	var steps := 0
	while burnt.powers.fire.burnt_out == 0 and steps < 900:
		burnt.step(DT, Vector2.ZERO, false, 0)
		if burnt.powers.fire.burnt_out == 0:
			knocked.step(DT, Vector2.ZERO, false, 0)
		steps += 1
	var start := knocked.rubble  # the same in both runs until the burn-out step
	# Knocked down the same way: the same ground cells in the same batches, no fire.
	var cells := knocked.powers.fire.ground_cells(0)
	var fire_cfg: Dictionary = Content.tuning()["powers"]["fire"]
	var batches := Num.i(fire_cfg["burn_out_steps"])
	var per := ceili(cells.size() / float(batches))
	var every := maxi(1, roundi(Num.f(fire_cfg["burn_out_seconds"]) / batches / DT))
	while not cells.is_empty() and _alive(knocked, 0) > 0:
		var batch: Array[Vector3i] = []
		while not cells.is_empty() and batch.size() < per:
			batch.append(cells.pop_front())
		var amounts := PackedFloat32Array()
		amounts.resize(batch.size())
		amounts.fill(1000000.0)
		knocked.damage_cells(0, batch, amounts)
		for k: int in every:
			knocked.step(DT, Vector2.ZERO, false, 0)
	_times(burnt, 8.0)
	_times(knocked, 8.0)
	var share := Num.f(Content.tuning()["powers"]["fire"]["burn_pay"])
	var ratio := (burnt.rubble - start) / maxf(0.001, knocked.rubble - start)
	check(
		absf(ratio - share) < 0.02 and _alive(burnt, 0) == 0 and burnt.falls.is_empty(),
		(
			"a burn-out pays %.2f of the same collapse knocked down (burn_pay %.2f; %.2f vs %.2f)"
			% [ratio, share, burnt.rubble - start, knocked.rubble - start]
		)
	)


## Smashed while it glows, the next block never burns: a firebreak (R 26.2).
func _check_firebreak() -> void:
	var sim := _pair(ABLAZE)
	sim.powers.fire.ignite(0)
	var broke := false
	var burned := false
	for i: int in roundi(30.0 / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
			var kind := str(event["type"])
			if Num.i(event.get("building", -1)) != 1:
				continue
			if kind == "fire_glow" and not broke:
				broke = true
				_smash(sim, 1)
			burned = burned or kind == "fire_burning"
	check(
		broke and not burned,
		"a glowing block smashed first never burns (glowed %s, burned %s)" % [broke, burned]
	)


func _smash(sim: RampageSim, index: int) -> void:
	var b := sim.buildings[index]
	var cells: Array[Vector3i] = []
	for y: int in b.height:
		for x: int in b.w:
			for z: int in b.d:
				cells.append(Vector3i(x, y, z))
	var amounts := PackedFloat32Array()
	amounts.resize(cells.size())
	amounts.fill(1000000.0)
	sim.damage_cells(index, cells, amounts)


## Five-Alarm: the next block catches sooner.
func _check_alarm() -> void:
	var slow := _pair(ABLAZE)
	var fast := _pair({"r_ablaze": 1, "r_alarm": 1})
	slow.powers.fire.ignite(0)
	fast.powers.fire.ignite(0)
	var a := Num.f(_times(slow, 20.0).get("1:fire_glow", 99.0))
	var b := Num.f(_times(fast, 20.0).get("1:fire_glow", 99.0))
	check(b < a - 0.5, "Five-Alarm: the next block glows sooner (%.1f s vs %.1f s)" % [b, a])


## Fire Front: with the wind blowing east, the block downwind catches before the one upwind;
## without the node they catch together.
func _check_front() -> void:
	var glows: Array[float] = []
	for levels: Dictionary in [ABLAZE, {"r_ablaze": 1, "r_front": 1}]:
		var row: Array[Dictionary] = [
			_b(0, 0, Vector3i(3, 3, 4)), _b(4, 0, Vector3i(3, 3, 4)), _b(-4, 0, Vector3i(3, 3, 4))
		]
		var sim := _sim("reptilian", levels, row, Vector2(0, -15))
		sim.powers.fire.wind = Vector2.RIGHT
		sim.powers.fire.ignite(0)
		var t := _times(sim, 20.0)
		glows.append(Num.f(t.get("1:fire_glow", 99.0)))
		glows.append(Num.f(t.get("2:fire_glow", 99.0)))
	check(
		absf(glows[0] - glows[1]) < DT and glows[2] < glows[3] - 0.5,
		(
			"Fire Front: downwind catches first (%.1f s vs %.1f s upwind; %.1f / %.1f without)"
			% [glows[2], glows[3], glows[0], glows[1]]
		)
	)


## Ember Rain: a block 3.5 m away, past a fire's reach, catches only with embers.
func _check_embers() -> void:
	var near := _pair(ABLAZE, 3.5)
	var far := _pair({"r_ablaze": 1, "r_embers": 1}, 3.5)
	near.powers.fire.ignite(0)
	far.powers.fire.ignite(0)
	var without := _times(near, 25.0)
	var with := _times(far, 25.0)
	check(
		not without.has("1:fire_glow") and with.has("1:fire_glow"),
		(
			"Ember Rain: fire leaps a 3.5 m street only with the node (%s vs %s)"
			% [with.has("1:fire_glow"), without.has("1:fire_glow")]
		)
	)


## Firestorm: an explosive site going off lights what is round it only with the node (a stub
## until explosive sites merge: nothing in the city calls blast yet).
func _check_firestorm() -> void:
	var lit: Array[bool] = []
	for levels: Dictionary in [ABLAZE, {"r_ablaze": 1, "r_firestorm": 1}]:
		var sim := _pair(levels)
		sim.powers.fire.blast(Vector2(0, 0), 2.0)
		lit.append(sim.powers.fire.state[0] == FireSpread.State.BURNING)
	check(
		not lit[0] and lit[1],
		"Firestorm: a blast lights the block beside it only with the node %s" % [lit]
	)


## D-129: the breath, the beam and a stray shell each light a block once City Ablaze is owned
## (chances set to 1 here; the beam's burning coat always lights).
func _check_lights() -> void:
	var by := {}
	for levels: Dictionary in [{"r_beam": 1}, {"r_beam": 1, "r_ablaze": 1}]:
		var owned := levels.has("r_ablaze")
		by["breath %s" % owned] = _breath_lights(levels)
		var beamed := _sim("reptilian", levels, [_b(0, -6, Vector3i(3, 3, 4))], Vector2(0, 0))
		by["beam %s" % owned] = _run(beamed, 3.0, Vector2.ZERO, ULT).has("fire_burning")
		var shelled := _pair(levels)
		shelled.powers.fire.cfg = _sure(shelled)
		shelled.powers.fire.shelled(Vector2(1.6, 0))
		by["shell %s" % owned] = shelled.powers.fire.state[0] == FireSpread.State.BURNING
	var lit_on: bool = by["breath true"] == true and by["beam true"] == true
	lit_on = lit_on and by["shell true"] == true
	check(
		by.values().count(true) == 3 and lit_on,
		"the breath, the beam and a stray shell light a block only with City Ablaze: %s" % [by]
	)


func _breath_lights(levels: Dictionary) -> bool:
	var sim := _sim("reptilian", levels, [_b(0, 0, Vector3i(3, 3, 4))], Vector2.ZERO)
	sim.powers.fire.cfg = _sure(sim)
	sim.facing = NORTH
	var snout: Vector2 = BreathCone.of(sim)["origin"]
	sim.kaiju_pos = Vector2(0, 4) - snout  # the breath starts 4 m south of the block's centre
	sim.stats["ability_damage"] = 0.0  # the block must stand to catch: this watches the fire
	var seen := {}
	for i: int in roundi(3.0 / DT):  # held down: the press counts once it has risen and is ready
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, RampageSim.BREATH):
			seen[str(event["type"])] = true
	return seen.has("ability") and seen.has("fire_burning")


## The fire tuning with every ignition chance 1 (a copy: Content's own stays as it is).
func _sure(sim: RampageSim) -> Dictionary:
	var cfg := sim.powers.fire.cfg.duplicate(true)
	cfg["breath_ignite"] = 1.0
	cfg["shell_ignite"] = 1.0
	return cfg
