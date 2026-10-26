extends SceneTree
## Road-geometry counts (D-265 follow-up): per stage, over the roads audit's map seeds, the four
## defect classes the city audit named: thin blocks (short side under THIN_M), overlapping
## junction boxes ("close!"), road pieces over open water, junctions with more than 5 arms.
##   godot --headless --path . --script tools/audit/road_geometry_counts.gd -- [--seeds=50]
## Prints one line per stage (mean, min-max, cities with any) and the shipped plan's counts.

const Roads := preload("res://tools/audit/road_audit.gd")
const THIN_M := 2.0  # CityLots' narrowest lot: a block under this holds no building

var _seeds := 50
var _detail := false
var _sweep := false


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			_seeds = arg.trim_prefix("--seeds=").to_int()
		if arg == "--detail":
			_detail = true
		if arg == "--sweep":
			_sweep = true
	var base := Content.tuning()
	if _sweep:
		_run_sweep(base)
		quit(0)
		return
	for tier: int in [1, 2, 3]:
		var sums := {"thin": [], "close!": [], "water": [], "arms": [], "close": [], "aspect": [],
			"blocks": [], "short_dm": [], "long_dm": []}
		for map_seed: int in Roads.seeds(_seeds):
			var cfg := Roads.city(base, tier, map_seed)
			var got := Roads.run(cfg)
			var violations: Array = got["violations"]
			var plan: Dictionary = got["plan"]
			var rules := Roads.by_rule(violations)
			rules["aspect"] = Num.i(got["metrics"]["stretched_blocks"])
			var size := block_sizes(plan, cfg)
			rules["blocks"] = Num.i(size[0])
			rules["short_dm"] = roundi(size[1] * 10.0)  # mean short side, decimetres
			rules["long_dm"] = roundi(size[2] * 10.0)
			for key: String in sums:
				var list: Array = sums[key]
				list.append(Num.i(rules.get(key, 0)))
			if map_seed == Roads.SHIPPED_SEED:
				print("stage %d shipped seed %d: %s" % [tier, map_seed, rules])
			if _detail:
				for v: Dictionary in violations:
					if str(v["rule"]) in ["arms", "water"] or str(v["note"]).contains("overlap"):
						print("  s%d %d %s %s %s" % [tier, map_seed, v["rule"], v["at"], v["note"]])
		var line := "stage %d:" % tier
		for key: String in sums:
			var list: Array = sums[key]
			line += " %s %s" % [key, _stat(list)]
		print(line)
	quit(0)


## [count, mean short side, mean long side] of the real city's blocks (not river).
static func block_sizes(plan: Dictionary, cfg: Dictionary) -> Array[float]:
	var extent := CityBand.extent(cfg)
	var n := 0.0
	var lo := 0.0
	var hi := 0.0
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		if CityBand.near_edge(rect) >= extent or str(block["use"]) == "river":
			continue
		n += 1.0
		lo += minf(rect.size.x, rect.size.y)
		hi += maxf(rect.size.x, rect.size.y)
	return [n, lo / maxf(n, 1.0), hi / maxf(n, 1.0)]


## Blocks of the real city (not river) whose short side is under THIN_M.
static func thin_blocks(plan: Dictionary, cfg: Dictionary) -> int:
	var extent := CityBand.extent(cfg)
	var n := 0
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		if CityBand.near_edge(rect) >= extent or str(block["use"]) == "river":
			continue
		if minf(rect.size.x, rect.size.y) < THIN_M:
			n += 1
	return n


func _stat(list: Array) -> String:
	var total := 0
	var lo := 1 << 30
	var hi := 0
	var any := 0
	for v: int in list:
		total += v
		lo = mini(lo, v)
		hi = maxi(hi, v)
		any += 1 if v > 0 else 0
	return "%.1f (%d-%d, %d)" % [float(total) / maxi(1, list.size()), lo, hi, any]


## Scratch: close! pairs over the seeds at stage 3 for each diagonal through-point z offset.
func _run_sweep(base: Dictionary) -> void:
	var city: Dictionary = base["city"]
	var through: Array = city["diagonal_through"]
	var z0 := Num.f(through[1])
	for dz: int in range(-14, 15):
		var t: Dictionary = base.duplicate(true)
		t["city"]["diagonal_through"] = [through[0], z0 + dz]
		var bad := 0
		var cities := 0
		for map_seed: int in Roads.seeds(_seeds):
			var cfg := Roads.city(t, 3, map_seed)
			var got := Roads.run(cfg)
			var violations: Array = got["violations"]
			var n := Num.i(Roads.by_rule(violations).get("close!", 0))
			bad += n
			cities += 1 if n > 0 else 0
		print("sweep dz %d (z %.0f): close! %d in %d cities" % [dz, z0 + dz, bad, cities])
