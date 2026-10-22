extends RefCounted
## The sim suite's demo-end checks (D-145, D-152, D-156): the final upgrade ends the demo, the thanks
## screen's totals against the sim's counters at a pinned seed, and Endless mode (no clock, no fall,
## waves that keep coming, a cap on the tanks alive, the city regrowing) leaving normal mode's
## results identical. Seeded by design: every run takes Seeds.make("army"/"city", 0).

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
	_check.call(not Demo.complete(UpgradeTree.new(defs, short, "reptilian")), "one level short does not (%s)" % last)
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
	var standing := 0
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var f := sim.carving.frame(i)
		if b.in_arena and (f.alive_count if f != null else b.frame.alive_count) == 0:
			standing += 1
	var military := sim.tanks_destroyed + sim.air.destroyed + sim.army_units.rooftops_destroyed
	_check.call(
		Num.i(totals["biomass"]) == Num.i(floor(sim.rubble)) and Num.i(totals["biomass"]) > 0,
		"biomass earned is the sim's rubble: %s vs %d" % [totals["biomass"], floor(sim.rubble)]
	)
	_check.call(
		Num.i(totals["military"]) == military,
		"military destroyed is tanks + helicopters + rooftop squads (%d)" % military
	)
	_check.call(
		Num.i(totals["buildings"]) == standing and standing > 0,
		"buildings destroyed match a recount of the sim's frames (%d)" % standing
	)
	_check.call(
		Num.i(totals["seconds"]) == floori(sim.elapsed) and sim.elapsed > 1.0,
		"time played is the sim's elapsed seconds (%.1f)" % sim.elapsed
	)
	_check.call(
		Num.i(totals["eaten"]) == 7 and Num.i(totals["fled"]) == 3,
		"people eaten and fled are the view's counts"
	)
	var fixed := Demo.add({}, {"tanks": 2, "helis": 3, "rooftops": 4})
	_check.call(Num.i(fixed["military"]) == 9, "every unit type counts as military destroyed: %s" % [fixed])
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
		"endless is still sending waves after %d s (%d in the last minute)" % [FREE_SECONDS, spawned_late]
	)
	_check.call(peak <= cap, "never more than %d tanks alive at once (peak %d)" % [cap, peak])
	_check.call(
		sim.air.helis.size() > 0 and Endless.escalation(sim) > 0,
		"the air wing is up in endless (%d)" % sim.air.helis.size()
	)
	var control: RampageSim = _make.call("reptilian", {"hide": 3}, 0, {})
	control.time_left = 1.0
	for i: int in 60:
		control.hp = control.max_hp
		control.step(DT, Vector2.ZERO, false)
	_check.call(control.over and control.end_reason == "time", "a normal rampage still ends on the clock")


## A destroyed building far from the kaiju stands whole again after the regrowth interval.
func _check_regrowth() -> void:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	sim.endless = Endless.new()
	var far := 0
	var far_d := -1.0
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var d := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		if b.landmark == "" and b.in_arena and d > far_d:
			far = i
			far_d = d
	var b := sim.buildings[far]
	var full := b.w * b.d * b.height
	for y: int in b.height:
		for z: int in b.d:
			for x: int in b.w:
				b.frame.damage(Vector3i(x, y, z), 1.0e9)
	sim.chunks_destroyed += full
	_check.call(b.frame.alive_count == 0 and sim.endless.regrowable(sim, far), "the far building is a ruin that may regrow")
	var regrown_events := 0
	for _step: int in (int(Num.f(Endless.cfg()["regrow_interval"])) + REGROW_SLACK) * 30:
		sim.hp = sim.max_hp
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "building_regrown" and Num.i(event["building"]) == far:
				regrown_events += 1
	_check.call(
		regrown_events == 1 and sim.buildings[far].frame.alive_count == full,
		"after the regrowth interval it stands whole again, announced once (%d events)" % regrown_events
	)
	var before := sim.chunks_destroyed
	sim.endless.regrow(sim, far)
	_check.call(
		sim.chunks_destroyed == maxi(0, before - full),
		"regrowing takes the destroyed count back (%d -> %d, building of %d)" % [before, sim.chunks_destroyed, full]
	)


## Endless tuning never reaches normal mode: change every endless row, a normal seed replays the same.
func _check_normal_untouched() -> void:
	var first: Dictionary = _autoplay.call(_make.call("reptilian", {"claws": 3, "hide": 2}, 0, {}))
	var cfg := Endless.cfg()
	var saved := cfg.duplicate()
	for key: String in cfg:
		cfg[key] = Num.f(cfg[key]) * 7.0 + 1.0
	var second: Dictionary = _autoplay.call(_make.call("reptilian", {"claws": 3, "hide": 2}, 0, {}))
	for key: String in saved:
		cfg[key] = saved[key]
	_check.call(first == second, "changing every endless row leaves a normal seed's results identical")
	_check.call(Num.i(first["tanks"]) + Num.i(first["buildings"]) > 0, "that normal run did something: %s" % [first])


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
		old["demo"] == false and old["demo_done"] == false and old["totals"] == {} and old["version"] == SaveFile.VERSION,
		"a v2 save migrates with the demo keys defaulted: %s" % [old]
	)
