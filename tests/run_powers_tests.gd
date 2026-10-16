extends "res://tests/lib/runner.gd"
## Powers suite: the species branches (docs/SPECIES.md, D-035) and the helicopters (D-037).
## Every branch node has a player-effect fixture: the same seeded, scripted scene with the
## node owned and without it plays out visibly differently. Headless, no autoloads.
##   godot --headless --path . --script tests/run_powers_tests.gd

const DT := 1.0 / 30.0
const NORTH := Vector2(0, -1)
const EAST := Vector2(1, 0)


func suite_name() -> String:
	return "Powers"


func run_checks() -> void:
	_check_branches()
	_check_tail()
	_check_momentum()
	_check_shear()
	_check_beam()
	_check_scuttle()
	_check_glide()
	_check_climb()
	_check_brood()
	_check_hydra()
	_check_squeeze()
	_check_grab()
	_check_ink()
	_check_helicopters()
	_check_replay()


## A building entry for a hand-made layout.
func _b(x: float, z: float, w: int, d: int, h: int, tier: int = 1) -> Dictionary:
	return {"x": x, "z": z, "w": w, "d": d, "h": h, "tier": tier, "style": 0}


## A kaiju of `species_id` with `levels` (prerequisites not enforced: the sim reads stats) in
## a hand-made layout, standing at `at`. A far building keeps the run from ending at once.
func _sim(
	species_id: String, levels: Dictionary, layout: Array[Dictionary], at: Vector2
) -> RampageSim:
	var species := Content.species_def(species_id)
	var tree := UpgradeTree.new(Content.upgrades(), levels, species_id)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var all: Array[Dictionary] = []
	all.append_array(layout)
	all.append(_b(38.0, 38.0, 2, 2, 2))
	var sim := RampageSim.new(stats, Content.tuning(), all, Seeds.make("army", 0))
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	sim.kaiju_pos = at
	return sim


## Steps for `seconds` with a fixed input; returns every event type seen, counted.
func _run(
	sim: RampageSim,
	seconds: float,
	move: Vector2,
	press: bool = false,
	hold: bool = false,
	ultimate: bool = false
) -> Dictionary:
	var seen := {}
	for i: int in roundi(seconds / DT):
		for event: Dictionary in sim.step(DT, move, press and i == 0, hold, ultimate and i == 0):
			var kind := str(event["type"])
			seen[kind] = Num.i(seen.get(kind, 0)) + 1
	return seen


func _alive(sim: RampageSim, index: int) -> int:
	return sim.buildings[index].frame.alive_count


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
		"each species has its own branch of 3+ nodes ending in an ultimate after Apex Titan: %s" % [missing]
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
		var sim := _sim("reptilian", levels, [_b(0, 0, 3, 3, 8)], Vector2(2.2, 1.5))
		var seen := _run(sim, 0.4, NORTH)
		seen.merge(_run(sim, 1.0, EAST), true)
		results.append({"alive": _alive(sim, 0), "sweeps": sim.powers.tail_sweeps, "seen": seen})
	check(
		Num.i(results[0]["sweeps"]) == 0 and Num.i(results[1]["sweeps"]) >= 1,
		"a hard turn sweeps the tail only with Tail Sweep (%d vs %d)"
		% [Num.i(results[0]["sweeps"]), Num.i(results[1]["sweeps"])]
	)
	var seen_with: Dictionary = results[1]["seen"]
	check(
		Num.i(results[1]["alive"]) < Num.i(results[0]["alive"]) and seen_with.has("fall_start"),
		"the tail cuts the building and its upper floors drop (%d vs %d chunks standing)"
		% [Num.i(results[1]["alive"]), Num.i(results[0]["alive"])]
	)


## Momentum: charging down a straight street lined with blocks, the reptilian goes further
## and breaks more; a U-turn bleeds the momentum away.
func _check_momentum() -> void:
	var row: Array[Dictionary] = []
	for n: int in 5:
		row.append(_b(5.0 + n * 5.0, 0.0, 3, 3, 3))
	var out: Array[Dictionary] = []
	for levels: Dictionary in [{"r_tail": 1}, {"r_tail": 1, "r_momentum": 3}]:
		var sim := _sim("reptilian", levels, row, Vector2(0, 0))
		_run(sim, 6.0, EAST)
		out.append({"x": sim.kaiju_pos.x, "broken": sim.chunks_destroyed, "sim": sim})
	check(
		Num.f(out[1]["x"]) > Num.f(out[0]["x"]) + 2.0,
		"momentum carries the reptilian further down the street (%.1f vs %.1f)"
		% [Num.f(out[1]["x"]), Num.f(out[0]["x"])]
	)
	check(
		Num.i(out[1]["broken"]) > Num.i(out[0]["broken"]),
		"momentum breaks more of the street (%d vs %d chunks)"
		% [Num.i(out[1]["broken"]), Num.i(out[0]["broken"])]
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
		var sim := _sim("reptilian", levels, [_b(0, 0, 3, 3, 14)], Vector2(2.2, 1.5))
		_run(sim, 0.4, NORTH)
		_run(sim, 1.5, EAST)
		cut.append(sim.powers.tail_cut)
	check(
		cut[1] > cut[0], "Shearing Tail cuts a deeper band out of a tower (%d vs %d chunks)" % [cut[1], cut[0]]
	)


## Atomic Beam: E fires a long beam that burns a line of buildings, keeps burning after it
## ends, and turns slowly to follow the stick. Without the node, E does nothing.
func _check_beam() -> void:
	var line: Array[Dictionary] = [_b(0, -6, 3, 3, 4), _b(0, -11, 3, 3, 4)]
	var off := _sim("reptilian", {}, line, Vector2(0, 0))
	var off_seen := _run(off, 3.0, Vector2.ZERO, false, false, true)
	var on := _sim("reptilian", {"r_beam": 1}, line, Vector2(0, 0))
	var on_seen := _run(on, 3.0, Vector2.ZERO, false, false, true)
	check(
		not off_seen.has("beam_start") and on_seen.has("beam_start") and on_seen.has("coated"),
		"E fires the Atomic Beam only with the node, and it sets what it crosses burning"
	)
	check(
		_alive(on, 1) < _alive(off, 1),
		"the beam reaches the second building down the line (%d vs %d standing)"
		% [_alive(on, 1), _alive(off, 1)]
	)
	# Swept fast across a block, the beam only grazes it; the fire it leaves finishes the job.
	var swept := _sim("reptilian", {"r_beam": 1}, [_b(0, -8, 3, 3, 4)], Vector2(0, 0))
	swept.facing = Vector2(-1, 0)
	_run(swept, 0.1, Vector2.ZERO, false, false, true)
	_run(swept, 0.5, Vector2(1, -1).normalized())
	var grazed := swept.chunks_destroyed
	_run(swept, 4.0, Vector2.ZERO)
	check(
		swept.chunks_destroyed > grazed + 3,
		"grazed chunks keep burning down after the beam passes (%d to %d)"
		% [grazed, swept.chunks_destroyed]
	)
	var steer := _sim("reptilian", {"r_beam": 1}, line, Vector2(0, 0))
	_run(steer, 0.1, Vector2.ZERO, false, false, true)
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
	check(dist[1] > dist[0] * 1.15, "Scuttle covers more ground (%.1f vs %.1f)" % [dist[1], dist[0]])


## Wing Buzz: tap leaps; holding the button glides on, steering, then lands with a crush.
func _check_glide() -> void:
	var out: Array[Dictionary] = []
	for levels: Dictionary in [{}, {"i_glide": 1}]:
		var sim := _sim("insectoid", levels, [_b(0, -14, 3, 3, 3)], Vector2(0, 0))
		sim.facing = NORTH
		var seen := _run(sim, 1.5, NORTH, true, true)
		out.append({"y": sim.kaiju_pos.y, "seen": seen})
	var with: Dictionary = out[1]["seen"]
	var without: Dictionary = out[0]["seen"]
	check(
		with.has("glide_start") and with.has("glide_land") and not without.has("glide_start"),
		"holding the leap button glides and lands again only with Wing Buzz"
	)
	check(
		Num.f(out[1]["y"]) < Num.f(out[0]["y"]) - 2.0,
		"the glide carries it further than the leap alone (%.1f vs %.1f)"
		% [-Num.f(out[1]["y"]), -Num.f(out[0]["y"])]
	)


## Climber: on a tall tower, the insectoid climbs to the roof and breaks the top floors,
## far above what it can reach from the street.
func _check_climb() -> void:
	var top_hit: Array[int] = []
	var stood: Array[float] = []
	for levels: Dictionary in [{}, {"i_climb": 1}]:
		var sim := _sim("insectoid", levels, [_b(0, 0, 3, 3, 16)], Vector2(0, 3.0))
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
		"climbing breaks floors far above street reach (floor %d vs %d, reach %.1f)"
		% [top_hit[1], top_hit[0], reach]
	)
	check(stood[0] == 0.0, "without Climber the insectoid stays on the street")


## Brood: E lays eggs that hatch into young who bite the city and draw the tanks' fire.
func _check_brood() -> void:
	var ring: Array[Dictionary] = [_b(6, 0, 3, 3, 3), _b(-6, 0, 3, 3, 3), _b(0, 6, 3, 3, 3)]
	var out: Array[RampageSim] = []
	for levels: Dictionary in [{}, {"i_brood": 1}]:
		var sim := _sim("insectoid", levels, ring, Vector2(0, -8))
		_run(sim, 0.1, Vector2.ZERO, false, false, true)
		_run(sim, 10.0, Vector2.ZERO)
		out.append(sim)
	check(
		out[0].brood.hatched == 0 and out[1].brood.hatched == 3,
		"E lays three eggs that hatch only with Brood (%d)" % out[1].brood.hatched
	)
	check(
		out[1].brood.bites > 5 and out[1].chunks_destroyed > out[0].chunks_destroyed,
		"the young bite the city on their own (%d bites, %d vs %d chunks)"
		% [out[1].brood.bites, out[1].chunks_destroyed, out[0].chunks_destroyed]
	)
	var sim := out[1]
	var tank := RampageSim.Tank.new()
	tank.id = 900
	tank.hp = 999.0
	tank.cooldown = 0.0
	tank.pos = sim.brood.young[0].pos + Vector2(3, 0) if not sim.brood.young.is_empty() else Vector2(40, 40)
	sim.tanks.append(tank)
	var shot_young := false
	for i: int in 30 * 3:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "tank_fired" and event.has("at"):
				shot_young = true
	check(shot_young, "a tank near the young fires on them instead of the kaiju")


## Hydra Limbs: standing out of stomp reach, freed tentacles still strike the buildings and
## tanks all around, each on its own timer.
func _check_hydra() -> void:
	var ring: Array[Dictionary] = [_b(4.5, 0, 3, 3, 3), _b(-4.5, 0, 3, 3, 3), _b(0, 4.5, 3, 3, 3)]
	var out: Array[RampageSim] = []
	var strikes: Array[int] = []
	for levels: Dictionary in [{}, {"c_hydra": 3}, {"c_hydra": 1}]:
		var sim := _sim("cephalopod", levels, ring, Vector2(0, 0))
		_run(sim, 2.0, Vector2.ZERO)
		strikes.append(sim.powers.limb_strikes)
		_run(sim, 3.0, Vector2.ZERO)
		out.append(sim)
	check(
		strikes[0] == 0 and strikes[1] >= 6 and strikes[1] > strikes[2] * 2,
		"each freed limb strikes on its own (0 / 1 / 3 limbs: %d / %d / %d strikes in 2 s)"
		% [strikes[0], strikes[2], strikes[1]]
	)
	var hit := 0
	for i: int in 3:
		if _alive(out[1], i) < _alive(out[0], i):
			hit += 1
	check(hit >= 2, "the limbs hit buildings on several sides (%d of 3)" % hit)


## Squeeze: through a narrow alley between two strong towers, the cephalopod slips through
## instead of shoving.
func _check_squeeze() -> void:
	var alley: Array[Dictionary] = [_b(-2.5, 0, 3, 6, 6, 3), _b(2.5, 0, 3, 6, 6, 3)]
	var z: Array[float] = []
	for levels: Dictionary in [{}, {"c_squeeze": 2}]:
		var sim := _sim("cephalopod", levels, alley, Vector2(0, 5))
		_run(sim, 3.0, NORTH)
		z.append(sim.kaiju_pos.y)
	check(z[1] < z[0] - 1.5, "Squeeze gets through the alley faster (z %.1f vs %.1f)" % [z[1], z[0]])


## Grab and Throw: a tank in reach is seized and hurled where the kaiju faces; it lands like a
## grenade on the building there.
func _check_grab() -> void:
	var out: Array[Dictionary] = []
	for levels: Dictionary in [{}, {"c_grab": 1}]:
		var sim := _sim("cephalopod", levels, [_b(0, -7, 3, 3, 3)], Vector2(0, 0))
		sim.facing = NORTH
		var tank := RampageSim.Tank.new()
		tank.id = 900
		tank.hp = 200.0
		tank.cooldown = 99.0
		tank.pos = Vector2(3.5, 0)
		sim.tanks.append(tank)
		var seen := _run(sim, 2.0, Vector2.ZERO)
		out.append({"seen": seen, "alive": _alive(sim, 0), "tanks": sim.tanks_destroyed})
	var with: Dictionary = out[1]["seen"]
	check(
		with.has("grab") and with.has("throw_land") and Num.i(out[1]["tanks"]) == 1,
		"a limb grabs the tank and throws it only with Grab and Throw: %s" % [with.keys()]
	)
	check(
		Num.i(out[1]["alive"]) < Num.i(out[0]["alive"]),
		"the thrown tank blasts the building it lands on (%d vs %d standing)"
		% [Num.i(out[1]["alive"]), Num.i(out[0]["alive"])]
	)


## Corrosive Ink: E coats everything around; coated chunks dissolve over seconds and coated
## tanks die.
func _check_ink() -> void:
	var ring: Array[Dictionary] = [_b(4, 0, 3, 3, 4, 2), _b(-4, 0, 3, 3, 4, 2)]
	var out: Array[Dictionary] = []
	for levels: Dictionary in [{}, {"c_ink": 1}]:
		var sim := _sim("cephalopod", levels, ring, Vector2(0, 0))
		var tank := RampageSim.Tank.new()
		tank.id = 900
		tank.hp = 60.0
		tank.cooldown = 99.0
		tank.pos = Vector2(0, 3.5)
		sim.tanks.append(tank)
		_run(sim, 0.5, Vector2.ZERO, false, false, true)
		var early := sim.chunks_destroyed
		_run(sim, 3.5, Vector2.ZERO)
		out.append({"early": early, "late": sim.chunks_destroyed, "tanks": sim.tanks_destroyed})
	check(
		Num.i(out[1]["late"]) > Num.i(out[1]["early"]) + 5,
		"ink keeps dissolving coated chunks (%d to %d)"
		% [Num.i(out[1]["early"]), Num.i(out[1]["late"])]
	)
	check(
		Num.i(out[1]["late"]) > Num.i(out[0]["late"]) and Num.i(out[1]["tanks"]) == 1,
		"ink beats no ink (%d vs %d chunks) and kills the coated tank"
		% [Num.i(out[1]["late"]), Num.i(out[0]["late"])]
	)


## Helicopters (D-037): they come once the city is burning, circle and strafe; a young kaiju
## cannot reach them, a grown one swats them on their strafing dives, and a cephalopod
## plucks them out of the air.
func _check_helicopters() -> void:
	var calm := _sim("reptilian", {}, [], Vector2(0, 0))
	_run(calm, 15.0, Vector2.ZERO)
	check(calm.air.helis.is_empty(), "no helicopters before the city has been hurt")
	var young := _sim("reptilian", {}, [], Vector2(0, 0))
	var heli := young.air.spawn()
	var start := heli.pos
	var seen := _run(young, 8.0, Vector2.ZERO)
	check(
		heli.pos.distance_to(start) > 1.0 and seen.has("heli_fired") and young.hp < young.max_hp,
		"a helicopter circles and strafes the kaiju (%d bursts)" % Num.i(seen.get("heli_fired", 0))
	)
	check(heli.hp > 0.0, "a young kaiju's stomps cannot reach a helicopter")
	var grown := _sim("reptilian", {"evolve1": 1, "claws": 5, "hide": 5}, [], Vector2(0, 0))
	grown.air.spawn()
	var swatted := _run(grown, 12.0, Vector2.ZERO)
	check(
		swatted.has("heli_destroyed"),
		"a grown kaiju (reach %.1f) swats a diving helicopter" % grown.reach_top()
	)
	var octo := _sim("cephalopod", {"c_grab": 1}, [_b(0, -7, 3, 3, 3)], Vector2(0, 0))
	octo.air.spawn()
	var grabbed := false
	for i: int in 30 * 8:
		for event: Dictionary in octo.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "grab" and str(event["kind"]) == "heli":
				grabbed = true
	check(grabbed, "a cephalopod plucks a helicopter out of the sky")


## A full autoplayed rampage with every branch bought replays identically for each species.
func _check_replay() -> void:
	var full := {
		"reptilian": {"r_tail": 2, "r_momentum": 2, "r_shear": 1, "r_beam": 1},
		"insectoid": {"i_scuttle": 2, "i_glide": 1, "i_climb": 1, "i_brood": 1},
		"cephalopod": {"c_hydra": 2, "c_squeeze": 1, "c_grab": 1, "c_ink": 1},
	}
	var same := true
	for species_id: String in full:
		var runs: Array[Dictionary] = []
		for n: int in 2:
			var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
			var species := Content.species_def(species_id)
			var levels: Dictionary = full[species_id]
			var tree := UpgradeTree.new(Content.upgrades(), levels, species_id)
			var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
			var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 3))
			var ability: Dictionary = species["ability"]
			sim.ability_type = str(ability["type"])
			var target := Vector2(INF, INF)
			for i: int in 30 * 30:
				if i % 15 == 0:
					target = sim.nearest_standing(sim.kaiju_pos)
				var move := Vector2.ZERO
				if target.x < INF:
					move = (target - sim.kaiju_pos).normalized()
				sim.step(DT, move, sim.ability_ready_in <= 0.0, i % 40 < 20, true)
			runs.append(sim.result())
		same = same and runs[0] == runs[1]
	check(same, "every species' full branch replays identically from the same seed")
