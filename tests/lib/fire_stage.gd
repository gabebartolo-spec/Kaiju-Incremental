extends RefCounted
## The fire suite's stage-4 check, split out to keep the runner small: on the stage-4 city with
## every fire node owned, a few blocks lit by the kaiju spread fire; the same seed replays the
## same fires and biomass, and the fire's own share of a tick stays in budget.

const DT := 1.0 / 30.0
const SECONDS := 30.0
## Blocks lit at the start, the ones nearest the kaiju.
const LIT := 6
## The fire's own cost a tick at stage 4, at most (usec, headless; FireSpread.step, burn-outs
## and their collapse included): the budget.
const BUDGET_USEC := 1000.0
const LEVELS := {
	"evolve1": 1,
	"evolve2": 1,
	"evolve3": 1,
	"r_ablaze": 1,
	"r_alarm": 3,
	"r_front": 2,
	"r_embers": 2,
	"r_firestorm": 1,
}

var _check: Callable


## FireSpread with a stopwatch on its tick (the fire's own cost, apart from the rest of the sim).
class TimedFire:
	extends FireSpread
	var usec := 0

	func step(dt: float) -> void:
		var t0 := Time.get_ticks_usec()
		super(dt)
		usec += Time.get_ticks_usec() - t0


func _init(p_check: Callable) -> void:
	_check = p_check


func run() -> void:
	var a := _play()
	var b := _play()
	var trace: PackedStringArray = a["trace"]
	var same := trace == b["trace"] and Num.f(a["rubble"]) == Num.f(b["rubble"])
	var says := "stage 4: fire spreads past the %d lit blocks to %d" % [LIT, Num.i(a["lit"])]
	says += (
		", and the same seed replays the same %d fire events and biomass (%.1f vs %.1f)"
		% [trace.size(), Num.f(a["rubble"]), Num.f(b["rubble"])]
	)
	_check.call(same and Num.i(a["lit"]) > LIT, says)
	var per_tick := Num.f(a["usec"]) / (SECONDS / DT)
	_check.call(
		per_tick <= BUDGET_USEC,
		(
			"stage 4 (%d buildings): the fire costs %.0f usec a tick (budget %.0f)"
			% [Num.i(a["buildings"]), per_tick, BUDGET_USEC]
		)
	)


## One seeded stage-4 run: {"trace": every fire event in order, "rubble", "lit": buildings
## that burned, "usec": the fire's time, "buildings"}.
func _play() -> Dictionary:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 1000000.0  # the kaiju must not fall: this watches the fire to the clock
	var tuning := CityGrowth.tuning_for(Content.tuning(), 4)
	var layout := CityGrowth.layout(Content.tuning(), 4, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	var old := sim.powers.fire
	var fire := TimedFire.new(sim, old.cfg, Seeds.make("fire", 0))
	sim.powers.fire = fire
	for i: int in _nearest(sim, LIT):
		fire.ignite(i)
	var trace := PackedStringArray()
	var lit := {}
	for step: int in roundi(SECONDS / DT):
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false, 0):
			var kind := str(event["type"])
			if kind.begins_with("fire_"):
				trace.append("%d:%s" % [Num.i(event["building"]), kind])
				if kind == "fire_burning":
					lit[event["building"]] = true
	return {
		"trace": trace,
		"rubble": sim.rubble,
		"lit": lit.size() + LIT,
		"usec": fire.usec,
		"buildings": sim.buildings.size(),
	}


## The `count` standing buildings nearest the kaiju, nearest first.
func _nearest(sim: RampageSim, count: int) -> Array[int]:
	var order: Array[int] = []
	for i: int in sim.buildings.size():
		if sim.buildings[i].frame.alive_count > 0 and sim.buildings[i].landmark == "":
			order.append(i)
	var at := sim.kaiju_pos
	order.sort_custom(
		func(x: int, y: int) -> bool:
			var bx := sim.buildings[x]
			var by := sim.buildings[y]
			return Vector2(bx.x, bx.z).distance_to(at) < Vector2(by.x, by.z).distance_to(at)
	)
	return order.slice(0, count)
