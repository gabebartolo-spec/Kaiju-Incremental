extends RefCounted
## The sim suite's heavy-body check (D-208, the Komodo's contact volume rides its drawn clips): the
## sim's clip clock (ClipClock) is new sim state, so the same seed and the same stick give the same
## clip, frame and volume on every step through every transition a run makes (idle, walk, a roar
## from the breath, a turn on the move, the stop). The rampage keeps no mid-run save (a run is
## rebuilt from its seed), so replaying it from the seed is its reload-then-continue.

const DT := 1.0 / 60.0
const STEPS := 600

var _check: Callable


func _init(check: Callable) -> void:
	_check = check


func run() -> void:
	var a := _replay()
	var b := _replay()
	var states := {}
	var first_off := -1
	for i: int in mini(a.size(), b.size()):
		var row: Array = a[i]
		states[row[0]] = true
		if first_off < 0 and str(row) != str(b[i]):
			first_off = i
	var ok := a.size() == STEPS and first_off < 0 and states.has("walk") and states.has("roar")
	ok = ok and states.has("idle")
	var clips := states.keys()
	var why := "the same seed replays the heavy clip clock and volume (%s; off at step %d)"
	_check.call(ok, why % [clips, first_off])


## One seeded heavy run: stand, walk, the breath (a roar), a turn on the move, then stop. Returns
## each step's clock snapshot with a digest of its volume (the first and last disc).
func _replay() -> Array:
	var sim := _heavy_sim()
	var hc := sim.body.heavy_contact
	var rows: Array = []
	if hc == null:
		return rows
	for n: int in STEPS:
		var t := n * DT
		var move := Vector2.ZERO
		if t > 0.5 and t < 8.0:
			move = Vector2(0, -1) if t < 4.0 else Vector2(-1, 0)
		sim.step(DT, move, n == 150, 0)
		var discs := hc.discs(sim.body._centre(sim.kaiju_pos, sim.body.heading), sim.body.body_dir)
		var row := hc.clock.snapshot()
		row.append(str(discs[0]) + str(discs[discs.size() - 1]))
		rows.append(row)
	return rows


func _heavy_sim() -> RampageSim:
	var def := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), {"evolve1": 1, "evolve2": 1}, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.kaiju_pos = Vector2(0, 30)
	return sim
