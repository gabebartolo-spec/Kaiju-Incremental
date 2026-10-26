extends "res://tests/lib/runner.gd"
## Death suite (director 2026-10-26, every kaiju: "overloaded with kaiju energy, crackling up,
## turning them to stone then exploding into shards"; DeathOverload). A death (killed, time's up,
## End rampage) staggers, turns to stone and shatters at the data's times before the run ends; the
## shards smash what they land on; the Death Blast nodes (1, 2, 3) wreck more and pay more each
## step through the normal destruction path; the city's fall still ends at once; the nodes ride the
## save. Seeded by design: hand-placed buildings, Seeds "army" 0, the kaiju parked at the centre.
##   godot --headless --path . --script tests/run_death_tests.gd

const DT := 1.0 / 15.0
const BANNED: Array[String] = ["Time.", "OS.", "randomize", "Node", "await"]
const SAVE_SLOT := 3


func suite_name() -> String:
	return "Death"


func run_checks() -> void:
	await _t("_check_pure")
	await _t("_check_sequence")
	await _t("_check_shards_smash")
	await _t("_check_blast_steps")
	await _t("_check_deaths_and_falls")
	await _t("_check_replay")
	await _t("_check_nodes_saved")


## A carpet of low 2x2 blocks round the centre (where the shards come down) and rings of taller
## ones at 12, 17 and 22 (where the blast's ring reaches) and 42 (past it).
func _layout() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for gx: int in range(-5, 6):
		for gz: int in range(-5, 6):
			var p := Vector2(gx, gz) * 2.2
			if p.length() > 4.0 and p.length() <= 10.0:
				out.append({"x": p.x, "z": p.y, "w": 2, "d": 2, "h": 4, "tier": 1, "style": 0})
	for ring: float in [12.0, 17.0, 22.0, 42.0]:
		for k: int in 12:
			var p := Vector2.from_angle(TAU * k / 12.0) * ring
			out.append({"x": p.x, "z": p.y, "w": 3, "d": 3, "h": 8, "tier": 1, "style": 0})
	return out


func _sim(blast_nodes: int, tree_levels: Dictionary = {}) -> RampageSim:
	var tree := UpgradeTree.new(Content.upgrades(), tree_levels, "reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def("reptilian"), tree
	)
	if tree_levels.is_empty():
		stats["death_blast"] = blast_nodes
	var sim := RampageSim.new(stats, Content.tuning(), _layout(), Seeds.make("army", 0))
	sim.ability_type = "leap"
	sim.body.use_species("reptilian")
	sim.kaiju_pos = Vector2.ZERO
	return sim


## Kills him (hp below zero) and steps until the run is over; every event, in order.
func _die(sim: RampageSim) -> Array[Dictionary]:
	sim.hp = -sim.max_hp
	var out: Array[Dictionary] = []
	for _s: int in int(30.0 / DT):
		out.append_array(sim.step(DT, Vector2.ZERO, false))
		if sim.over:
			break
	return out


func _of(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return str(e["type"]) == type)


func _index(events: Array[Dictionary], type: String) -> int:
	for i: int in events.size():
		if str(events[i]["type"]) == type:
			return i
	return -1


func _check_pure() -> void:
	var src := FileAccess.get_file_as_string("res://sim/death_overload.gd")
	for word: String in BANNED:
		check(not src.contains(word), "death_overload.gd has no %s" % word)
	# The deaths the overload plays for are the deaths the save counts (SaveFile.DEATHS, D-263).
	var reasons: Array = Content.section("death")["reasons"]
	var deaths: Array = SaveFile.DEATHS.duplicate()
	reasons = reasons.duplicate()
	reasons.sort()
	deaths.sort()
	check(reasons == deaths, "death.reasons %s match SaveFile.DEATHS %s" % [reasons, deaths])


## Stagger, stone, shatter at the data's times, in that order; the run ends only after the last
## shard is down (the results wait for the burst), as a defeat, with nothing moving him meanwhile.
func _check_sequence() -> void:
	var cfg: Dictionary = Content.section("death")
	var sim := _sim(0)
	sim.hp = -sim.max_hp
	var events := sim.step(DT, Vector2.ZERO, false)  # he dies on this step, standing still
	var times: Dictionary = {"death_begin": DT} if not _of(events, "death_begin").is_empty() else {}
	var at := sim.kaiju_pos
	var elapsed := DT
	var last_shard := -1
	for _s: int in int(30.0 / DT):
		var now := sim.step(DT, Vector2(1, 0), true, RampageSim.ULTIMATE)  # a stick and buttons
		elapsed += DT
		for e: Dictionary in now:
			times[str(e["type"])] = times.get(str(e["type"]), elapsed)
			last_shard = events.size() if str(e["type"]) == "death_shard" else last_shard
			events.append(e)
		if sim.over:
			break
	var stagger := Num.f(cfg["stagger_s"])
	var stone := Num.f(cfg["stone_s"])
	check(
		times.has("death_begin") and Num.f(times["death_begin"]) <= DT, "he starts to die at once"
	)
	check(
		absf(Num.f(times.get("death_stone", -1.0)) - stagger) <= DT * 1.5,
		"the stone comes after the stagger (%.2f s): %s" % [stagger, times.get("death_stone")]
	)
	check(
		absf(Num.f(times.get("death_shatter", -1.0)) - stagger - stone) <= DT * 1.5,
		"he shatters after the stone (%.2f s): %s" % [stagger + stone, times.get("death_shatter")]
	)
	var shards := _of(events, "death_shard")
	check(shards.size() == Num.i(cfg["shards"]), "every shard lands: %d" % shards.size())
	check(
		sim.over and _index(events, "run_over") > last_shard,
		"the run ends after the last shard is down"
	)
	check(sim.end_reason == "defeated", "it ends as a defeat: %s" % sim.end_reason)
	check(sim.kaiju_pos == at, "a dying kaiju takes no input: %s" % sim.kaiju_pos)
	check(_of(events, "ability").is_empty(), "nor fires his powers")


## Each shard that lands on a building breaks some of it; with no node, the shards alone pay.
func _check_shards_smash() -> void:
	var sim := _sim(0)
	sim.hp = -sim.max_hp
	var events: Array[Dictionary] = []
	var before: Array[int] = []  # read the step he shatters, before any shard is down
	for _s: int in int(30.0 / DT):
		events.append_array(sim.step(DT, Vector2.ZERO, false))
		if before.is_empty() and not _of(events, "death_shatter").is_empty():
			for b: RampageSim.Building in sim.buildings:
				before.append(b.frame.alive_count)
		if sim.over:
			break
	var hit := 0
	var broke := 0
	for e: Dictionary in _of(events, "death_shard"):
		var p := Vector2(Num.f(e["x"]), Num.f(e["z"]))
		for i: int in sim.buildings.size():
			var b := sim.buildings[i]
			var inside := (
				absf(p.x - b.x) <= b.w * 0.5 - 0.25 and absf(p.y - b.z) <= b.d * 0.5 - 0.25
			)
			if before[i] > 0 and inside:  # standing when he shattered, the shard well inside it
				hit += 1
				broke += 1 if b.frame.alive_count < before[i] else 0
	check(hit >= 5, "shards come down on the blocks round him: %d" % hit)
	check(broke == hit, "every block a shard lands on is broken: %d of %d" % [broke, hit])
	check(sim.death.shard_chunks > 0, "the shards break chunks: %d" % sim.death.shard_chunks)
	check(sim.death.blast_chunks == 0, "no node, no blast")


## 0, 1, 2, 3 Death Blast nodes: a ring round his body, his edge plus 5 / 10 / 15 (director
## 2026-10-26, "Smaller: a ring round his body"); every building inside it is wiped, nothing past
## it or his shards is touched, and each step out breaks more and pays more biomass (the same seed;
## the blast goes through hit_area, so it pays as any blow does).
func _check_blast_steps() -> void:
	var cfg: Dictionary = Content.section("death")
	var chunks: Array[int] = []
	var pay: Array[float] = []
	var control: Array[int] = []  # what stands after a death with no node (the shards alone)
	for nodes: int in 4:
		var sim := _sim(nodes)
		var rubble := sim.rubble
		_die(sim)
		chunks.append(sim.death.shard_chunks + sim.death.blast_chunks)
		pay.append(sim.rubble - rubble)
		var want := sim.death.body_edge() + nodes * Num.f(cfg["per_node"]) if nodes > 0 else 0.0
		check(
			is_equal_approx(sim.death.blast_radius, want),
			"%d nodes: the ring reaches %.1f (got %.1f)" % [nodes, want, sim.death.blast_radius]
		)
		var standing_inside := 0
		var touched_past := 0
		for i: int in sim.buildings.size():
			var b := sim.buildings[i]
			if nodes == 0:
				control.append(b.frame.alive_count)
				continue
			var centre := Vector2(b.x, b.z).length()
			var half := Vector2(b.w, b.d).length() * 0.5
			if centre + half <= want and b.frame.alive_count > 0:
				standing_inside += 1
			if centre - half > want + 1.0 and b.frame.alive_count != control[i]:
				touched_past += 1
		check(standing_inside == 0, "%d nodes: inside the ring nothing stands" % nodes)
		check(touched_past == 0, "%d nodes: past the ring nothing is touched" % nodes)
	for n: int in range(1, 4):
		check(chunks[n] > chunks[n - 1], "%d nodes break more than %d: %s" % [n, n - 1, chunks])
		check(pay[n] > pay[n - 1], "%d nodes pay more biomass than %d: %s" % [n, n - 1, pay])


## Time's up and End rampage are deaths too (D-263, D-265); the city's fall ends at once.
func _check_deaths_and_falls() -> void:
	var timed := _sim(0)
	timed.time_left = 0.0
	var events := _die_by(timed, func() -> void: pass)
	check(timed.end_reason == "time" and not _of(events, "death_shatter").is_empty(), "time's up")
	var ended := _sim(0)
	ended.end("ended")
	events = _die_by(ended, func() -> void: pass)
	check(
		ended.end_reason == "ended" and not _of(events, "death_shatter").is_empty(), "End rampage"
	)
	var fallen := _sim(0)
	fallen.chunks_destroyed = fallen.chunks_total
	var first := fallen.step(DT, Vector2.ZERO, false)
	check(
		fallen.over and fallen.end_reason == "city_fallen" and not fallen.death.active(),
		"the city's fall ends the run at once, no death: %s" % [_of(first, "run_over")]
	)


func _die_by(sim: RampageSim, each: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for _s: int in int(30.0 / DT):
		each.call()
		out.append_array(sim.step(DT, Vector2.ZERO, false))
		if sim.over:
			break
	return out


## The same seed replays the same death: shards, landings, chunks, biomass.
func _check_replay() -> void:
	var a := _sim(2)
	var b := _sim(2)
	var ea := _die(a)
	var eb := _die(b)
	check(_of(ea, "death_shatter") == _of(eb, "death_shatter"), "the same shards fly")
	check(_of(ea, "death_shard") == _of(eb, "death_shard"), "and land in the same places")
	check(a.rubble == b.rubble and a.chunks_destroyed == b.chunks_destroyed, "and pay the same")


## Bought nodes ride the save: three bought, saved, loaded: the node 3 ring.
func _check_nodes_saved() -> void:
	var tree := UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	for id: String in ["claws", "hide", "rage", "evolve1", "sig_power", "sig_recharge"]:
		tree.levels[id] = 1
	var bought := 0
	for id: String in ["death_blast1", "death_blast2", "death_blast3"]:
		bought += 1 if tree.buy(id, 1000000) > 0 else 0
	check(bought == 3, "the three nodes can be bought in order: %d" % bought)
	var save := SaveFile.new_save("reptilian")
	save["levels"] = tree.levels.duplicate()
	SaveFile.save_game(save, SAVE_SLOT)
	var back: Dictionary = SaveFile.load_game(SAVE_SLOT).get("levels", {})
	check(Num.i(back.get("death_blast3", 0)) == 1, "the save keeps them: %s" % back)
	var sim := _sim(0, back)
	_die(sim)
	var want := sim.death.body_edge() + 3.0 * Num.f(Content.section("death")["per_node"])
	check(
		is_equal_approx(sim.death.blast_radius, want),
		"a loaded save blasts the node 3 ring: %.1f" % sim.death.blast_radius
	)
	SaveFile.delete_save(SAVE_SLOT)
