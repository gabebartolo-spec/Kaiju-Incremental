extends RefCounted
## The sim suite's rooftop defender checks (D-063), split out to keep the runner small: armed
## citizens on the taller roofs plink at the kaiju, a sting far below a tank shell; they die with
## their roof or under a splash, and pay biomass. Includes the player-effect fixture
## "army.rooftop": the same seeded Behemoth rampage with squads on and off.

const DT := 1.0 / 30.0
const MAX_STEPS := 30 * 400
## D-076: the seeded Behemoth fixture draws at least this many rooftop volleys a second over its
## run (1.55 with D-076a and #50; 0.29 with the old squads and interval).
const MIN_BEHEMOTH_VOLLEYS := 1.0

var _check: Callable
var _make: Callable
var _play: Callable


## check: the runner's check; make(species, levels, run_index, tuning) -> RampageSim;
## play(sim, max_steps) -> result (the runner's scripted autoplay).
func _init(p_check: Callable, make: Callable, play: Callable) -> void:
	_check = p_check
	_make = make
	_play = play


func run() -> void:
	var cfg: Dictionary = Content.section("army")["rooftop"]
	var caps: Array = cfg["max_by_tier"]
	var sim: RampageSim = _new({})
	var army := sim.army_units
	var placed := not army.squads.is_empty() and army.squads.size() <= Num.i(caps[0])
	for squad: Army.Squad in army.squads:
		var b := sim.buildings[squad.building]
		var top := b.frame.top_below(squad.cell.x, squad.cell.z, b.height)
		placed = placed and b.height >= Num.i(cfg["min_height"]) and squad.cell.y == top
	_check.call(
		placed,
		(
			"rooftop squads stand on the top chunk of roofs %d+ floors high, at most %d (%d)"
			% [Num.i(cfg["min_height"]), Num.i(caps[0]), army.squads.size()]
		)
	)
	_check.call(
		_squad_spots(sim) == _squad_spots(_new({})) and not army.squads.is_empty(),
		"the same seed places the same rooftop squads: %s" % [_squad_spots(sim)]
	)
	# Size tier scales the sting; it stays far below a tank shell at every tier.
	var tank := Num.f(Content.section("army")["tank_damage"])
	var grown := CityGrowth.tuning_for(Content.tuning(), 2)
	var behemoth: RampageSim = _new({"claws": 3, "hide": 3, "rage": 3, "evolve1": 1}, grown)
	var big_tank := Num.f(grown["army"]["tank_damage"])
	var sting := army.volley()
	var big_sting := behemoth.army_units.volley()
	_check.call(
		sting > 0.0 and big_sting > sting and sting < tank * 0.25 and big_sting < big_tank * 0.25,
		(
			"a volley is a sting scaled by size: young %.2f (tank %.0f), Behemoth %.2f (tank %.0f)"
			% [sting, tank, big_sting, big_tank]
		)
	)
	_check.call(
		behemoth.army_units.squads.size() <= Num.i(caps[1]),
		"a Behemoth city holds at most %d squads" % Num.i(caps[1])
	)
	if army.squads.is_empty():
		return
	# One squad, the kaiju in range: it fires volleys; out of range: it holds fire.
	var near := _one_squad(_new({}))
	near.kaiju_pos = near.army_units.squads[0].pos + Vector2(Num.f(cfg["range"]) * 0.5, 0)
	var far := _one_squad(_new({}))
	far.kaiju_pos = far.army_units.squads[0].pos + Vector2(Num.f(cfg["range"]) * 1.5, 0)
	var seconds := Num.f(cfg["fire_interval"]) * 2.0 + 0.1  # before the first tank (5 s)
	var near_shots := _steps_counting(near, seconds, "rooftop_fired")
	var far_shots := _steps_counting(far, seconds, "rooftop_fired")
	# Each volley stings for the young tier's damage, grown by the threat as its stomps break chunks.
	var lost := near.max_hp - near.hp
	_check.call(
		(
			near_shots >= 2
			and lost >= near_shots * sting - 0.001
			and lost <= near_shots * near.army_units.volley() + 0.001
		),
		"a squad in range fires a volley each interval (%d shots, %.2f hp)" % [near_shots, lost]
	)
	_check.call(
		far_shots == 0 and far.hp == far.max_hp,
		"a squad out of range holds fire (%d shots)" % far_shots
	)
	# Improvised, not drilled (D-076): one squad's shots come at ragged gaps, never a metronome.
	var ragged := _one_squad(_new({}))
	ragged.kaiju_pos = ragged.army_units.squads[0].pos + Vector2(Num.f(cfg["range"]) * 0.5, 0)
	var times: Array[float] = []
	for i: int in ceili(Num.f(cfg["fire_interval"]) * 8.0 / DT):
		for event: Dictionary in ragged.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "rooftop_fired":
				times.append(i * DT)
	var gaps: Array[float] = []
	for i: int in range(1, times.size()):
		gaps.append(times[i] - times[i - 1])
	var spread: float = (gaps.max() - gaps.min()) if gaps.size() >= 3 else 0.0
	_check.call(
		spread >= Num.f(cfg["fire_interval"]) * 0.3,
		"a squad fires at ragged gaps, not in step (%d gaps, spread %.2f s)" % [gaps.size(), spread]
	)
	# Range is measured from the edge of the kaiju's stomp, as the tanks' is (D-076): a Behemoth
	# whose centre is past `range` but whose stomp edge is within it draws fire.
	var edge := _one_squad(_new({"claws": 3, "hide": 3, "rage": 3, "evolve1": 1}, grown))
	var past := Num.f(cfg["range"]) + edge.stomp_radius() * 0.5
	edge.kaiju_pos = edge.army_units.squads[0].pos + Vector2(past, 0)
	var edge_shots := _steps_counting(edge, seconds, "rooftop_fired")
	_check.call(
		edge_shots >= 1,
		(
			"a squad fires at a Behemoth %.1f from its centre, inside range %.0f + stomp %.1f (%d)"
			% [past, Num.f(cfg["range"]), edge.stomp_radius(), edge_shots]
		)
	)
	# Its roof chunk gone (broken, dropped or toppled): the squad dies and pays biomass.
	var roof := _one_squad(_new({}))
	roof.kaiju_pos = Vector2(roof.arena_half, roof.arena_half)  # far off: no stomp lands
	var squad := roof.army_units.squads[0]
	var before := roof.rubble
	roof.buildings[squad.building].frame.remove(squad.cell)
	var died := _steps_counting(roof, DT, "rooftop_destroyed")
	var paid := roof.rubble - before
	var want := Num.f(cfg["rooftop_rubble"][0]) * roof.stat("rubble_mult")
	_check.call(
		died == 1 and roof.army_units.squads.is_empty() and is_equal_approx(paid, want),
		"a squad whose roof is gone dies and pays %.1f biomass (paid %.1f)" % [want, paid]
	)
	_check.call(
		Num.i(roof.result().get("rooftops", -1)) == 1,
		"the result counts rooftop squads killed: %s" % [roof.result()]
	)
	# A splash kills a squad only when it reaches the squad's roof floor.
	var hit := _one_squad(_new({}))
	var target := hit.army_units.squads[0]
	var at := target.pos
	var force := func(p: Vector2, r: float) -> float:
		return 1.0 if p.distance_to(at) <= r + 1.0 else 0.0
	hit.hit_area(force, 0.0, 0, target.cell.y)
	var below_survives := hit.army_units.squads.size() == 1
	hit.hit_area(force, 0.0, 0, target.cell.y + 1)
	_check.call(
		(
			below_survives
			and hit.army_units.squads.is_empty()
			and hit.army_units.rooftops_destroyed == 1
		),
		"a stomp or breath kills a squad only when it reaches its roof floor %d" % target.cell.y
	)
	# Player effect: the same seeded Behemoth rampage (the demo's last stage) with and without
	# rooftop squads, in the Behemoth's grown city: hp left halfway (both still standing), then
	# the biomass at the end.
	# Landmarks off in both: the scripted walk goes to the nearest building, and the Behemoth's
	# wheel stands by the start in a plaza no rooftop squad covers, so it would never meet one.
	var on_tune := grown.duplicate(true)
	on_tune["city"]["landmarks"] = []
	var off_tune := on_tune.duplicate(true)
	off_tune["army"]["rooftop"]["max_by_tier"] = [0, 0, 0, 0]
	var build := {"claws": 3, "hide": 5, "rage": 3, "evolve1": 1}
	var on: RampageSim = _new(build, on_tune)
	var off: RampageSim = _new(build, off_tune)
	var half := roundi(Num.f(on.time_left) * 0.5 / DT)
	_play.call(on, half)
	_play.call(off, half)
	var on_hp := on.hp
	var off_hp := off.hp
	var on_result: Dictionary = _play.call(on, MAX_STEPS)
	var off_result: Dictionary = _play.call(off, MAX_STEPS)
	_check.call(
		off.army_units.squads.is_empty() and on_hp > 0.0 and on_hp < off_hp,
		(
			"rooftops on vs off: hp left halfway %.1f vs %.1f, biomass %d vs %d, squads killed %d"
			% [
				on_hp,
				off_hp,
				Num.i(on_result["rubble"]),
				Num.i(off_result["rubble"]),
				Num.i(on_result.get("rooftops", 0))
			]
		)
	)
	# D-076 "more squads, more often": over the whole Behemoth rampage the roofs keep firing.
	var played := Num.f(on.stat("run_seconds")) - maxf(0.0, on.time_left)
	var rate := on.army_units.volleys / maxf(1.0, played)
	_check.call(
		rate >= MIN_BEHEMOTH_VOLLEYS,
		(
			"a Behemoth rampage draws %.2f rooftop volleys a second (%d in %.0f s), at least %.1f"
			% [rate, on.army_units.volleys, played, MIN_BEHEMOTH_VOLLEYS]
		)
	)
	_check.call(
		Num.i(on_result["rubble"]) != Num.i(off_result["rubble"]),
		(
			"rooftops change the biomass earned (%d vs %d)"
			% [Num.i(on_result["rubble"]), Num.i(off_result["rubble"])]
		)
	)


## A seeded reptilian rampage (the runner's _sim) with these levels and tuning.
func _new(levels: Dictionary, tuning: Dictionary = {}) -> RampageSim:
	var sim: RampageSim = _make.call("reptilian", levels, 0, tuning)
	return sim


func _squad_spots(sim: RampageSim) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for squad: Army.Squad in sim.army_units.squads:
		out.append(Vector3i(squad.building, squad.cell.x, squad.cell.z))
	return out


## Keeps only the first squad, ready to fire.
func _one_squad(sim: RampageSim) -> RampageSim:
	if not sim.army_units.squads.is_empty():
		var first := sim.army_units.squads[0]
		first.cooldown = 0.0
		sim.army_units.squads.assign([first])
	return sim


## Steps a standing kaiju for `seconds`, counting events of `kind`.
func _steps_counting(sim: RampageSim, seconds: float, kind: String) -> int:
	var count := 0
	for i: int in ceili(seconds / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == kind:
				count += 1
	return count
