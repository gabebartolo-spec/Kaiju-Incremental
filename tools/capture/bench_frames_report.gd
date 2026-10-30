extends RefCounted
## bench_frames.gd's report: the per-frame CSV and the summary block (BENCH_SUMMARY, one
## BENCH_PHASE line per phase window, pipelines, costs, timers), split out to keep files small.

const Lib := preload("res://tools/capture/bench_lib.gd")
const SUMMARY_FMT := (
	"BENCH_SUMMARY label=%s time=%s weather=%s graphics=%s "
	+ "stage=%s frames=%d first_fall=%d vsync=%s"
)
const PHASE_FMT := (
	"BENCH_PHASE %s n=%d wall p50 %.2f p95 %.2f p99 %.2f max %.2f "
	+ "| gpu p50 %.2f p95 %.2f p99 %.2f | rcpu p95 %.2f "
	+ "| proc+phys p95 %.2f p99 %.2f max %.2f | over16.7 %d over33.4 %d "
	+ "| draws p50 %.0f vis_draws %.0f sh_draws %.0f vis_prims %.0f sh_prims %.0f "
	+ "| vram_mb %.0f"
)
const TIMERS_FMT := (
	"BENCH_TIMERS building_stream worst %.1f ms, island break worst %.1f ms, "
	+ "street total %.1f ms worst %.1f ms (cumulative)"
)
const PHASE_FRAMES := 600


## The phase windows as [name, from, to) over measured frames: the first 10 s, the 10 s after
## that (the first big collapses, seen in every replay), and the last 10 s (peak ruin).
static func _phases(n: int, _first_fall: int) -> Array:
	return [
		["whole", 0, n],
		["walk_in", 0, mini(PHASE_FRAMES, n)],
		["first_collapses", mini(PHASE_FRAMES, n), mini(2 * PHASE_FRAMES, n)],
		["peak_ruin", maxi(0, n - PHASE_FRAMES), n],
	]


## Writes <out>/<label>.csv (one row per measured frame) and <out>/<label>_summary.txt, printing
## the summary: `a` is the tool's args, `lib` its route (steps and tally), `columns` the CSV's.
static func write(
	a: Dictionary,
	lib: Lib,
	columns: Array[String],
	rows: Array[PackedFloat64Array],
	facts: Dictionary,
) -> void:
	var first_fall: int = facts["first_fall"]
	var costs_max: Dictionary = facts["costs_max"]
	var break_max: int = facts["break_max"]
	var stream: BuildingStream = facts["stream"]
	var street: StreetLife = facts["street"]
	var rampage: Rampage = facts["rampage"]
	var label := str(a["label"])
	var dir := str(a["out"])
	var phases := _phases(rows.size(), first_fall)
	var csv := FileAccess.open("%s/%s.csv" % [dir, label], FileAccess.WRITE)
	csv.store_line(",".join(columns))
	for i: int in rows.size():
		var parts := PackedStringArray()
		for c: int in columns.size():
			parts.append("%.3f" % rows[i][c])
		parts[1] = _phase_of(i, phases)
		csv.store_line(",".join(parts))
	csv.close()
	var lines: Array[String] = []
	var col := func(name: String) -> int: return columns.find(name)
	lines.append(
		(
			SUMMARY_FMT
			% [
				label,
				a["time"],
				a["weather"],
				a["graphics"],
				a["stage"],
				rows.size(),
				first_fall,
				a["vsync"]
			]
		)
	)
	lines.append("BENCH_ROUTE steps=%d tally=%s" % [lib.steps, lib.tally])
	for ph: Array in phases:
		var from: int = ph[1]
		var to: int = ph[2]
		var s := func(name: String) -> Array:
			var out: Array = []
			for i: int in range(from, to):
				out.append(rows[i][col.call(name)])
			out.sort()
			return out
		var wall: Array = s.call("wall_ms")
		var gpu: Array = s.call("gpu_ms")
		var rcpu: Array = s.call("rcpu_ms")
		var proc_phys: Array = []
		for i: int in range(from, to):
			proc_phys.append(rows[i][col.call("proc_ms")] + rows[i][col.call("phys_ms")])
		proc_phys.sort()
		var draws: Array = s.call("draws")
		var vis_p: Array = s.call("vis_prims")
		var sh_p: Array = s.call("sh_prims")
		var vis_d: Array = s.call("vis_draws")
		var sh_d: Array = s.call("sh_draws")
		var vram: Array = s.call("vram_mb")
		(
			lines
			. append(
				(
					PHASE_FMT
					% [
						ph[0],
						wall.size(),
						Lib.pct(wall, 0.5),
						Lib.pct(wall, 0.95),
						Lib.pct(wall, 0.99),
						Lib.pct(wall, 1.0),
						Lib.pct(gpu, 0.5),
						Lib.pct(gpu, 0.95),
						Lib.pct(gpu, 0.99),
						Lib.pct(rcpu, 0.95),
						Lib.pct(proc_phys, 0.95),
						Lib.pct(proc_phys, 0.99),
						Lib.pct(proc_phys, 1.0),
						Lib.over(wall, 16.7),
						Lib.over(wall, 33.4),
						Lib.pct(draws, 0.5),
						Lib.pct(vis_d, 0.5),
						Lib.pct(sh_d, 0.5),
						Lib.pct(vis_p, 0.5),
						Lib.pct(sh_p, 0.5),
						Lib.pct(vram, 1.0),
					]
				)
			)
		)
	# Pipeline compilations: any rise after the warm-up is a first-use hitch.
	var pipes := ""
	for name: String in ["pipe_canvas", "pipe_mesh", "pipe_surface", "pipe_draw", "pipe_spec"]:
		var c: int = col.call(name)
		pipes += " %s %d->%d" % [name, rows[0][c], rows[rows.size() - 1][c]]
	lines.append("BENCH_PIPELINES" + pipes)
	var cost_text: Array[String] = []
	for key: Variant in costs_max:
		if Num.i(costs_max[key]) >= 1000:
			cost_text.append("%s %.1f" % [key, Num.i(costs_max[key]) / 1000.0])
	lines.append("BENCH_COSTS worst ms per frame: %s" % ", ".join(cost_text))
	lines.append(
		(
			TIMERS_FMT
			% [
				stream.worst_usec / 1000.0,
				break_max / 1000.0,
				(street.total_usec / 1000.0) if street != null else 0.0,
				(street.worst_usec / 1000.0) if street != null else 0.0
			]
		)
	)
	lines.append(
		(
			"BENCH_END sim_over=%s chunks_destroyed=%d"
			% [rampage.sim.over, rampage.sim.chunks_destroyed]
		)
	)
	var txt := FileAccess.open("%s/%s_summary.txt" % [dir, label], FileAccess.WRITE)
	for line: String in lines:
		print(line)
		txt.store_line(line)
	txt.close()


static func _phase_of(i: int, phases: Array) -> String:
	for k: int in range(phases.size() - 1, 0, -1):
		var ph: Array = phases[k]
		if i >= Num.i(ph[1]) and i < Num.i(ph[2]):
			return str(ph[0])
	return "whole"
