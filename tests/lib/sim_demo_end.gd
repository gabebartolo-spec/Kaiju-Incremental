extends RefCounted
## The sim suite's demo-end checks (D-145, D-152, D-156): the final upgrade ends the demo, the
## thanks screen's totals against the sim's counters at a pinned seed, and Endless mode (no clock,
## no fall, waves that keep coming and grow with the city, a cap on the tanks alive, a share of the
## ruins regrowing) leaving normal mode's results identical. Seeded by design: every run takes
## Seeds.make("army"/"city", 0).

const DT := 1.0 / 30.0
const FREE_SECONDS := 420
const EARLY_SECONDS := 60
## Seconds beyond the regrowth interval the check runs (the kaiju first rises from the river).
const REGROW_SLACK := 12

var _check: Callable
var _make: Callable
var _autoplay: Callable


## check: the runner's check; make(species, levels, run_index, tuning) -> RampageSim;
## autoplay(sim) -> result (the sim suite's scripted player).
func _init(p_check: Callable, make: Callable, autoplay: Callable) -> void:
	_check = p_check
	_make = make
	_autoplay = autoplay


func run() -> void:
	_check_complete()
	_check_totals()
	_check_endless()
	_check_regrowth()
	_check_regrow_state()
	_check_scaling()
	_check_normal_untouched()
	_check_save()


## The demo ends on the final upgrade: every node of the tree owned, read from the data.
func _check_complete() -> void:
	var levels: Dictionary = {}
	var defs: Array = Content.upgrades()
	for def: Dictionary in defs:
		if not def.has("species") or def["species"] == "reptilian":
			levels[str(def["id"])] = Num.i(def["max_level"])
	var full := UpgradeTree.new(defs, levels, "reptilian")
	_check.call(Demo.complete(full), "a tree with every node owned completes the demo")
	var short := levels.duplicate()
	var last := str(defs[defs.size() - 1]["id"])
	for def: Dictionary in defs:
		if not (def.has("species") and def["species"] != "reptilian"):
			last = str(def["id"])
	short[last] = Num.i(short[last]) - 1
	_check.call(
		not Demo.complete(UpgradeTree.new(defs, short, "reptilian")),
		"one level short does not (%s)" % last
	)
	var demo := Content.section("demo")
	demo["enabled"] = false
	_check.call(not Demo.complete(full), "with the demo off nothing ends it")
	demo["enabled"] = true


## The totals are the sim's counters, summed (Demo.add), at a pinned seed.
func _check_totals() -> void:
	var sim: RampageSim = _make.call("reptilian", {"claws": 3, "hide": 2}, 0, {})
	var result: Dictionary = _autoplay.call(sim)
	result = result.merged({"civilians": 7, "fled": 3})
	var totals := Demo.add({}, result)
	# Recounted from the chunk mirror (the sim's ruin rule: a building is gone once each chunk is at
	# most half its cells), apart from the fine grids; the seed leaves stubs, so the two differ.
	var gone := 0
	var fine_empty := 0
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var f := sim.carving.frame(i)
		if b.in_arena and b.frame.alive_count == 0:
			gone += 1
			if f != null and f.alive_count == 0:
				fine_empty += 1
	var military := (
		sim.tanks_destroyed
		+ sim.air.destroyed
		+ sim.army_units.rooftops_destroyed
		+ sim.army_units.taskforce.kills
	)
	_check.call(
		Num.i(totals["biomass"]) == Num.i(floor(sim.rubble)) and Num.i(totals["biomass"]) > 0,
		"biomass earned is the sim's rubble: %s vs %d" % [totals["biomass"], floor(sim.rubble)]
	)
	_check.call(
		Num.i(totals["military"]) == military,
		(
			"military destroyed is tanks + helicopters + rooftop squads + Taskforce agents (%d)"
			% military
		)
	)
	(
		_check
		. call(
			Num.i(totals["buildings"]) == gone and gone > fine_empty and fine_empty > 0,
			(
				"buildings destroyed are the ruined ones by the sim's rule (%d), not the no-cell-left ones (%d)"
				% [gone, fine_empty]
			)
		)
	)
	_check.call(
		Num.i(totals["seconds"]) == floori(sim.elapsed) and sim.elapsed > 1.0,
		"time played is the sim's elapsed seconds (%.1f)" % sim.elapsed
	)
	_check.call(
		Num.i(totals["eaten"]) == 7 and Num.i(totals["fled"]) == 3,
		"people eaten and fled are the view's counts"
	)
	var fixed := Demo.add({}, {"tanks": 2, "helis": 3, "rooftops": 4, "agents": 5})
	_check.call(
		Num.i(fixed["military"]) == 14, "every unit type counts as military destroyed: %s" % [fixed]
	)
	var twice := Demo.add(totals, result)
	_check.call(
		Num.i(twice["military"]) == 2 * military and Demo.rows(twice).size() == 6,
		"a second rampage adds to the totals; the screen has six rows"
	)


## Endless mode: no clock, no fall, waves keep coming, never more tanks alive than the cap.
func _check_endless() -> void:
	var sim: RampageSim = _make.call("reptilian", {"hide": 3}, 0, {})
	sim.endless = Endless.new()
	var cap := Num.i(Endless.cfg()["max_tanks"])
	var spawned_early := 0
	var spawned_late := 0
	var peak := 0
	for step: int in FREE_SECONDS * 30:
		sim.hp = sim.max_hp  # an invincible kaiju: only the clock and the fall could end it
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "tank_spawned":
				if step < EARLY_SECONDS * 30:
					spawned_early += 1
				elif step >= (FREE_SECONDS - EARLY_SECONDS) * 30:
					spawned_late += 1
		peak = maxi(peak, sim.tanks.size())
		if step % 90 == 0 and sim.tanks.size() > 0:
			sim.tanks[0].hp = 0.0  # the kaiju eats one now and then
			sim.army_units.clear_dead()
	_check.call(
		not sim.over and sim.time_left < 0.0,
		"endless runs on past the clock (over %s, clock %.0f)" % [sim.over, sim.time_left]
	)
	_check.call(spawned_early > 0, "endless fields tanks in its first minute (%d)" % spawned_early)
	_check.call(
		spawned_late > 0,
		(
			"endless is still sending waves after %d s (%d in the last minute)"
			% [FREE_SECONDS, spawned_late]
		)
	)
	_check.call(peak <= cap, "never more than %d tanks alive at once (peak %d)" % [cap, peak])
	_check.call(
		sim.air.helis.size() > 0 and Endless.escalation(sim) > 0,
		"the air wing is up in endless (%d)" % sim.air.helis.size()
	)
	var control: RampageSim = _make.call("reptilian", {"hide": 3}, 0, {})
	control.time_left = 1.0
	for i: int in 300:  # the clock, then his death plays out (DeathOverload)
		control.hp = control.max_hp
		control.step(DT, Vector2.ZERO, false)
	_check.call(
		control.over and control.end_reason == "time", "a normal rampage still ends on the clock"
	)


## Flattens building `i` (every chunk gone) and books its chunks as destroyed.
func _flatten(sim: RampageSim, i: int) -> int:
	var b := sim.buildings[i]
	for y: int in b.height:
		for z: int in b.d:
			for x: int in b.w:
				b.frame.damage(Vector3i(x, y, z), 1.0e9)
	var full := b.w * b.d * b.height
	sim.chunks_destroyed += full
	return full


## The plain arena buildings, farthest from the kaiju first.
func _far_plain(sim: RampageSim) -> Array[int]:
	var ids: Array[int] = []
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.landmark == "" and b.in_arena:
			ids.append(i)
	var from := sim.kaiju_pos
	ids.sort_custom(
		func(a: int, c: int) -> bool:
			var pa := Vector2(sim.buildings[a].x, sim.buildings[a].z)
			var pc := Vector2(sim.buildings[c].x, sim.buildings[c].z)
			return pa.distance_to(from) > pc.distance_to(from)
	)
	return ids


## Flattened buildings far from the kaiju come back at about regrow_share_per_minute a minute.
func _check_regrowth() -> void:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	sim.endless = Endless.new()
	var ruins: Array[int] = []
	ruins.assign(_far_plain(sim).slice(0, 400))
	for i: int in ruins:
		_flatten(sim, i)
	_check.call(sim.endless.regrowable(sim, ruins[0]), "a flattened far building may regrow")
	var minutes := 3
	var regrown_events := 0
	for _step: int in minutes * 60 * 30:
		sim.hp = sim.max_hp
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "building_regrown":
				regrown_events += 1
	var share := Num.f(Endless.cfg()["regrow_share_per_minute"])
	var expected := float(ruins.size()) * share * minutes
	_check.call(
		regrown_events > 0 and absf(regrown_events - expected) <= expected * 0.35 + 1.0,
		(
			"about %.0f%% of %d ruins a minute come back: %d in %d min (near %.0f)"
			% [share * 100.0, ruins.size(), regrown_events, minutes, expected]
		)
	)
	_check.call(
		sim.endless.regrown == regrown_events,
		(
			"each regrowth is announced once (%d events, %d counted)"
			% [regrown_events, sim.endless.regrown]
		)
	)
	var one: int = ruins[0]
	for i: int in ruins:
		if sim.buildings[i].frame.alive_count == 0:
			one = i
			break
	var b := sim.buildings[one]
	var full := b.w * b.d * b.height
	var before := sim.chunks_destroyed
	sim.endless.regrow(sim, one)
	_check.call(
		sim.chunks_destroyed == maxi(0, before - full) and b.frame.alive_count == full,
		(
			"regrowing stands it whole and takes its chunks back (%d -> %d, building of %d)"
			% [before, sim.chunks_destroyed, full]
		)
	)


## A regrown building is new in every way the sim tracks: it can catch fire again, pays a full
## smash, and may topple (and count) again.
func _check_regrow_state() -> void:
	var sim: RampageSim = _make.call("reptilian", {"r_ablaze": 1}, 0, {})
	sim.endless = Endless.new()
	var i := _far_plain(sim)[0]
	var fire: FireSpread = sim.powers.fire
	_flatten(sim, i)
	fire.state[i] = FireSpread.State.BURNT
	fire.heat[i] = 1.0
	sim.buildings[i].pay_share = 0.15
	sim.collapse._toppled_ids[i] = true
	sim.endless.regrow(sim, i)
	_check.call(
		(
			fire.state[i] == FireSpread.State.INTACT
			and fire.heat[i] == 0.0
			and sim.buildings[i].pay_share == 1.0
		),
		(
			"a regrown building has no fire state or reduced pay left (state %d, pay %.2f)"
			% [fire.state[i], sim.buildings[i].pay_share]
		)
	)
	fire.ignite(i)
	_check.call(
		fire.state[i] == FireSpread.State.BURNING,
		"and it catches fire again (state %d)" % fire.state[i]
	)
	_check.call(not sim.collapse._toppled_ids.has(i), "and may topple and count once more")


## The escalation follows the city's chunk total and never stops growing.
func _check_scaling() -> void:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	sim.endless = Endless.new()
	var marks: Array[int] = []
	for t: float in [0.0, 60.0, 600.0, 6000.0, 60000.0]:
		sim.elapsed = t
		marks.append(Endless.escalation(sim))
	var rising := true
	for k: int in range(1, marks.size()):
		rising = rising and marks[k] > marks[k - 1]
	_check.call(rising, "the endless escalation rises for ever, with no cap: %s" % [marks])
	sim.elapsed = 600.0
	var late := Endless.escalation(sim)
	_check.call(
		late > sim.chunks_total,
		(
			"ten minutes in it is worse than a city's whole ruin (%d vs %d chunks)"
			% [late, sim.chunks_total]
		)
	)
	var twice: RampageSim = _make.call("reptilian", {}, 0, {})
	twice.endless = Endless.new()
	twice.chunks_total = sim.chunks_total * 2
	twice.elapsed = 600.0
	_check.call(
		absi(Endless.escalation(twice) - 2 * late) <= 2,
		(
			"a city twice the size escalates twice as hard (%d vs %d)"
			% [Endless.escalation(twice), late]
		)
	)


## Endless tuning never reaches normal mode: change every endless row, a normal seed replays
## the same.
func _check_normal_untouched() -> void:
	var first: Dictionary = _autoplay.call(_make.call("reptilian", {"claws": 3, "hide": 2}, 0, {}))
	var cfg := Endless.cfg()
	var saved := cfg.duplicate()
	var same := true
	# Every row zero (no escalation, no tanks) and every row high: a normal seed must not notice.
	for factor: float in [0.0, 7.0]:
		for key: String in saved:
			cfg[key] = Num.f(saved[key]) * factor
		var again: Dictionary = _autoplay.call(
			_make.call("reptilian", {"claws": 3, "hide": 2}, 0, {})
		)
		# The pinned seed fields no tank in its window, so the caps are asked of the sim directly.
		var probe: RampageSim = _make.call("reptilian", {"claws": 3, "hide": 2}, 0, {})
		same = (
			same
			and first == again
			and not Endless.tanks_full(probe)
			and Endless.escalation(probe) == 0
		)
	for key: String in saved:
		cfg[key] = saved[key]
	_check.call(same, "changing every endless row leaves a normal seed's results identical")
	_check.call(
		Num.i(first["tanks"]) + Num.i(first["buildings"]) > 0,
		"that normal run did something: %s" % [first]
	)


## A save that began in the demo never continues in the full game; v2 saves migrate.
func _check_save() -> void:
	var demo := Content.section("demo")
	var save := SaveFile.new_save("reptilian")
	save["demo"] = true
	_check.call(Demo.continues(save), "a demo save continues in the demo")
	demo["enabled"] = false
	_check.call(not Demo.continues(save), "a demo save does not continue in the full game")
	save["demo"] = false
	_check.call(Demo.continues(save), "a full-game save continues in the full game")
	demo["enabled"] = true
	var old := SaveFile.migrate({"version": 2, "species": "reptilian"})
	_check.call(
		(
			old["demo"] == false
			and old["demo_done"] == false
			and old["totals"] == {}
			and old["version"] == SaveFile.VERSION
		),
		"a v2 save migrates with the demo keys defaulted: %s" % [old]
	)
