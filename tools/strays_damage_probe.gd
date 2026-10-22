extends SceneTree
## Fixed-path damage probe for the clumsy army (director, comments #18; D-066, D-157): the army's
## damage to the kaiju must stay within 5% of the base behaviour (every shell hits). The kaiju
## walks one scripted loop of waypoints (no autoplay, so a stray that breaks a building cannot
## change where it goes), with the same city, tanks and seeds in both modes:
##   base:   army.miss hit_near = hit_far = 1.0 (every shell hits for full damage)
##   strays: data/tuning.json as it stands (a hit chance that falls with range, misses land beside)
## Helicopters are ON by default (D-157: the chunks a stray breaks count, so they call the
## helicopters in earlier); --air=off turns them off to isolate the tanks and squads.
## Prints one ROW per run (damage per minute split by source, shots, squads lost, chunks) and, per
## tier, each mode's mean and standard error and the paired strays-minus-base difference, for the
## damage as it fell and for the expected damage (every shot at the kaiju x the damage of a hit,
## which leaves out the luck of which shells hit and so has a smaller standard error).
##   godot --headless --path . --script tools/strays_damage_probe.gd -- \
##     [--tier=2] [--first=0] [--seeds=24] [--seconds=120] [--mode=both|base|strays] [--air=on|off]
## Run it with its own APPDATA, as tools/run_tests.sh does. Damage by source is approximate: the
## helicopter and squad shares are counted from their events, the tanks' is the rest.

const DT := 1.0 / 15.0
const LEVELS := {1: {}, 2: {"evolve1": 1}, 3: {"evolve1": 1, "evolve2": 1}}
## The loop's corners, as a fraction of the arena's half width; a corner counts as reached
## within REACHED metres.
const LOOP := [Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5), Vector2(0.5, -0.5)]
const REACHED := 3.0
## The numbers printed per mode: damage per minute (all, tanks, squads, helicopters) and counts
## per run: shots, squads' volleys and losses, helicopter shots, tanks that came, chunks broken;
## and why tanks fire less: tanks destroyed, tank-steps alive, in range of the kaiju, of those
## without a clear line, towers toppled and roads they shut by the end.
const FIELDS := [
	"damage",
	"expected",
	"tank_dmg",
	"roof_dmg",
	"heli_dmg",
	"shots",
	"misses",
	"volleys",
	"squads_lost",
	"heli_shots",
	"tanks",
	"chunks",
	"tanks_lost",
	"tank_steps",
	"in_range",
	"no_line",
	"topples",
	"roads_shut"
]

var _tier := 2
var _first := 0
var _seeds := 24
var _seconds := 120.0
var _mode := "both"
var _air := true


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
		if arg.begins_with("--air="):
			_air = arg.substr(6) != "off"
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var modes: Array[String] = ["base", "strays"]
	if _mode != "both":
		modes = [_mode]
	var rows := {}  # mode -> {seed: row}
	for mode: String in modes:
		rows[mode] = {}
	for seed_id: int in range(_first, _first + _seeds):
		for mode: String in modes:
			var r := _rampage(seed_id, mode)
			var by_seed: Dictionary = rows[mode]
			by_seed[seed_id] = r
			var line := "ROW tier %d seed %d %s" % [_tier, seed_id, mode]
			for key: String in FIELDS:
				line += " %s %.4f" % [key, Num.f(r[key])]
			print(line + " seconds %.1f" % Num.f(r["seconds"]))
	_report(modes, rows)
	quit()


## One rampage on the fixed loop: damage taken (hp lost; regen is 0, checked) by source, shots
## and misses, squads lost, chunks broken. Damage fields are per minute.
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
	if not _air:
		air_cfg["max"] = 0
	var layout := CityGrowth.layout(Content.tuning(), _tier, Seeds.make("city", seed_id))
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", seed_id))
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	assert(sim.stat("regen") == 0.0, "regen would hide damage in the hp delta")
	var corners: Array[Vector2] = []
	for c: Vector2 in LOOP:
		corners.append(c * sim.arena_half)
	var hit := maxf(
		Num.f(army_cfg["min_damage"]), Num.f(army_cfg["tank_damage"]) - sim.stat("armor")
	)
	var heli_hit := maxf(
		Num.f(army_cfg["min_damage"]), Num.f(air_cfg["damage"]) - sim.stat("armor")
	)
	var row := {}
	for key: String in FIELDS:  # the counts start at nothing; the damage fields are set at the end
		row[key] = 0.0
	var tank_dmg := 0.0
	var roof_dmg := 0.0
	var heli_dmg := 0.0
	var next := 0
	var steps := roundi(_seconds / DT)
	var done := 0
	for n: int in steps:
		if sim.kaiju_pos.distance_to(corners[next]) < REACHED:
			next = (next + 1) % corners.size()
		var before := sim.hp
		var roofs := 0
		var helis := 0
		for event: Dictionary in sim.step(
			DT, (corners[next] - sim.kaiju_pos).normalized(), false, 0
		):
			_tally(event, row)
			roofs += 1 if str(event["type"]) == "rooftop_fired" else 0
			helis += 1 if str(event["type"]) == "heli_fired" else 0
		_count_range(sim, row)
		var lost := maxf(0.0, before - sim.hp)
		var roof_part := roofs * sim.army_units.volley()
		var heli_part := helis * heli_hit
		roof_dmg += roof_part
		heli_dmg += heli_part
		tank_dmg += lost - roof_part - heli_part
		row["heli_shots"] = Num.f(row["heli_shots"]) + helis
		done = n + 1
		if sim.over:
			break
	var minutes := maxf(0.001, done * DT / 60.0)
	row["damage"] = (tank_dmg + roof_dmg + heli_dmg) / minutes
	row["expected"] = (Num.f(row["shots"]) * hit + roof_dmg + heli_dmg) / minutes
	row["tank_dmg"] = tank_dmg / minutes
	row["roof_dmg"] = roof_dmg / minutes
	row["heli_dmg"] = heli_dmg / minutes
	row["volleys"] = sim.army_units.volleys
	row["squads_lost"] = sim.army_units.rooftops_destroyed
	row["chunks"] = sim.chunks_destroyed
	row["tanks_lost"] = sim.tanks_destroyed
	for shut: int in sim.army_units.convoy.graph.blocked:
		row["roads_shut"] = Num.f(row.get("roads_shut", 0.0)) + float(shut)
	row["seconds"] = done * DT
	return row


## Counts one event into the row: tank shots at the kaiju (all, and misses), tanks that came,
## towers toppled (a carved scrap blocks no road).
func _tally(event: Dictionary, row: Dictionary) -> void:
	match str(event["type"]):
		"tank_fired":
			if event.has("at") and not event.get("miss", false):
				return  # a shot at a young of the brood
			row["shots"] = Num.f(row["shots"]) + 1.0
			row["misses"] = Num.f(row["misses"]) + (1.0 if event.get("miss", false) else 0.0)
		"tank_spawned":
			row["tanks"] = Num.f(row["tanks"]) + 1.0
		"fall_land":
			if str(event.get("kind", "")) == "topple" and event.get("scrap", false) != true:
				row["topples"] = Num.f(row["topples"]) + 1.0


## Tank-steps within the tanks' reach of the kaiju, and of those the ones with no clear line.
func _count_range(sim: RampageSim, row: Dictionary) -> void:
	var reach := Num.f(sim.army["range"]) + sim.stomp_radius() + 1.0
	for tank: RampageSim.Tank in sim.tanks:
		row["tank_steps"] = Num.f(row["tank_steps"]) + 1.0
		if tank.pos.distance_to(sim.kaiju_pos) > reach:
			continue
		row["in_range"] = Num.f(row["in_range"]) + 1.0
		if not sim.army_units.convoy.clear_line(tank.pos, sim.kaiju_pos):
			row["no_line"] = Num.f(row["no_line"]) + 1.0


## Mean and standard error of values.
func _mean_se(values: Array[float]) -> Vector2:
	var n := maxf(1.0, values.size())
	var mean := 0.0
	for v: float in values:
		mean += v
	mean /= n
	var squares := 0.0
	for v: float in values:
		squares += (v - mean) * (v - mean)
	return Vector2(mean, sqrt(squares / maxf(1.0, n - 1.0)) / sqrt(n))


func _column(by_seed: Dictionary, key: String) -> Array[float]:
	var values: Array[float] = []
	for seed_id: int in by_seed:
		var row: Dictionary = by_seed[seed_id]
		values.append(Num.f(row[key]))
	return values


func _report(modes: Array[String], rows: Dictionary) -> void:
	for mode: String in modes:
		var line := (
			"TIER %d %s (%d seeds, %.0f s, air %s):"
			% [_tier, mode, _seeds, _seconds, "on" if _air else "off"]
		)
		var by_seed: Dictionary = rows[mode]
		for key: String in FIELDS:
			var ms := _mean_se(_column(by_seed, key))
			line += " %s %.2f+-%.2f" % [key, ms.x, ms.y]
		print(line)
	if modes.size() < 2:
		return
	var base: Dictionary = rows["base"]
	var strays: Dictionary = rows["strays"]
	var line := "TIER %d strays-base (paired, mean +- 1 SE):" % _tier
	for key: String in FIELDS:
		var diffs: Array[float] = []
		var a := _column(base, key)
		var b := _column(strays, key)
		for i: int in a.size():
			diffs.append(b[i] - a[i])
		var ms := _mean_se(diffs)
		line += " %s %+.2f+-%.2f" % [key, ms.x, ms.y]
	print(line)
	_headline(base, strays, "damage", "as it fell")
	_headline(base, strays, "expected", "expected (every shot at the kaiju x a hit's damage)")


## The budget line: the paired strays-minus-base difference in `key` as a share of the base.
func _headline(base: Dictionary, strays: Dictionary, key: String, what: String) -> void:
	var a := _column(base, key)
	var b := _column(strays, key)
	var diffs: Array[float] = []
	for i: int in a.size():
		diffs.append(b[i] - a[i])
	var d_base := _mean_se(a)
	var diff := _mean_se(diffs)
	var scale := 100.0 / maxf(0.0001, d_base.x)
	print(
		(
			"TIER %d damage per minute %s, strays vs base: %+.2f%% +- %.2f%% (1 SE, %d seeds; base %.2f)"
			% [_tier, what, diff.x * scale, diff.y * scale, _seeds, d_base.x]
		)
	)
