extends SceneTree
## The 4K speed baseline (render plan Phase 0, docs/research/2026-10-26-render-baseline.md):
## the adult
## city (stage 3, army seed 0, the reptilian) with a recorded route replayed on it, every frame
## measured, one CSV and one summary block. Grown from bench_rampage.gd.
##
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 --disable-vsync \
##     --script tools/capture/bench_frames.gd -- --time=night --weather=clear --graphics=medium \
##     --route-file=<route.json> --out=<dir> --label=A_medium
##   --frames=3600 --warmup=120   120 frames to settle, then 3600 measured (60 s at 60 fps)
##   --time=dusk|night|morning|noon  --weather=clear|rain  --graphics=potato|low|medium|high|max
##   --route=replay (the recorded inputs; capture_one_look.gd --route=record makes them)
##   --vsync   keep vsync on (the pacing run); default off for the GPU-time run
##   --set=key=value,...  (look overrides)  --tune=section.key=value,...  (tuning.json numbers)
## Phases: walk-in = the first 600 measured frames; first collapses = frames 600-1200;
## peak ruin = the last 600. Every number is also in <out>/<label>.csv per frame.

const Lib := preload("res://tools/capture/bench_lib.gd")
const Kit := preload("res://tools/capture/capture_kit.gd")
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
const IDLE_SCAN := 120  # frames between scans of the island bodies (a node search is not free)
const COLUMNS: Array[String] = [
	"frame",
	"phase",
	"wall_ms",
	"gpu_ms",
	"rcpu_ms",
	"proc_ms",
	"phys_ms",
	"draws",
	"prims",
	"objs",
	"vis_draws",
	"vis_prims",
	"vis_objs",
	"sh_draws",
	"sh_prims",
	"sh_objs",
	"vram_mb",
	"tex_mb",
	"buf_mb",
	"pipe_canvas",
	"pipe_mesh",
	"pipe_surface",
	"pipe_draw",
	"pipe_spec",
	"debris_live",
	"rubble",
	"bodies_all",
	"jolt_active",
	"nodes",
	"sim_step_ms",
	"street_ms",
	"phys_span_ms",
	"proc_span_ms",
	"draw_span_ms",
]

var _a: Dictionary
var _lib := Lib.new()
## The frame's CPU phases off the engine's own signals (Performance's TIME_PROCESS and
## TIME_PHYSICS_PROCESS read above wall, so unusable): physics steps (first physics_frame to
## process_frame), process (to frame_pre_draw), draw (to frame_post_draw). Each row holds the
## previous frame's spans, the last ones complete when its process_frame fires.
var _t_phys := 0
var _t_proc := 0
var _t_pre := 0
var _spans := Vector3.ZERO


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var defaults := Lib.DEFAULTS.duplicate()
	defaults.merge({"frames": 3600, "warmup": 120, "out": "user://bench", "label": "run"})
	_a = Kit.args(defaults)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(str(_a["out"]))
	var vp := root.get_viewport_rid()
	if _a["vsync"] != true:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	if not await _lib.start(self, _a):
		quit(1)
		return
	var rampage := _lib.rampage
	var city := _lib.city
	Kit.measure_on(self)
	physics_frame.connect(_physics_started)
	process_frame.connect(func() -> void: _t_proc = Time.get_ticks_usec())
	RenderingServer.frame_pre_draw.connect(func() -> void: _t_pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(_frame_drawn)
	print(
		(
			"BENCH start frames_drawn=%d size=%s gpu=%s"
			% [Engine.get_frames_drawn(), root.size, RenderingServer.get_video_adapter_name()]
		)
	)
	print(
		(
			"BENCH renderer=%s buildings=%d"
			% [RenderingServer.get_current_rendering_method(), rampage.sim.buildings.size()]
		)
	)
	for _i: int in Num.i(_a["warmup"]):
		await process_frame
	rampage.cost_usec.clear()
	var carve: Node = null
	var found := Lib.nodes_of(self, "CarvePhysics")
	if not found.is_empty():
		carve = found[0]
	var debris: DebrisField = city.get("_debris")
	var street := city.street
	var stream: BuildingStream = city.get("_stream")
	var rows: Array[PackedFloat64Array] = []
	var costs_max: Dictionary = {}
	var break_max := 0
	var street_prev := street.total_usec if street != null else 0
	var first_fall := -1
	var total := Num.i(_a["frames"])
	var last := Time.get_ticks_usec()
	for i: int in total:
		await process_frame
		var now := Time.get_ticks_usec()
		var wall := (now - last) / 1000.0
		last = now
		var row := PackedFloat64Array()
		row.resize(COLUMNS.size())
		var sim_step := Num.f(rampage.cost_usec.get("sim.step", 0)) / 1000.0
		for key: Variant in rampage.cost_usec:
			costs_max[key] = maxi(Num.i(costs_max.get(key, 0)), Num.i(rampage.cost_usec[key]))
		rampage.cost_usec.clear()
		if first_fall < 0 and _lib.rampage.sim.next_fall_id > 0:
			first_fall = i
		var street_ms := 0.0
		if street != null:
			street_ms = (street.total_usec - street_prev) / 1000.0
			street_prev = street.total_usec
		var vis := _info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE)
		var shadow := _info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW)
		var all_bodies := 0
		var debris_live := 0
		var rubble := 0
		if carve != null:
			all_bodies = Num.i(carve.call("all_bodies"))
			debris_live = Num.i(carve.call("live_bodies"))
			rubble = Num.i(carve.call("rubble_pieces"))
		if debris != null:
			var live_bodies: Array = debris.get("_bodies")
			debris_live += live_bodies.size()
		if i % IDLE_SCAN == 0:
			for node: Node in Lib.nodes_of(self, "IslandBody"):
				break_max = maxi(break_max, Num.i(node.get("last_break_us")))
		var v := [
			i,
			0,
			wall,
			RenderingServer.viewport_get_measured_render_time_gpu(vp),
			RenderingServer.viewport_get_measured_render_time_cpu(vp),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			vis[0],
			vis[1],
			vis[2],
			shadow[0],
			shadow[1],
			shadow[2],
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION),
			debris_live,
			rubble,
			all_bodies,
			Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			sim_step,
			street_ms,
			_spans.x,
			_spans.y,
			_spans.z,
		]
		for c: int in COLUMNS.size():
			row[c] = Num.f(v[c])
		rows.append(row)
		if rampage.sim.over:
			print("BENCH run over at measured frame %d (%s)" % [i, rampage.sim.end_reason])
			break
	_write(
		rows,
		{
			"first_fall": first_fall,
			"costs_max": costs_max,
			"break_max": break_max,
			"stream": stream,
			"street": street,
			"rampage": rampage,
		}
	)
	quit()


## [draw calls, primitives, objects] of one render pass kind this frame.
func _physics_started() -> void:
	if _t_phys == 0:
		_t_phys = Time.get_ticks_usec()


func _frame_drawn() -> void:
	var phys := (_t_proc - _t_phys) / 1000.0 if _t_phys > 0 else 0.0
	_spans = Vector3(phys, (_t_pre - _t_proc) / 1000.0, (Time.get_ticks_usec() - _t_pre) / 1000.0)
	_t_phys = 0


func _info(vp: RID, kind: RenderingServer.ViewportRenderInfoType) -> Array:
	return [
		RenderingServer.viewport_get_render_info(
			vp, kind, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
		),
		RenderingServer.viewport_get_render_info(
			vp, kind, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME
		),
		RenderingServer.viewport_get_render_info(
			vp, kind, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME
		),
	]


## The phase windows as [name, from, to) over measured frames: the first 10 s, the 10 s after
## that (the first big collapses, seen in every replay), and the last 10 s (peak ruin).
func _phases(n: int, _first_fall: int) -> Array:
	return [
		["whole", 0, n],
		["walk_in", 0, mini(PHASE_FRAMES, n)],
		["first_collapses", mini(PHASE_FRAMES, n), mini(2 * PHASE_FRAMES, n)],
		["peak_ruin", maxi(0, n - PHASE_FRAMES), n],
	]


func _write(rows: Array[PackedFloat64Array], facts: Dictionary) -> void:
	var first_fall: int = facts["first_fall"]
	var costs_max: Dictionary = facts["costs_max"]
	var break_max: int = facts["break_max"]
	var stream: BuildingStream = facts["stream"]
	var street: StreetLife = facts["street"]
	var rampage: Rampage = facts["rampage"]
	var label := str(_a["label"])
	var dir := str(_a["out"])
	var phases := _phases(rows.size(), first_fall)
	var csv := FileAccess.open("%s/%s.csv" % [dir, label], FileAccess.WRITE)
	csv.store_line(",".join(COLUMNS))
	for i: int in rows.size():
		var parts := PackedStringArray()
		for c: int in COLUMNS.size():
			parts.append("%.3f" % rows[i][c])
		parts[1] = _phase_of(i, phases)
		csv.store_line(",".join(parts))
	csv.close()
	var lines: Array[String] = []
	var col := func(name: String) -> int: return COLUMNS.find(name)
	lines.append(
		(
			SUMMARY_FMT
			% [
				label,
				_a["time"],
				_a["weather"],
				_a["graphics"],
				_a["stage"],
				rows.size(),
				first_fall,
				_a["vsync"]
			]
		)
	)
	lines.append("BENCH_ROUTE steps=%d tally=%s" % [_lib.steps, _lib.tally])
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


func _phase_of(i: int, phases: Array) -> String:
	for k: int in range(phases.size() - 1, 0, -1):
		var ph: Array = phases[k]
		if i >= Num.i(ph[1]) and i < Num.i(ph[2]):
			return str(ph[0])
	return "whole"
