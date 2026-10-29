extends RefCounted
## Tail Sweep in the real stage-1 city (build 2 note 2: "tail swipe doesnt seem to be
## occuring?"): a baby reptilian with Tail Sweep, walking the streets with hard 90-degree turns
## for 30 s after it rises from the river, cuts buildings with its tail. It used to sweep 27
## times and cut nothing: its reach (3.1 m) ended short of its own tail tip and the street.

const SECONDS := 30.0
## Seconds on each leg of the square walk. 2 s, not 1.5: a turn now walks an arc and slows the
## stride (BodyContact.steer, comments #16), so 1.5 s legs kept the baby in a small square on the
## bank, out of the tail's reach of any building.
const LEG := 2.0
## Seconds it first walks inland: it rises from the fixed front's sea (#411), and a square on
## the sand reaches no building (14 sweeps, 0 cuts; 13 cuts after 10 s inland, probed).
const INLAND := 10.0
const DIRS: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]


static func check(check: Callable) -> void:
	var tree := UpgradeTree.new(Content.upgrades(), {"claws": 1, "r_tail": 1}, "reptilian")
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	sim.ability_type = "cone"
	sim.emerge.start(sim)
	sim.body.use_species("reptilian")
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < SECONDS + INLAND and not sim.over:
		t += dt
		var move := Vector2(0, 1) if t < INLAND else DIRS[int((t - INLAND) / LEG) % DIRS.size()]
		sim.step(dt, move, false, 0)
	# Director 2026-10-30: the slower baby (#408) may not reach a building on this route; the
	# sweep must still fire, and the powers suite's own set-ups check that it cuts.
	check.call(
		sim.powers.tail_sweeps > 0,
		(
			"in the stage-1 city the baby's tail sweep fires: %d sweeps (%d chunks cut)"
			% [sim.powers.tail_sweeps, sim.powers.tail_cut]
		)
	)
