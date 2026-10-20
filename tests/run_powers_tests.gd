extends "res://tests/lib/powers_base.gd"
## Powers suite: the species branches (docs/SPECIES.md, D-035) for the reptilian and the
## insectoid. Every branch node has a player-effect fixture: the same seeded, scripted scene
## with the node owned and without it plays out visibly differently. Headless, no autoloads.
## The cephalopod and the helicopters are in run_tentacles_tests.gd.
##   godot --headless --path . --script tests/run_powers_tests.gd


func suite_name() -> String:
	return "Powers"


func run_checks() -> void:
	await _t("_check_branches")
	await _t("_check_tail")
	await _t("_check_momentum")
	await _t("_check_shear")
	await _t("_check_beam")
	await _t("_check_scuttle")
	await _t("_check_glide")
	await _t("_check_climb")
	await _t("_check_brood")
	await _t("_check_streets")
	await _t("_check_base_unchanged")
	await _t("_check_levels")


func _check_branches() -> void:
	var missing: Array[String] = []
	for species_id: String in ["reptilian", "insectoid", "cephalopod"]:
		var tree := UpgradeTree.new(Content.upgrades(), {}, species_id)
		var own: Array[String] = []
		var ultimate := ""
		for id: String in tree.order:
			var def: Dictionary = tree.defs[id]
			var owner := str(def.get("species", ""))
			if owner != "" and owner != species_id:
				missing.append("%s tree holds %s" % [species_id, id])
			if owner == species_id:
				own.append(id)
				var requires: Array = def["requires"]
				if str(def["name"]).begins_with("ULTIMATE") and requires.has("evolve3"):
					ultimate = id
		if own.size() < 3 or ultimate == "":
			missing.append("%s branch %s, ultimate '%s'" % [species_id, own, ultimate])
	check(
		missing.is_empty(),
		(
			"each species has its own branch of 3+ nodes ending in an ultimate after Apex Titan: %s"
			% [missing]
		)
	)
	var saved := UpgradeTree.new(Content.upgrades(), {"r_tail": 2, "i_glide": 1}, "reptilian")
	check(
		saved.level("r_tail") == 2 and not saved.defs.has("i_glide"),
		"a reptilian's tree keeps its own levels and drops another species' nodes"
	)


## Tail Sweep: walking north past a building's east side and turning hard east swings the tail
## back through it; a band of floors is cut and the floors above it drop.
func _check_tail() -> void:
	var results: Array[Dictionary] = []
	for levels: Dictionary in [{"claws": 1}, {"claws": 1, "r_tail": 1}]:
		var sim := _sim("reptilian", levels, [_b(0, 0, Vector3i(3, 3, 8))], Vector2(2.2, 1.5))
		var seen := _run(sim, 0.4, NORTH)
		seen.merge(_run(sim, 1.0, EAST), true)
		results.append({"alive": _alive(sim, 0), "sweeps": sim.powers.tail_sweeps, "seen": seen})
	check(
		Num.i(results[0]["sweeps"]) == 0 and Num.i(results[1]["sweeps"]) >= 1,
		(
			"a hard turn sweeps the tail only with Tail Sweep (%d vs %d)"
			% [Num.i(results[0]["sweeps"]), Num.i(results[1]["sweeps"])]
		)
	)
	var seen_with: Dictionary = results[1]["seen"]
	check(
		Num.i(results[1]["alive"]) < Num.i(results[0]["alive"]) and seen_with.has("fall_start"),
		(
			"the tail cuts the building and its upper floors drop (%d vs %d chunks standing)"
			% [Num.i(results[1]["alive"]), Num.i(results[0]["alive"])]
		)
	)


## Momentum: charging down a straight street lined with blocks, the reptilian goes further
## and breaks more; a U-turn bleeds the momentum away.
func _check_momentum() -> void:
	var row: Array[Dictionary] = []
	for n: int in 5:
		row.append(_b(5.0 + n * 5.0, 0.0, Vector3i(3, 3, 3)))
	var out: Array[Dictionary] = []
	for levels: Dictionary in [{"r_tail": 1}, {"r_tail": 1, "r_momentum": 3}]:
		var sim := _sim("reptilian", levels, row, Vector2(0, 0))
		sim.stats["swipe_damage"] = 0.0  # the claw swipe would break the whole row either way
		_run(sim, 6.0, EAST)
		out.append({"x": sim.kaiju_pos.x, "broken": sim.chunks_destroyed, "sim": sim})
	check(
		Num.f(out[1]["x"]) > Num.f(out[0]["x"]) + 2.0,
		(
			"momentum carries the reptilian further down the street (%.1f vs %.1f)"
			% [Num.f(out[1]["x"]), Num.f(out[0]["x"])]
		)
	)
	check(
		Num.i(out[1]["broken"]) > Num.i(out[0]["broken"]),
		(
			"momentum breaks more of the street (%d vs %d chunks)"
			% [Num.i(out[1]["broken"]), Num.i(out[0]["broken"])]
		)
	)
	var charged: RampageSim = out[1]["sim"]
	var before := charged.powers.momentum
	_run(charged, 0.1, -EAST)
	check(
		before > 0.6 and charged.powers.momentum < 0.2,
		"a U-turn bleeds momentum (%.2f to %.2f)" % [before, charged.powers.momentum]
	)


## Shearing Tail: the same sweep through a taller building cuts more chunks.
func _check_shear() -> void:
	var cut: Array[int] = []
	for levels: Dictionary in [{"r_tail": 1}, {"r_tail": 1, "r_shear": 2}]:
		var sim := _sim("reptilian", levels, [_b(0, 0, Vector3i(3, 3, 14))], Vector2(2.2, 1.5))
		_run(sim, 0.4, NORTH)
		_run(sim, 1.5, EAST)
		cut.append(sim.powers.tail_cut)
	check(
		cut[1] > cut[0],
		"Shearing Tail cuts a deeper band out of a tower (%d vs %d chunks)" % [cut[1], cut[0]]
	)


## Atomic Beam: E fires a long beam that burns a line of buildings, keeps burning after it
## ends, and turns slowly to follow the stick. Without the node, E does nothing.
func _check_beam() -> void:
	var line: Array[Dictionary] = [_b(0, -6, Vector3i(3, 3, 4)), _b(0, -11, Vector3i(3, 3, 4))]
	var off := _sim("reptilian", {}, line, Vector2(0, 0))
	var off_seen := _run(off, 3.0, Vector2.ZERO, ULT)
	var on := _sim("reptilian", {"r_beam": 1}, line, Vector2(0, 0))
	var on_seen := _run(on, 3.0, Vector2.ZERO, ULT)
	check(
		not off_seen.has("beam_start") and on_seen.has("beam_start") and on_seen.has("coated"),
		"E fires the Atomic Beam only with the node, and it sets what it crosses burning"
	)
	check(
		_alive(on, 1) < _alive(off, 1),
		(
			"the beam reaches the second building down the line (%d vs %d standing)"
			% [_alive(on, 1), _alive(off, 1)]
		)
	)
	# Swept fast across a block, the beam only grazes it; the fire it leaves finishes the job.
	var swept := _sim("reptilian", {"r_beam": 1}, [_b(0, -8, Vector3i(3, 3, 4))], Vector2(0, 0))
	swept.facing = Vector2(-1, 0)
	_run(swept, 0.1, Vector2.ZERO, ULT)
	_run(swept, 0.5, Vector2(1, -1).normalized())
	var grazed := swept.chunks_destroyed
	_run(swept, 4.0, Vector2.ZERO)
	check(
		swept.chunks_destroyed > grazed + 3,
		(
			"grazed chunks keep burning down after the beam passes (%d to %d)"
			% [grazed, swept.chunks_destroyed]
		)
	)
	var steer := _sim("reptilian", {"r_beam": 1}, line, Vector2(0, 0))
	_run(steer, 0.1, Vector2.ZERO, ULT)
	_run(steer, 0.3, EAST)
	var turned := absf(NORTH.angle_to(steer.facing))
	check(
		turned > 0.2 and turned < PI * 0.45,
		"the beam turns slowly to follow the stick (%.2f rad in 0.3 s)" % turned
	)


func _check_scuttle() -> void:
	var dist: Array[float] = []
	for levels: Dictionary in [{}, {"i_scuttle": 2}]:
		var sim := _sim("insectoid", levels, [], Vector2(0, 20))
		_run(sim, 2.0, NORTH)
		dist.append(20.0 - sim.kaiju_pos.y)
	check(
		dist[1] > dist[0] * 1.15, "Scuttle covers more ground (%.1f vs %.1f)" % [dist[1], dist[0]]
	)


## Wing Buzz: tap leaps; holding the button glides on, steering, then lands with a crush.
func _check_glide() -> void:
	var out: Array[Dictionary] = []
	for levels: Dictionary in [{}, {"i_glide": 1}]:
		var sim := _sim("insectoid", levels, [_b(0, -14, Vector3i(3, 3, 3))], Vector2(0, 0))
		sim.facing = NORTH
		var seen := _run(sim, 1.5, NORTH, PRESS | HOLD)
		out.append({"y": sim.kaiju_pos.y, "seen": seen})
	var with: Dictionary = out[1]["seen"]
	var without: Dictionary = out[0]["seen"]
	check(
		with.has("glide_start") and with.has("glide_land") and not without.has("glide_start"),
		"holding the leap button glides and lands again only with Wing Buzz"
	)
	check(
		Num.f(out[1]["y"]) < Num.f(out[0]["y"]) - 2.0,
		(
			"the glide carries it further than the leap alone (%.1f vs %.1f)"
			% [-Num.f(out[1]["y"]), -Num.f(out[0]["y"])]
		)
	)


## Climber: on a tall tower, the insectoid climbs to the roof and breaks the top floors,
## far above what it can reach from the street.
func _check_climb() -> void:
	var top_hit: Array[int] = []
	var stood: Array[float] = []
	for levels: Dictionary in [{}, {"i_climb": 1}]:
		var sim := _sim("insectoid", levels, [_b(0, 0, Vector3i(3, 3, 16))], Vector2(0, 3.0))
		var highest := -1
		for i: int in 30 * 6:
			for event: Dictionary in sim.step(DT, NORTH if i < 13 else Vector2.ZERO, false):
				if str(event["type"]) == "chunks_broken":
					for c: Vector3i in event["cells"]:
						highest = maxi(highest, c.y)
		top_hit.append(highest)
		stood.append(sim.stand_y)
	var reach := _sim("insectoid", {}, [], Vector2.ZERO).reach_height()
	check(
		top_hit[0] < reach and top_hit[1] > reach + 4,
		(
			"climbing breaks floors far above street reach (floor %d vs %d, reach %.1f)"
			% [top_hit[1], top_hit[0], reach]
		)
	)
	check(stood[0] == 0.0, "without Climber the insectoid stays on the street")


## Brood: E lays eggs that hatch into young who bite the city and draw the tanks' fire.
func _check_brood() -> void:
	var ring: Array[Dictionary] = [
		_b(6, 0, Vector3i(3, 3, 3)), _b(-6, 0, Vector3i(3, 3, 3)), _b(0, 6, Vector3i(3, 3, 3))
	]
	var out: Array[RampageSim] = []
	for levels: Dictionary in [{}, {"i_brood": 1}]:
		var sim := _sim("insectoid", levels, ring, Vector2(0, -8))
		_run(sim, 0.1, Vector2.ZERO, ULT)
		_run(sim, 10.0, Vector2.ZERO)
		out.append(sim)
	check(
		out[0].brood.hatched == 0 and out[1].brood.hatched == 3,
		"E lays three eggs that hatch only with Brood (%d)" % out[1].brood.hatched
	)
	check(
		out[1].brood.bites > 5 and out[1].chunks_destroyed > out[0].chunks_destroyed,
		(
			"the young bite the city on their own (%d bites, %d vs %d chunks)"
			% [out[1].brood.bites, out[1].chunks_destroyed, out[0].chunks_destroyed]
		)
	)
	var sim := out[1]
	var tank := RampageSim.Tank.new()
	tank.id = 900
	tank.hp = 999.0
	tank.cooldown = 0.0
	tank.pos = (
		sim.brood.young[0].pos + Vector2(3, 0)
		if not sim.brood.young.is_empty()
		else Vector2(40, 40)
	)
	sim.tanks.append(tank)
	var shot_young := false
	for i: int in 30 * 3:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "tank_fired" and event.has("at"):
				shot_young = true
	check(shot_young, "a tank near the young fires on them instead of the kaiju")


## The building slow does not grow with the kaiju (lead review): a grown kaiju with no branch
## node strides down a 4-wide street lined with blocks at full speed, past every block.
func _check_streets() -> void:
	var street: Array[Dictionary] = []
	for n: int in 6:
		for side: float in [-3.5, 3.5]:
			street.append(_b(side, 34.0 - n * 8.0, Vector3i(3, 6, 4), 3))
	var grown := {"claws": 5, "hide": 5, "rage": 1, "evolve1": 1, "evolve2": 1}
	var slow: Array[String] = []
	for species_id: String in ["reptilian", "insectoid", "cephalopod"]:
		for levels: Dictionary in [{}, grown]:
			var sim := _sim(species_id, levels, street, Vector2(0, 40))
			_run(sim, 2.0, NORTH)
			var free := sim.stat("speed") * 2.0
			if 40.0 - sim.kaiju_pos.y < free * 0.95:
				slow.append(
					(
						"%s tier %d: %.1f of %.1f"
						% [species_id, sim.size_tier(), 40.0 - sim.kaiju_pos.y, free]
					)
				)
	check(slow.is_empty(), "young and grown kaiju walk a city street at full speed: %s" % [slow])
	# The street runs z 37 .. -9 (inside the arena's +-44.5); the kaiju starts at z 40.
	var far := _sim("reptilian", grown, street, Vector2(0, 40))
	_run(far, 11.0, NORTH)
	check(
		far.kaiju_pos.y < -10.0,
		(
			"a tier-3 kaiju with no branch passes all six blocks in 11 s (at z %.0f, past -10)"
			% far.kaiju_pos.y
		)
	)


## A kaiju with no branch node bought plays exactly as before the branches existed: no tail,
## no ram, no climb, no glide, no limbs or throws, no ultimate.
func _check_base_unchanged() -> void:
	var stray: Array[String] = []
	for species_id: String in ["reptilian", "insectoid", "cephalopod"]:
		var ring: Array[Dictionary] = [_b(5, 0, Vector3i(3, 3, 8)), _b(-5, 0, Vector3i(3, 3, 8))]
		var sim := _sim(species_id, {}, ring, Vector2(0, 3))
		var seen := {}
		for i: int in 30 * 8:
			var move := Vector2.from_angle(i * 0.11)
			var flags := RampageSim.HELD | (RampageSim.ULTIMATE if i % 60 == 0 else 0)
			for event: Dictionary in sim.step(DT, move, i % 45 == 0, flags):
				seen[str(event["type"])] = true
			if sim.stand_y != 0.0 or sim.powers.hit_mult() != 1.0:
				stray.append("%s lift/mult" % species_id)
				break
		for kind: String in [
			"tail_sweep", "glide_start", "beam_start", "eggs_laid", "limb", "grab", "ink", "coated"
		]:
			if seen.has(kind):
				stray.append("%s %s" % [species_id, kind])
		if sim.powers.has_ultimate():
			stray.append("%s ultimate" % species_id)
	check(
		stray.is_empty(), "a kaiju with no branch node uses none of the branch powers: %s" % [stray]
	)


## More levels of a node do more: a deeper tail cut, a faster scuttle, a longer glide.
func _check_levels() -> void:
	var cut: Array[int] = []
	for level: int in [1, 4]:
		var sim := _sim(
			"reptilian", {"r_tail": level}, [_b(0, 0, Vector3i(3, 3, 8), 2)], Vector2(2.2, 1.5)
		)
		_run(sim, 0.4, NORTH)
		_run(sim, 1.0, EAST)
		cut.append(sim.powers.tail_cut)
	var run: Array[float] = []
	for level: int in [1, 4]:
		var sim := _sim("insectoid", {"i_scuttle": level}, [], Vector2(0, 20))
		_run(sim, 2.0, NORTH)
		run.append(20.0 - sim.kaiju_pos.y)
	var glide: Array[float] = []
	for level: int in [1, 3]:
		var sim := _sim("insectoid", {"i_glide": level}, [], Vector2(0, 30))
		sim.facing = NORTH
		_run(sim, 4.0, NORTH, PRESS | HOLD)
		glide.append(30.0 - sim.kaiju_pos.y)
	check(
		cut[1] > cut[0] and run[1] > run[0] * 1.2 and glide[1] > glide[0] + 3.0,
		(
			"higher levels do more: tail cut %d > %d, scuttle %.1f > %.1f, glide %.1f > %.1f"
			% [cut[1], cut[0], run[1], run[0], glide[1], glide[0]]
		)
	)
