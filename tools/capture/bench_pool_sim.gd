extends SceneTree
## Sim cost per physics tick with the Tripo city pool (D-256) on and off: --rounds alternating
## runs (on, off, on, off...) of the stage 3 city (seed 0), the stage 3 body on Rampage's autoplay
## inputs, on a fixed 60 Hz clock with no view, so a slow PC's catch-up ticks multiply nothing.
## Prints the mean and p95 ms per tick over the first --window seconds after the kaiju has risen
## and over the last --window seconds of --seconds, then the means of each mode; when probes fill
## Engine meta "frame_cost", each probed cost per tick too, the costliest first.
##
##   godot --headless --path . --script tools/capture/bench_pool_sim.gd -- --rounds=4 --seconds=60

const Kit := preload("res://tools/capture/capture_kit.gd")
const STAGE := 3
const DT := 1.0 / 60.0
const GLIDE_CYCLE := 90  ## Rampage.AUTOPLAY_GLIDE_CYCLE
const GLIDE_HELD := 50  ## Rampage.AUTOPLAY_GLIDE_HELD

var _rounds := 4
var _seconds := 60.0
var _window := 5.0


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"rounds": _rounds, "seconds": _seconds, "window": _window})
	_rounds = Num.i(a["rounds"])
	_seconds = Num.f(a["seconds"])
	_window = Num.f(a["window"])
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var cfg: Dictionary = CityGrowth.tuning_for(Content.tuning(), STAGE)["city"]
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[STAGE - 1], "reptilian")
	var sums := {"on": PackedFloat64Array([0, 0, 0, 0]), "off": PackedFloat64Array([0, 0, 0, 0])}
	for k: int in _rounds:
		var mode := "on" if k % 2 == 0 else "off"
		var city := cfg if mode == "on" else _off(cfg)
		var layout := CityGen.generate(Seeds.make("city", 0), city)
		var got := _one(stats, layout)
		print("run %d pool %s: start %s; late %s" % [k, mode, _line(got, 0), _line(got, 2)])
		var s: PackedFloat64Array = sums[mode]
		for i: int in 4:
			s[i] += got[i] / ceilf(_rounds / 2.0)
	for mode: String in ["on", "off"]:
		var s: PackedFloat64Array = sums[mode]
		print("pool %s mean: start %s; late %s" % [mode, _line(s, 0), _line(s, 2)])
	quit()


## [start mean, start p95, late mean, late p95] ms per tick of one run.
func _one(stats: Dictionary, layout: Array[Dictionary]) -> PackedFloat64Array:
	Content.set_time(Content.time_for_run(2))
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 2))
	var ability: Dictionary = Content.species_def("reptilian")["ability"]
	sim.ability_type = str(ability["type"])
	sim.emerge.start(sim)
	sim.body.use_species("reptilian")
	var walk := AutoWalk.new()
	var ticks := int(_seconds * 60.0)
	var window := int(_window * 60.0)
	var start: Array[Array] = []
	var late: Array[Array] = []
	var risen := -1
	var steps := 0
	while steps < ticks + 6000 and not sim.over:
		var move := walk.move(sim, steps)
		var buttons := RampageSim.ULTIMATE
		buttons |= RampageSim.HELD if steps % GLIDE_CYCLE < GLIDE_HELD else 0
		Engine.set_meta("frame_cost", {})
		var t0 := Time.get_ticks_usec()
		sim.step(DT, move, sim.ability_ready_in <= 0.0, buttons)
		var row := [Time.get_ticks_usec() - t0, Engine.get_meta("frame_cost", {})]
		steps += 1
		if risen < 0:
			risen = steps if not sim.emerge.active else -1
			continue
		var since := steps - risen
		if since < window:
			start.append(row)
		elif since >= ticks - window and since < ticks:
			late.append(row)
		elif since >= ticks:
			break
	sim.dispose()
	var a := _stats(start, "start")
	var b := _stats(late, "late")
	return PackedFloat64Array([a[0], a[1], b[0], b[1]])


## [mean, p95] ms of `rows`; prints the probed costs per tick, the costliest first.
static func _stats(rows: Array[Array], what: String) -> PackedFloat64Array:
	if rows.is_empty():
		return PackedFloat64Array([0, 0])
	var spent: Array[int] = []
	var total := 0
	var parts: Dictionary = {}
	for row: Array in rows:
		var usec: int = row[0]
		spent.append(usec)
		total += usec
		var costs: Dictionary = row[1]
		for key: String in costs:
			parts[key] = Num.i(parts.get(key, 0)) + Num.i(costs[key])
	spent.sort()
	var n := float(rows.size())
	var keys: Array = parts.keys()
	keys.sort_custom(func(x: Variant, y: Variant) -> bool: return Num.i(parts[x]) > Num.i(parts[y]))
	var top: Array[String] = []
	for key: Variant in keys.slice(0, 12):
		top.append("%s %.2f" % [key, Num.i(parts[key]) / 1000.0 / n])
	if not top.is_empty():
		print("  %s per tick: %s" % [what, ", ".join(top)])
	var p95 := spent[mini(rows.size() - 1, int(n * 0.95))] / 1000.0
	return PackedFloat64Array([total / 1000.0 / n, p95])


static func _line(t: PackedFloat64Array, at: int) -> String:
	return "%.2f ms/tick (p95 %.2f)" % [t[at], t[at + 1]]


## `cfg` with the pool's placement off (today's city), as bench_pool_frames.
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
