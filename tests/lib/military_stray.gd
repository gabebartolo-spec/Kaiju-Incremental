extends RefCounted
## The clumsy military (StrayShell; director, comments #18): tank shells miss the kaiju at the
## seeded rate the data sets, a miss lands in the city and breaks what it hits, never a tank, and
## the same seed gives the same shots, misses and landings; what a stray breaks counts for the
## kaiju in full (D-157). Part of the military suite.
## Seeded by design: every rampage takes Seeds.make("city"/"army", seed).

const DT := 1.0 / 15.0
const STEPS := 600
## The Colossus city, the strongest army left (D-135): the tanks fire often enough to count.
const TIER := 3
## Re-probed for D-135: seed 4 saw no tank shot in the Colossus city; 0-3, 5 and 6 all pass.
const SEED := 0
const SHOTS := 400
## How far the miss share may sit from the data's on SHOTS seeded shells (2.5 sigma at 40%).
const RATE_SLACK := 0.06
## How far the damage of SHOTS shells may sit from SHOTS sure hits' (3 sigma at a 60% chance).
const DAMAGE_SLACK := 0.12

var _check: Callable
var _make: Callable
var _play: Callable


## check: the runner's check; make(tier, seed) -> RampageSim; play(sim, steps, target) -> target.
func _init(p_check: Callable, make: Callable, play: Callable) -> void:
	_check = p_check
	_make = make
	_play = play


func run() -> void:
	for at_reach: float in [0.1, 1.0]:
		_rate_and_damage(at_reach)
	var first := _rampage()
	var again := _rampage()
	(
		_check
		. call(
			Num.i(first["misses"]) > 0 and first == again,
			(
				(
					"an autoplayed rampage misses (%d of %d shots) and the same seed gives the same shots,"
					+ " misses, landings and damage"
				)
				% [Num.i(first["misses"]), Num.i(first["shots"])]
			)
		)
	)
	_lands_on_a_building()
	_counts_as_destruction()


## SHOTS shells from at_reach x the tanks' reach: they miss at the data's rate there
## (StrayShell.chance), and the kaiju takes what SHOTS sure hits did before (hit damage / chance).
func _rate_and_damage(at_reach: float) -> void:
	var sim: RampageSim = _make.call(1, 0)
	var reach := Num.f(sim.army["range"]) + sim.stomp_radius()
	var dist := reach * at_reach
	var tank := RampageSim.Tank.new()
	tank.pos = sim.kaiju_pos + Vector2(dist, 0.0)
	var hp := sim.hp
	for n: int in SHOTS:
		sim.army_units.shoot(tank, dist, reach)
	var odds := StrayShell.chance(sim.army, dist, reach)
	var share := float(sim.army_units.misses) / SHOTS
	var sure := Num.f(sim.army["tank_damage"]) - sim.stat("armor")
	var expected := SHOTS * maxf(Num.f(sim.army["min_damage"]), sure)
	var taken := hp - sim.hp
	_check.call(
		absf(share - (1.0 - odds)) <= RATE_SLACK,
		(
			"at %.0f%% of reach %.0f%% of %d shells miss (the data's %.0f%%)"
			% [at_reach * 100.0, share * 100.0, SHOTS, (1.0 - odds) * 100.0]
		)
	)
	_check.call(
		absf(taken - expected) <= expected * DAMAGE_SLACK,
		(
			"at %.0f%% of reach the kaiju takes %.0f from %d shells, as %d sure hits did (%.0f)"
			% [at_reach * 100.0, taken, SHOTS, SHOTS, expected]
		)
	)


## A shell landed on a building breaks chunks of it and hurts no tank.
func _lands_on_a_building() -> void:
	var sim: RampageSim = _make.call(1, 0)
	for n: int in 300:  # until the first tanks are in the city
		sim.step(DT, Vector2.ZERO, false)
	var target := -1
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.in_arena and b.frame.alive_count > 0 and b.height >= 2:
			target = i
			break
	var b := sim.buildings[target]
	var before := b.frame.alive_count
	var paid := sim.chunks_destroyed
	var tank_hp := 0.0
	for tank: RampageSim.Tank in sim.tanks:
		tank_hp += tank.hp
	StrayShell.land(sim, Vector2(b.x, b.z))
	var after := 0.0
	for tank: RampageSim.Tank in sim.tanks:
		after += tank.hp
	_check.call(
		sim.chunks_destroyed > paid and is_equal_approx(after, tank_hp),
		(
			"a stray shell on building %d breaks %d of its chunks (%d standing before) and no tank"
			% [target, sim.chunks_destroyed - paid, before]
		)
	)


## D-157 (director, 2026-10-23): a missed shell that smashes part of a building counts in full. A
## real shell through Army.shoot and its flight, beside a standing building one chunk short of the
## first helicopter: the kaiju earns the biomass (rubble), the city's ruin rises, and the army
## escalates as usual (the tanks' threat grows and the stray's chunks call the first helicopter in).
func _counts_as_destruction() -> void:
	var sim: RampageSim = _make.call(2, 0)
	var after := Num.i(sim.air.cfg["after_chunks"])
	var target := -1
	for i: int in sim.buildings.size():  # a tier-1 building: one shell breaks its chunks
		var b := sim.buildings[i]
		if b.in_arena and b.frame.alive_count > 0 and b.height >= 2 and b.tier == 1:
			target = i
			break
	var b := sim.buildings[target]
	sim.kaiju_pos = Vector2(b.x + b.w * 0.5 + 6.0, b.z)
	sim.chunks_destroyed = after - 1
	var biomass := sim.rubble
	var ruin := sim.destruction()
	var threat := sim.army_units.threat_scale()
	var helis := sim.air.cap()
	var tank := RampageSim.Tank.new()
	tank.pos = sim.kaiju_pos + Vector2(8.0, 0.0)
	var reach := Num.f(sim.army["range"]) + sim.stomp_radius()
	var shots := 0
	while sim.army_units.misses == 0 and shots < 200:
		sim.army_units.shoot(tank, 8.0, reach)
		shots += 1
	var flying: Dictionary = sim.army_units._strays[0]
	flying["at"] = Vector2(b.x, b.z)  # where it lands is random: this test is about what it earns
	sim.events.clear()
	sim.army_units.step(Num.f(sim.army["shell_flight"]) + DT)
	var landed := sim.events.any(
		func(e: Dictionary) -> bool: return str(e["type"]) == "stray_landed"
	)
	_check.call(
		landed and sim.chunks_destroyed > after - 1 and sim.rubble > biomass,
		(
			"a stray shell (shot %d) that breaks %d chunks pays the kaiju: biomass %.1f -> %.1f"
			% [shots, sim.chunks_destroyed - (after - 1), biomass, sim.rubble]
		)
	)
	_check.call(
		sim.destruction() > ruin,
		"and the city's ruin rises: %.5f -> %.5f of the city" % [ruin, sim.destruction()]
	)
	_check.call(
		sim.army_units.threat_scale() > threat and sim.air.cap() > helis,
		(
			"and the army escalates: threat x%.4f -> x%.4f, helicopters allowed %d -> %d"
			% [threat, sim.army_units.threat_scale(), helis, sim.air.cap()]
		)
	)


## One autoplayed rampage: shots at the kaiju, misses, where each landed and the kaiju's health
## at the end (a digest of the run).
func _rampage() -> Dictionary:
	var sim: RampageSim = _make.call(TIER, SEED)
	var target := Vector2(INF, INF)
	var shots := 0
	var misses := 0
	var landed: Array[Vector2] = []
	for steps: int in STEPS:
		if sim.over:
			break
		target = _play.call(sim, steps, target)
		for e: Dictionary in sim.events:
			if str(e["type"]) != "tank_fired":
				continue
			if e.get("miss", false):
				misses += 1
				landed.append(e["at"])
			if not e.has("at") or e.get("miss", false):
				shots += 1
	return {"shots": shots, "misses": misses, "landed": landed, "hp": snappedf(sim.hp, 0.001)}
