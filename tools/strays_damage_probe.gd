extends SceneTree
## Fixed-path damage probe for the clumsy army (director, comments #18): the army's damage to the
## kaiju must stay within 5% of the base behaviour (every shell hits). The kaiju walks one
## scripted loop of waypoints (no autoplay, so a stray that breaks a building cannot change where
## it goes), with the same city, tanks and seeds in both modes:
##   base:   army.miss.hit_near = hit_far = 1.0 (every shell hits for its full damage, as before)
##   strays: data/tuning.json as it stands (a hit chance that falls with range, misses land beside)
## Helicopters are off in both modes (air.max 0): strays change how much of the city falls, which
## would call them in at different times and swamp the tanks' and squads' damage this checks.
## Prints one ROW per run and, per tier, the damage per minute of each mode and the difference.
##   godot --headless --path . --script tools/strays_damage_probe.gd -- \
##     [--tier=2] [--first=0] [--seeds=72] [--seconds=90] [--mode=both|base|strays]
## Run it with its own APPDATA, as tools/run_tests.sh does.

const DT := 1.0 / 15.0
const LEVELS := {
	1: {},
	2: {"evolve1": 1},
	3: {"evolve1": 1, "evolve2": 1},
	4: {"evolve1": 1, "evolve2": 1, "evolve3": 1}
}
## The loop's corners, as a fraction of the arena's half width; a corner counts as reached
## within REACHED metres.
const LOOP := [Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5), Vector2(0.5, -0.5)]
const REACHED := 3.0

var _tier := 2
var _first := 0
var _seeds := 72
var _seconds := 90.0
var _mode := "both"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tier="):
			_tier = arg.substr(7).to_int()
		if arg.begins_with("--first="):
			_first = arg.substr(8).to_int()
		if arg.begins_with("--seeds="):
			_seeds = arg.substr(8).to_int()
		if arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		if arg.begins_with("--mode="):
			_mode = arg.substr(7)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var modes: Array[String] = ["base", "strays"]
	if _mode != "both":
		modes = [_mode]
	var total := {}  # mode -> {damage, minutes, shots, misses}
	var damage := {}  # mode -> {seed: damage per minute}
	for mode: String in modes:
		total[mode] = {"damage": 0.0, "minutes": 0.0, "shots": 0, "misses": 0}
		damage[mode] = {}
	for seed_id: int in range(_first, _first + _seeds):
		for mode: String in modes:
			var r := _rampage(seed_id, mode)
			var t: Dictionary = total[mode]
			t["damage"] = Num.f(t["damage"]) + Num.f(r["damage"])
			t["minutes"] = Num.f(t["minutes"]) + Num.f(r["seconds"]) / 60.0
			t["shots"] = Num.i(t["shots"]) + Num.i(r["shots"])
			t["misses"] = Num.i(t["misses"]) + Num.i(r["misses"])
			var per_min := Num.f(r["damage"]) / maxf(0.001, Num.f(r["seconds"]) / 60.0)
			var by_seed: Dictionary = damage[mode]
			by_seed[seed_id] = per_min
			print(
				(
					"ROW tier %d seed %d %s damage_per_min %.4f shots %d misses %d seconds %.1f"
					% [_tier, seed_id, mode, per_min, r["shots"], r["misses"], r["seconds"]]
				)
			)
	_report(modes, total, damage)
	quit()


## One rampage on the fixed loop: damage taken (hp lost; regen is 0, checked), shots and misses.
func _rampage(seed_id: int, mode: String) -> Dictionary:
	var species := Content.species_def("reptilian")
	var levels: Dictionary = LEVELS[_tier]
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 1000000.0  # the kaiju must not fall: this measures the army over the whole clock
	stats["run_seconds"] = 100000.0
	var tuning := CityGrowth.tuning_for(Content.tuning(), _tier)  # a deep copy
	var army_cfg: Dictionary = tuning["army"]
	var miss: Dictionary = army_cfg["miss"]
	if mode == "base":
		miss["hit_near"] = 1.0
		miss["hit_far"] = 1.0
	var air_cfg: Dictionary = tuning["air"]
	air_cfg["max"] = 0
	var layout := CityGrowth.layout(Content.tuning(), _tier, Seeds.make("city", seed_id))
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", seed_id))
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	assert(sim.stat("regen") == 0.0, "regen would hide damage in the hp delta")
	var corners: Array[Vector2] = []
	for c: Vector2 in LOOP:
		corners.append(c * sim.arena_half)
	var next := 0
	var hurt := 0.0
	var shots := 0
	var misses := 0
	var steps := roundi(_seconds / DT)
	var done := 0
	for n: int in steps:
		if sim.kaiju_pos.distance_to(corners[next]) < REACHED:
			next = (next + 1) % corners.size()
		var before := sim.hp
		for event: Dictionary in sim.step(
			DT, (corners[next] - sim.kaiju_pos).normalized(), false, 0
		):
			if str(event["type"]) == "tank_fired":
				shots += 1
				if event.get("miss", false):
					misses += 1
		hurt += maxf(0.0, before - sim.hp)
		done = n + 1
		if sim.over:
			break
	return {"damage": hurt, "shots": shots, "misses": misses, "seconds": done * DT}


func _report(modes: Array[String], total: Dictionary, damage: Dictionary) -> void:
	for mode: String in modes:
		var t: Dictionary = total[mode]
		print(
			(
				"TIER %d %s: %.4f damage per minute (%d runs, %.1f min, %d shots, %d misses)"
				% [
					_tier,
					mode,
					Num.f(t["damage"]) / maxf(0.001, Num.f(t["minutes"])),
					_seeds,
					t["minutes"],
					t["shots"],
					t["misses"]
				]
			)
		)
	if modes.size() < 2:
		return
	var base: Dictionary = damage["base"]
	var strays: Dictionary = damage["strays"]
	var tb: Dictionary = total["base"]
	var ts: Dictionary = total["strays"]
	var rate_base := Num.f(tb["damage"]) / maxf(0.001, Num.f(tb["minutes"]))
	var rate_strays := Num.f(ts["damage"]) / maxf(0.001, Num.f(ts["minutes"]))
	var diffs: Array[float] = []
	for seed_id: int in base:
		diffs.append(Num.f(strays[seed_id]) - Num.f(base[seed_id]))
	var mean := 0.0
	for d: float in diffs:
		mean += d
	mean /= maxf(1.0, diffs.size())
	var var_sum := 0.0
	for d: float in diffs:
		var_sum += (d - mean) * (d - mean)
	var se := sqrt(var_sum / maxf(1.0, diffs.size() - 1.0)) / sqrt(maxf(1.0, diffs.size()))
	print(
		(
			"TIER %d strays vs base: %+.2f%% (paired seed difference %.4f +- %.4f, 1 SE, %d seeds)"
			% [_tier, (rate_strays / maxf(0.0001, rate_base) - 1.0) * 100.0, mean, se, diffs.size()]
		)
	)
