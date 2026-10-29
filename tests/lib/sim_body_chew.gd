extends RefCounted
## The sim suite's tower checks for the body (D-091, D-096, D-099), split out of
## tests/lib/sim_body_contact.gd to keep that file small: the baby topples a tall tier-2 tower by
## eating its base, at the suite's usual city and at city seeds 3, 8 and 22, from a spot where
## nothing stands inside its body to start with; the undermined tower falls by its own physics;
## a claw swipe brings it down sooner, and cannot reach through it into the block behind.

const Fixture := preload("res://tests/lib/sim_body_fixture.gd")

const DT := 1.0 / 30.0
## The tower test: the baby chews across a tier-2 tower's base for at most this long (steps).
const TOPPLE_STEPS := 30 * 60
## City seeds whose tall towers stand among neighbours taller than the baby (nothing but the
## chew breaks those), so a body set down on top of them starts inside them. Seeds 3 and 8 have
## no office tower in the arena.
const CHEW_SEEDS: Array[int] = [3, 8, 22]
## The chew's ways in, first that has clear ground: from the south face, then north, east, west.
const CHEW_DIRS: Array[Vector2] = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]

var _check: Callable
var _make: Callable
var _make_seeded: Callable


## check: the runner's check; make(species, levels, run_index, tuning) -> RampageSim;
## make_seeded(species, levels, tuning, Vector2i(city seed, run index)) -> RampageSim.
func _init(p_check: Callable, make: Callable, make_seeded: Callable) -> void:
	_check = p_check
	_make = make
	_make_seeded = make_seeded


func run() -> void:
	_check_topple()
	_check_chew_seeds()
	_check_swipe_occlusion()


## D-091: "more than capable of tearing the roots out and toppling the large buildings". The baby
## chews straight into the base of the nearest tall tier-2 tower until it comes down.
func _check_topple() -> void:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	var b := sim.buildings[Fixture.nearest_tower(sim)]
	var start := b.frame.alive_count
	var chew := _chew_to_topple(sim)
	var fall: RampageSim.Fall = chew["fall"]
	_check.call(
		fall != null and Num.i(chew["worst"]) == 0,
		(
			(
				"the baby topples a %d-floor tier-2 tower by eating its base: %s after %.1f s"
				+ " (%d of %d chunks standing, none inside the body: %d)"
			)
			% [
				b.height,
				fall != null,
				Num.i(chew["steps"]) * DT,
				b.frame.alive_count,
				start,
				Num.i(chew["worst"])
			]
		)
	)
	_check_falls_by_physics(sim, fall)
	_check_swipe_undermines(Num.i(chew["steps"]))


## The same chew in other cities (CHEW_SEEDS): a real tall tower is found, the body starts with
## nothing inside it, the tower topples, and after every step still nothing stands inside the
## body. Before this fixture backed the body off its neighbours, it started inside them (55 to 107
## chunks on seeds 8 and 22) and counted those as chunks the chew left in the body.
func _check_chew_seeds() -> void:
	for city_seed: int in CHEW_SEEDS:
		var sim: RampageSim = _make_seeded.call("reptilian", {}, {}, Vector2i(city_seed, 0))
		var chew := _chew_to_topple(sim)
		var tower := Num.i(chew["tower"])
		var fall: RampageSim.Fall = chew["fall"]
		var b: RampageSim.Building = sim.buildings[tower] if tower >= 0 else null
		(
			_check
			. call(
				(
					b != null
					and Num.f(chew["backed"]) >= 0.0
					and fall != null
					and Num.i(chew["worst"]) == 0
				),
				(
					(
						"city seed %d: the baby topples a %s tower, set down %.0f m back with nothing inside"
						+ " its body: %s after %.1f s; most chunks inside the body after a step: %d"
					)
					% [
						city_seed,
						"%dx%dx%d" % [b.w, b.d, b.height] if b != null else "(none found)",
						Num.f(chew["backed"]),
						fall != null,
						Num.i(chew["steps"]) * DT,
						Num.i(chew["worst"])
					]
				)
			)
		)


## D-096 (director 2026-10-20, "Swipes undermine towers"): a claw hit on a tower's base counts as
## chewing it, so the same chew with the swipe on brings the tower down sooner than with it off. A
## chew alone may never topple it (the pool city's office tower: the chew cuts a slot through its
## middle and walks out the far side while both flanks hold it up), which counts as later.
func _check_swipe_undermines(swiped_steps: int) -> void:
	var off: RampageSim = _make.call("reptilian", {}, 0, {})
	off.stats["swipe_damage"] = 0.0
	var chew := _chew_to_topple(off)
	var fell := chew["fall"] != null
	_check.call(
		swiped_steps < Num.i(chew["steps"]),
		(
			"a swiped tower topples sooner: %.1f s with the swipe vs %.1f s without (fell: %s)"
			% [swiped_steps * DT, Num.i(chew["steps"]) * DT, fell]
		)
	)


## A claw can't reach through a tower into the block behind it: one swipe at the tier-2 tower's
## south face, with a building standing right against its far (north) side, chews the tower and
## leaves the building behind it whole (the chewed rows are the nearest standing ones per lane).
func _check_swipe_occlusion() -> void:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	var index := Fixture.nearest_of(sim, 2, Vector2i(Fixture.TOWER_FLOORS, Fixture.TOWER_SIDE), -1)
	var tower := sim.buildings[index]
	var behind_index := -1
	for i: int in sim.buildings.size():
		var other := sim.buildings[i]
		if i != index and other.tier == 2 and other.landmark == "" and other.in_arena:
			behind_index = i
			break
	var behind := sim.buildings[behind_index]
	for other: RampageSim.Building in sim.buildings:
		if other != tower and other != behind:
			other.x += 1000.0  # a clear street: nothing else stands in the band
	behind.x = tower.x
	behind.z = tower.z - tower.d * 0.5 - behind.d * 0.5  # touching the tower's far face
	var into := Vector2(0, -1)
	Fixture.set_down(
		sim, Vector2(tower.x, tower.z + tower.d * 0.5 + sim.body.length() * 0.25), into
	)
	var tower_before := tower.frame.alive_count
	var behind_before := behind.frame.alive_count
	sim.powers.swipe._rake()
	var tower_lost := tower_before - tower.frame.alive_count
	var behind_lost := behind_before - behind.frame.alive_count
	_check.call(
		tower_lost > 0 and behind_lost == 0,
		(
			(
				"a swipe chews the tower it hits (%d chunks off) and not the building right behind"
				+ " it (%d of %d off)"
			)
			% [tower_lost, behind_lost, behind_before]
		)
	)


## The baby chews straight north into the nearest tall tier-2 tower's base from its south face,
## set down clear of every neighbour, until the tower topples (an office tower, so the fixture
## does not hang on whichever style stands nearest: one swipe clears a brick tower's two front
## rows without tipping it sooner, red-115, senior dev review): {"steps", "worst" (most chunks
## inside the body after a step), "fall" (or null), "tower" (building index, -1 none found),
## "backed" (how far the body backed off its first spot, -1 if it found no clear one)}.
func _chew_to_topple(sim: RampageSim) -> Dictionary:
	sim.body.use_species("reptilian")
	var out := {"steps": 0, "worst": 0, "fall": null, "tower": -1, "backed": -1.0}
	var index := Fixture.nearest_tower(sim)
	if index < 0:
		return out
	out["tower"] = index
	var b := sim.buildings[index]
	# From the tower's south face across its base; else the first other face with clear ground.
	var into := Vector2.ZERO
	for dir: Vector2 in CHEW_DIRS:
		var half := Vector2(b.w, b.d) * 0.5
		var face := Vector2(b.x, b.z) - dir * (absf(dir.dot(half)) + sim.body.length() * 0.6)
		out["backed"] = Fixture.set_down_clear(sim, face, dir)
		if Num.f(out["backed"]) >= 0.0:
			into = dir
			break
	if into == Vector2.ZERO:
		return out
	var steps := 0
	var worst := 0
	var fall: RampageSim.Fall = null
	while steps < TOPPLE_STEPS and fall == null:
		sim.step(DT, into, false)
		worst = maxi(worst, Fixture.count(sim.body.inside(sim.kaiju_pos, sim.body.heading)))
		for f: RampageSim.Fall in sim.falls:
			if f.building == index and f.kind == "topple":
				fall = f
		steps += 1
	out["steps"] = steps
	out["worst"] = worst
	out["fall"] = fall
	return out


## D-099: the undermined tower falls by its own physics, toward the side that was cut away (here
## the kaiju's), and the strip it lands on runs from its base along that fall.
func _check_falls_by_physics(sim: RampageSim, fall: RampageSim.Fall) -> void:
	var landed: Dictionary = {}
	var steps := 0
	while fall != null and landed.is_empty() and steps < TOPPLE_STEPS:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "fall_land" and Num.i(event["id"]) == fall.id:
				landed = event
		steps += 1
	var from: Vector2 = landed.get("from", Vector2.ZERO)
	var to: Vector2 = landed.get("to", Vector2.ZERO)
	_check.call(
		fall != null and not landed.is_empty() and (to - from).dot(fall.dir) > 0.0,
		(
			"the undermined tower lands along its fall dir %s: strip %s -> %s"
			% [fall.dir if fall != null else Vector2.ZERO, from.round(), to.round()]
		)
	)
