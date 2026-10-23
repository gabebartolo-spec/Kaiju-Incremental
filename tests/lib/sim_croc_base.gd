extends RefCounted
## The sim suite's "the croc is untouched" pin (D-208's sim review): the heavy body's work (the
## Komodo adult, BodySteps, HeavyContact) must leave the young croc and the adolescent croc on
## the very paths they walked before it (claude/look-options cc77576c). Each case plays a run as
## the game makes it (CityGrowth's city, the river rise, 900 steps at 60 Hz, a scripted stick and
## the signature every 200 steps) and hashes, every step, the kaiju's place, heading, step clock,
## chunks broken, HP and tanks. The pins were taken on cc77576c; a float32 round of the stepped
## turn's cadence (BodySteps.stepped_pace as a Vector2) moved the adolescent's heading at step 371.
## Seeded by design: city and army seeds are the case's run index.

const DT := 1.0 / 60.0
const STEPS := 900
## [stage levels, run index, stick script, digest on cc77576c].
const PINS := [
	[{}, 3, "turnmove", 406364848],
	[{"evolve1": 1}, 5, "turnmove", 4066838200],
	[{"evolve1": 1}, 5, "stoprestart", 382810721],
]

var _check: Callable


func _init(check: Callable) -> void:
	_check = check


func run() -> void:
	for pin: Array in PINS:
		var levels: Dictionary = pin[0]
		var got := digest(_croc(levels, Num.i(pin[1])), str(pin[2]))
		var why := "the croc %s (run %d, %s) walks as it did before the heavy body: %d, base %d"
		var stage := "adolescent" if levels.has("evolve1") else "baby"
		_check.call(got == Num.i(pin[3]), why % [stage, pin[1], pin[2], got, pin[3]])


## The run's per-step hash.
static func digest(sim: RampageSim, script: String) -> int:
	var h := 17
	for n: int in STEPS:
		sim.step(DT, _stick(n, script), n % 200 == 150, 0)
		var row := [h, snappedf(sim.kaiju_pos.x, 0.0001), snappedf(sim.kaiju_pos.y, 0.0001)]
		row.append_array([snappedf(sim.body.heading.x, 0.0001), sim.body.broken])
		row.append_array([sim.chunks_destroyed, snappedf(sim.hp, 0.0001)])
		row.append_array([snappedf(sim.body.phase, 0.0001), sim.tanks.size()])
		h = hash(row)
	return h


## turnmove: up 3 s, left 3 s, down 3 s, then stand; stoprestart: up 3 s, let go 0.2 s, up again
## until 6 s.
static func _stick(n: int, script: String) -> Vector2:
	var t := n * DT
	if script == "stoprestart":
		return Vector2(0, -1) if t < 3.0 or (t >= 3.2 and t < 6.0) else Vector2.ZERO
	if t < 3.0:
		return Vector2(0, -1)
	if t < 6.0:
		return Vector2(-1, 0)
	return Vector2(0, 1) if t < 9.0 else Vector2.ZERO


## A croc run as the game makes one: the city for its size, the army, the rise from the river.
func _croc(levels: Dictionary, run_index: int) -> RampageSim:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var size := Num.i(stats["size"])
	var layout := CityGrowth.layout(Content.tuning(), size, Seeds.make("city", run_index))
	var sim := RampageSim.new(
		stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", run_index)
	)
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	sim.body.use_species("reptilian")
	sim.emerge.start(sim)
	return sim
