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
const Report := preload("res://tools/capture/bench_frames_report.gd")
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
		BenchCensus.at(root, i, _a)
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
	(
		Report
		. write(
			_a,
			_lib,
			COLUMNS,
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
