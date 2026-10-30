extends "res://tests/lib/runner.gd"
## Shared scene-building for the power suites (run_powers_tests, run_helis_tests): a kaiju
## with chosen branch levels in a small hand-made layout, stepped with fixed input.

const DT := 1.0 / 30.0
const NORTH := Vector2(0, -1)
const EAST := Vector2(1, 0)
## _run button flags (BREATH_KEY: the croc's breath button).
const PRESS := 1
const HOLD := 2
const ULT := 4
const BREATH_KEY := 16  # the croc's breath button (D-399), on the first step


## A building entry for a hand-made layout.
## size = (width, depth, floors).
func _b(x: float, z: float, size: Vector3i, tier: int = 1) -> Dictionary:
	return {"x": x, "z": z, "w": size.x, "d": size.y, "h": size.z, "tier": tier, "style": 0}


## A kaiju of `species_id` with `levels` (prerequisites not enforced: the sim reads stats) in
## a hand-made layout, standing at `at`. A far building keeps the run from ending at once.
func _sim(
	species_id: String, levels: Dictionary, layout: Array[Dictionary], at: Vector2
) -> RampageSim:
	var species := Content.species_def(species_id)
	var tree := UpgradeTree.new(Content.upgrades(), levels, species_id)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var all: Array[Dictionary] = []
	all.append_array(layout)
	all.append(_b(38.0, 38.0, Vector3i(2, 2, 2)))
	var sim := RampageSim.new(stats, Content.tuning(), all, Seeds.make("army", 0))
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	sim.kaiju_pos = at
	return sim


## Steps for `seconds` with a fixed input (buttons: PRESS / ULT on the first step, HOLD on
## every step); returns every event type seen, counted.
func _run(sim: RampageSim, seconds: float, move: Vector2, buttons: int = 0) -> Dictionary:
	var seen := {}
	for i: int in roundi(seconds / DT):
		var flags := RampageSim.HELD if buttons & HOLD else 0
		if i == 0 and buttons & ULT:
			flags |= RampageSim.ULTIMATE
		if i == 0 and buttons & BREATH_KEY:
			flags |= RampageSim.BREATH
		for event: Dictionary in sim.step(DT, move, i == 0 and buttons & PRESS != 0, flags):
			var kind := str(event["type"])
			seen[kind] = Num.i(seen.get(kind, 0)) + 1
	return seen


## Steps for `seconds` (buttons on the first step) with the leader held `offset` from the kaiju, so
## a strike that lands a beat after the press (D-166) still finds it; returns the events seen.
func _held_run(sim: RampageSim, seconds: float, offset: Vector2, buttons: int) -> Dictionary:
	var seen := {}
	for i: int in roundi(seconds / DT):
		if sim.vip.flying():
			sim.vip.pos = sim.kaiju_pos + offset
		var flags := RampageSim.ULTIMATE if i == 0 and buttons & ULT else 0
		if i == 0 and buttons & BREATH_KEY:
			flags |= RampageSim.BREATH
		for event: Dictionary in sim.step(DT, Vector2.ZERO, i == 0 and buttons & PRESS != 0, flags):
			var kind := str(event["type"])
			seen[kind] = Num.i(seen.get(kind, 0)) + 1
	return seen


func _alive(sim: RampageSim, index: int) -> int:
	return sim.buildings[index].frame.alive_count


## Seconds that carry a pressed Thunder Beam to its strike, where the stream starts (D-166).
func _strike_wait() -> float:
	return Num.f(Content.section("strike")["beam"])
