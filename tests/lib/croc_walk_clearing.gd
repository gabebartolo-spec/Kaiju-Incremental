extends RefCounted
## D-302: the reworked walk takes longer, slower steps (the adult's step_len in contact.bodies
## follows the clip's stride, D-201), so fewer footfalls fall in each metre walked, and a walking
## stomp falls on a footfall. What a Colossus clears walking up a street stays within CLEAR_TOL of
## the walk before D-302: same city seeds, same stick, same time; the only change is the step.
## "Cleared" is building chunks broken per metre walked (no tank reaches a 20 s walk).

const DT := 1.0 / 60.0
const SECONDS := 20.0
const SEEDS: Array[int] = [0, 1, 2]
const HERO_HP := 1.0e9
## The adult's step (body units at scale 1) before D-302: contact.bodies, reptilian, third stage.
const BEFORE_STEP_LEN := 2.33
const ADULT := 2  # the adult's index in contact.bodies.reptilian and its size tier minus one
const CLEAR_TOL := 0.10

var _check: Callable


func _init(check: Callable) -> void:
	_check = check


func run() -> void:
	var before := _walks(BEFORE_STEP_LEN)
	var now := _walks(-1.0)
	var was := Num.f(before["chunks"]) / maxf(1.0, Num.f(before["m"]))
	var is_now := Num.f(now["chunks"]) / maxf(1.0, Num.f(now["m"]))
	var ratio := is_now / was if was > 0.0 else INF
	_check.call(
		absf(ratio - 1.0) <= CLEAR_TOL,
		(
			"adult walk (D-302): chunks cleared per metre within %d%% of the walk before (%.2f vs"
			% [roundi(CLEAR_TOL * 100.0), is_now]
			+ " %.2f, ratio %.3f; %d vs %d stomps over %.0f vs %.0f m)"
			% [was, ratio, now["stomps"], before["stomps"], now["m"], before["m"]]
		)
	)


## The sum over SEEDS of one straight walk each; step_len < 0 keeps the data's own step.
func _walks(step_len: float) -> Dictionary:
	var sum := {"m": 0.0, "chunks": 0, "stomps": 0}
	for map_seed: int in SEEDS:
		var one := _walk(map_seed, step_len)
		for key: String in sum:
			sum[key] += one[key]
	return sum


## Walks the adult north up the city's middle from the south ring avenue for SECONDS.
func _walk(map_seed: int, step_len: float) -> Dictionary:
	var tuning: Dictionary = Content.tuning().duplicate(true)
	if step_len >= 0.0:
		tuning["contact"]["bodies"]["reptilian"][ADULT]["step_len"] = step_len
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades(), {})
	)
	stats["size"] = float(ADULT + 1)
	var layout := CityGen.generate(Seeds.make("city", map_seed), Content.section("city"))
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", map_seed))
	sim.body.use_species("reptilian")
	sim.hp = HERO_HP
	sim.max_hp = HERO_HP
	var walked := 0.0
	var stomps := 0
	for i: int in roundi(SECONDS / DT):
		var was := sim.kaiju_pos
		for event: Dictionary in sim.step(DT, Vector2(0.0, -1.0), false):
			if str(event["type"]) == "stomp":
				stomps += 1
		walked += was.distance_to(sim.kaiju_pos)
	var out := {"m": walked, "chunks": sim.chunks_destroyed, "stomps": stomps}
	sim.dispose()
	return out
