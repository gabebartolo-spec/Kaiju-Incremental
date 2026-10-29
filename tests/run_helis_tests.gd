extends "res://tests/lib/powers_base.gd"
## Helis suite: the croc and the helicopters (D-037, D-183) and his full branch replayed. Moved
## out of run_tentacles_tests.gd, now parked with the cephalopod and insectoid (tests/parked/,
## director 2026-10-29: only what the demo build needs is tested). Headless, no autoloads.
##   godot --headless --path . --script tests/run_helis_tests.gd

## Strafing passes a helicopter is sent on, and the seconds each is given (strafe_seconds).
const PASSES := 8
const PASS_SECONDS := 22.0
## How fast the grown croc's walk curves (radians a second) while the passes run: a pass aims
## ahead of his walk into the claw's band; past a croc standing still it runs down his flank.
const WALK_TURN := 0.3


func suite_name() -> String:
	return "Helis"


func run_checks() -> void:
	await _t("_check_helicopters")
	await _t("_check_heli_keeps_clear")
	await _t("_check_caps")
	await _t("_check_replay")


## Helicopters (D-037, D-183): they come once the city is burning, hold their stand-off ring and
## fire; a young kaiju cannot reach them, and a grown one walking the city swats one on its
## strafing pass.
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
		(
			"a helicopter flies in and fires on the kaiju (%d bursts)"
			% Num.i(seen.get("heli_fired", 0))
		)
	)
	check(heli.hp > 0.0, "a young kaiju's stomps cannot reach a helicopter")
	var grown := _sim("reptilian", {"evolve1": 1, "claws": 5, "hide": 5}, [], Vector2(0, 0))
	var diver := grown.air.spawn()
	_face_away_from_camera(grown)
	grown.time_left = 1.0e9  # the passes run longer than a short rampage
	# nor does the one building's fall end it (city_fallen): it fell in pass 4 of 8 when the walk
	# reached it, so the passes after it never flew
	grown.chunks_total = 10000000
	var swatted := false
	for pass_n: int in PASSES:
		# A swipe lands every 2 s, so each pass starts a little later in that rhythm (a pass is
		# in the claw's band for about 1.6 s of it).
		_run(grown, 0.4 * pass_n, Vector2.ZERO)
		grown.air.flight.start_pass(diver)
		for i: int in roundi(PASS_SECONDS / DT):
			grown.hp = grown.max_hp  # the passes run on; the helicopters' fire is not measured
			var walk := Vector2.from_angle(i * DT * WALK_TURN)
			for event: Dictionary in grown.step(DT, walk, false):
				swatted = swatted or str(event["type"]) == "heli_destroyed"
		if swatted:
			break
	check(
		swatted,
		"a grown kaiju (reach %.1f) swats a helicopter on its strafing pass" % grown.reach_top()
	)


## The kaiju faces away from the game camera, where the helicopters are allowed to be.
func _face_away_from_camera(sim: RampageSim) -> void:
	sim.facing = Vector2.from_angle(
		deg_to_rad(Num.f(Content.section("air")["camera_bearing"])) + PI
	)


## Helicopters keep off the camera's side of the kaiju (never between the player and it) and
## hold their stand-off ring (D-183) round a standing kaiju, for 20 s (before the first pass).
func _check_heli_keeps_clear() -> void:
	var sim := _sim("reptilian", {}, [], Vector2(0, 0))
	var air: Dictionary = Content.section("air")
	var bearing := deg_to_rad(Num.f(air["camera_bearing"]))
	var ring := Num.f(air["standoff"]) * (1.0 - Num.f(air["standoff_jitter"])) * sim.body_scale()
	for _n: int in 3:
		sim.air.spawn()
	var closest := PI
	var nearest := INF
	for i: int in roundi(20.0 / DT):
		sim.step(DT, Vector2.ZERO, false)
		for heli: AirWing.Heli in sim.air.helis:
			var side := absf(wrapf((heli.pos - sim.kaiju_pos).angle() - bearing, -PI, PI))
			closest = minf(closest, side)
			nearest = minf(nearest, heli.pos.distance_to(sim.kaiju_pos))
	check(
		(
			closest >= deg_to_rad(Num.f(air["clear_arc"])) - 0.01
			and nearest >= ring - Num.f(air["arrive"])
		),
		(
			"helicopters stay %.0f deg off the camera side and hold %.1f out (ring %.1f)"
			% [rad_to_deg(closest), nearest, ring]
		)
	)


## Caps (lead review): a downed helicopter is replaced only after the call-in interval, never on
## the next step; never more helicopters than the max.
func _check_caps() -> void:
	var air: Dictionary = Content.section("air")
	var sim := _sim("reptilian", {}, [], Vector2(0, 0))
	sim.chunks_total = 1000000  # a big-city stand-in, so the run cannot end as "fallen"
	sim.chunks_destroyed = Num.i(air["after_chunks"])
	var first := _run(sim, 0.2, Vector2.ZERO)
	var called := first.has("heli_spawned") and sim.air.helis.size() == 1
	_run(sim, Num.f(air["interval"]) * 1.5, Vector2.ZERO)  # a long spell at the cap first
	called = called and sim.air.helis.size() == 1
	sim.air.helis[0].hp = 0.0 if called else 1.0
	sim.air.clear_dead()
	var soon := _run(sim, Num.f(air["interval"]) * 0.9, Vector2.ZERO)
	var later := _run(sim, Num.f(air["interval"]) * 0.2, Vector2.ZERO)
	check(
		called and not soon.has("heli_spawned") and later.has("heli_spawned"),
		(
			"a downed helicopter is replaced only after the %.0f s call-in interval"
			% Num.f(air["interval"])
		)
	)
	var swarm := _sim("reptilian", {"hide": 5, "titan_hide": 5}, [], Vector2(0, 0))
	swarm.chunks_total = 1000000
	swarm.chunks_destroyed = 99999
	var most := 0
	for i: int in 30 * 60:
		swarm.step(DT, Vector2.ZERO, false)
		most = maxi(most, swarm.air.helis.size())
	check(
		most == Num.i(air["max"]),
		"the sky never holds more than %d helicopters (most %d)" % [Num.i(air["max"]), most]
	)


## A full autoplayed rampage with every croc branch bought replays identically.
func _check_replay() -> void:
	var full := {
		"reptilian": {"r_tail": 2, "r_momentum": 2, "r_shear": 1, "r_beam": 1},
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
				var held := RampageSim.HELD if i % 40 < 20 else 0
				sim.step(DT, move, sim.ability_ready_in <= 0.0, held | RampageSim.ULTIMATE)
			runs.append(sim.result())
		same = same and runs[0] == runs[1]
	check(same, "the croc's full branch replays identically from the same seed")
