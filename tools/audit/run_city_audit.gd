extends SceneTree
## The three city audits (D-265) at full size, writing their tables and pictures:
##   godot --headless --path . --script tools/audit/run_city_audit.gd -- \
##       [--audit=roads,seeds,assets] [--seeds=N] [--out=C:/kt/audits]
## roads: every stage x 50 map seeds (tools/audit/road_audit.gd): per-seed pass/fail table,
##   rule counts, histograms, a top-down PNG per failing seed (<out>/roads/).
## seeds: every stage, pairwise over 20 run indices through the game's own run seeding
##   (CitySeed) and, for comparison, with the map seed and stream varied too
##   (tools/audit/seed_audit.gd).
## assets: 3 stages x 20 seeds, every placeable asset's appearances (tools/audit/asset_audit.gd).
## Each writes <out>/<audit>.json and <out>/<audit>.md; the suite (tests/run_city_audit_tests.gd)
## runs the same tools on fewer seeds.

const Roads := preload("res://tools/audit/road_audit.gd")
const Png := preload("res://tools/audit/audit_png.gd")
const Report := preload("res://tools/audit/audit_report.gd")
const SeedAudit := preload("res://tools/audit/seed_audit.gd")
const AssetAudit := preload("res://tools/audit/asset_audit.gd")

var _args := {"audit": "roads,seeds,assets", "seeds": "", "out": "C:/kt/audits"}


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	var wanted := str(_args["audit"]).split(",")
	var out := str(_args["out"])
	DirAccess.make_dir_recursive_absolute(out)
	if "roads" in wanted:
		_roads(out, _count(50))
	if "seeds" in wanted:
		_write(out, "seeds", SeedAudit.run_all(Content.tuning(), _count(20)))
	if "assets" in wanted:
		_write(out, "assets", await AssetAudit.run_all(root, _count(20)))
	quit(0)


func _count(default: int) -> int:
	var s := str(_args["seeds"])
	return default if s.is_empty() else s.to_int()


func _roads(out: String, count: int) -> void:
	var rows: Array[Dictionary] = []
	var base := Content.tuning()
	var started := Time.get_ticks_msec()
	for tier: int in [1, 2, 3]:
		for map_seed: int in Roads.seeds(count):
			var cfg := Roads.city(base, tier, map_seed)
			var got := Roads.run(cfg)
			var violations: Array = got["violations"]
			var row := {
				"tier": tier,
				"seed": map_seed,
				"rules": Roads.by_rule(violations),
				"metrics": got["metrics"],
				"examples": violations.slice(0, 6),
			}
			if not violations.is_empty():
				var png := "%s/roads/stage%d_seed%d.png" % [out, tier, map_seed]
				var plan: Dictionary = got["plan"]
				Png.save(plan, cfg, violations, png)
				row["png"] = png
			rows.append(row)
	print("roads: %d cities in %d ms" % [rows.size(), Time.get_ticks_msec() - started])
	_write(out, "roads", Report.roads(rows))


func _write(out: String, audit: String, result: Dictionary) -> void:
	var json := FileAccess.open("%s/%s.json" % [out, audit], FileAccess.WRITE)
	json.store_string(JSON.stringify(result["data"], "\t"))
	var md := FileAccess.open("%s/%s.md" % [out, audit], FileAccess.WRITE)
	md.store_string(str(result["markdown"]))
	print(str(result["summary"]))
