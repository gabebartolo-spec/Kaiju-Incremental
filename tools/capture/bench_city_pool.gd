extends SceneTree
## Generation time with the Tripo city pool (D-256) on and off: per growth stage, the wall-clock
## ms of building the city (CityGen.generate with the stage's tuning) and its sim (RampageSim.new),
## averaged over --seeds city seeds. Headless.
##
##   godot --headless --path . --script tools/capture/bench_city_pool.gd -- --seeds=10

const Kit := preload("res://tools/capture/capture_kit.gd")

var _seeds := 10


func _initialize() -> void:
	_seeds = Num.i(Kit.args({"seeds": _seeds})["seeds"])
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var tuning := Content.tuning()
	var stats := Kit.stats("reptilian")
	for stage: int in range(1, CityGrowth.stage_count(tuning) + 1):
		var cfg: Dictionary = CityGrowth.tuning_for(tuning, stage)["city"]
		var line := "stage %d:" % stage
		for on: bool in [false, true]:
			var city := cfg if on else _off(cfg)
			var gen := 0
			var build := 0
			var count := 0
			for s: int in _seeds:
				var t0 := Time.get_ticks_usec()
				var layout := CityGen.generate(Seeds.make("city", s), city)
				var t1 := Time.get_ticks_usec()
				var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
				build += Time.get_ticks_usec() - t1
				gen += t1 - t0
				count += sim.buildings.size()
			line += (
				" pool %s gen %.1f ms sim %.1f ms (%d buildings);"
				% [
					"on" if on else "off",
					gen / 1000.0 / _seeds,
					build / 1000.0 / _seeds,
					count / _seeds,
				]
			)
		print(line)
	quit()


## `cfg` with the pool's placement off (today's city).
static func _off(cfg: Dictionary) -> Dictionary:
	var out := cfg.duplicate()
	var shared_book: Dictionary = cfg["building_pool"]
	var book := shared_book.duplicate()
	var shared_pl: Dictionary = book["placement"]
	var pl := shared_pl.duplicate()
	pl["on"] = false
	book["placement"] = pl
	out["building_pool"] = book
	return out
