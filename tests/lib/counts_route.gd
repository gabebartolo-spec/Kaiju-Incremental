extends RefCounted
## The countable bars of the night speed runs, checked on every PR (D-351: bars that can be counted
## move to GitHub; only millisecond bars stay on the director's PC). The pinned adult-city route
## (tools/capture/routes/replay_adult.json, the one render plan items 8 and 13 replay) is played
## headless through the speed runs' own set-up (tools/capture/bench_lib.gd: city seed 0, stage 3,
## night, medium preset, the route's recorded input on the real input path), for the speed run's
## own window (120 warm-up frames and 3,600 measured, or until the run is over).
## What it counts: FxPool (render plan item 8), the most slots of each kind in use at once. This is
## the item-8 sizing run: every kind gets more slots than it can use (_measure), so none runs out
## and each peak is the true peak. Valid headless: slots are taken and given back on the node tree,
## SceneTree timers and GPUParticles3D `finished` (emitted from the node's own process delta), all
## on the suites' fixed frame clock. Draw calls, by contrast, read 0 under the dummy renderer.
## Bar, once tuning render_opt.fx_pool.provisional_sizes is off: every kind's true peak fits its
## shipped slots, so no burst on the route finds every slot busy and builds a system (the hitch
## item 8 removed). While the sizes are provisional the peaks are printed only (they size them).
## Printed: each pool's "FXPOOL peak/slots" line (what the item-8 sizing script reads), the frame
## each peak was reached and the most taken in one frame, NOTICE lines (annotations on GitHub) and
## the particle systems built outside the pool during the route, by host.

const Lib := preload("res://tools/capture/bench_lib.gd")
const ROUTE := "res://tools/capture/routes/replay_adult.json"
## Slots a kind for the measuring run (the item-8 sizing run's count).
const MEASURE := 300
## Kinds that need more to measure: dust peaks at 373 at once on this route (the 1.5x city, #413;
## 2,687 before the FxPool owner fix, when the city's dust slots leaked to the other pool); 5,000
## measures either.
const MEASURE_MORE := {"dust": 5000}
## The speed run's window (bench_frames.gd: --warmup=120 --frames=3600).
const FRAMES := 3720

var _check: Callable
var _tree: SceneTree
var _lib := Lib.new()
var _built: Dictionary = {}  # host class name -> GPUParticles3D built outside the pool
var _built_total := 0
var _top: Dictionary = {}  # kind -> its peak so far
var _peak_at: Dictionary = {}  # kind -> the frame its peak was last raised
var _jump: Dictionary = {}  # kind -> [the most more in use than a frame before, that frame]
var _was: Dictionary = {}  # kind -> slots in use at the end of the last frame


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


static func _measure(kind: String) -> int:
	return Num.i(MEASURE_MORE.get(kind, MEASURE))


func _added(node: Node) -> void:
	if node is GPUParticles3D and not node.has_meta("fx_kind"):
		_built_total += 1
		var host := node.get_parent()
		var key := host.get_class() if host != null else "none"
		var script: Script = host.get_script() if host != null else null
		if script != null and script.get_global_name() != &"":
			key = str(script.get_global_name())
		_built[key] = Num.i(_built.get(key, 0)) + 1


func run() -> void:
	var cfg: Dictionary = Content.section("render_opt")["fx_pool"]
	var table: Dictionary = cfg["slots"]
	var shipped := table.duplicate()
	var tune: PackedStringArray = []
	for kind: String in shipped:
		tune.append("render_opt.fx_pool.slots.%s=%d" % [kind, _measure(kind)])
	var a := Lib.DEFAULTS.duplicate()
	a["route-file"] = ROUTE
	a["tune"] = ",".join(tune)
	var began := Time.get_ticks_msec()
	print("COUNTS set-up starts %.0f s after the engine started" % (began / 1000.0))
	var started: bool = await _lib.start(_tree, a)
	cfg["slots"] = shipped.duplicate()  # the pools are built: the tuning reads as shipped again
	_check.call(started, "the speed runs' set-up builds the adult city and arms %s" % ROUTE)
	if not started:
		return
	_tree.node_added.connect(_added)
	var sim := _lib.rampage.sim
	var pools := Lib.nodes_of(_tree, "FxPool")
	var route_steps := _lib.route.size()
	var first_step := _lib.steps
	var frames := 0
	while frames < FRAMES and not sim.over:
		await _tree.process_frame
		frames += 1
		_sample(pools, frames)
	_tree.node_added.disconnect(_added)
	print(
		(
			"COUNTS route steps=%d/%d (step %d at frame 0) frames=%d over=%s"
			% [mini(_lib.steps, route_steps), route_steps, first_step, frames, sim.over]
		)
	)
	print("COUNTS tally=%s wall_s=%.0f" % [_lib.tally, (Time.get_ticks_msec() - began) / 1000.0])
	_check.call(
		_lib.steps >= route_steps, "the route played all %d steps (%d)" % [route_steps, _lib.steps]
	)
	_check.call(
		Num.i(_lib.tally["falls"]) > 0, "the route brings buildings down (%s)" % [_lib.tally]
	)
	var provisional: bool = cfg.get("provisional_sizes", false) == true
	_pools(pools, shipped, provisional)
	print("COUNTS built outside the pool during the route: %d %s" % [_built_total, _built])
	var freeing := Time.get_ticks_msec()
	_lib.rampage.queue_free()
	await _tree.process_frame
	print("COUNTS the rampage freed in %d ms" % (Time.get_ticks_msec() - freeing))
	print("COUNTS done %.0f s after the engine started" % (Time.get_ticks_msec() / 1000.0))


## Where each kind's peak was reached and the most taken in one frame (which burst sets the peak).
func _sample(pools: Array[Node], frame: int) -> void:
	var used: Dictionary = {}
	for pool: Node in pools:
		var fx := pool as FxPool
		var kinds: Dictionary = fx.get("_kinds")
		for kind: String in kinds:
			var k: Dictionary = kinds[kind]
			var out: Dictionary = k["out"]
			used[kind] = Num.i(used.get(kind, 0)) + out.size()
	var most := _most(pools)
	for kind: String in used:
		if Num.i(most[kind]) > Num.i(_top.get(kind, 0)):
			_top[kind] = most[kind]
			_peak_at[kind] = frame
		var rise := Num.i(used[kind]) - Num.i(_was.get(kind, 0))
		var best: Array = _jump.get(kind, [0, 0])
		if rise > Num.i(best[0]):
			_jump[kind] = [rise, frame]
		_was[kind] = used[kind]


## The most slots of each kind in use at once, over the pools (both read the same slots).
static func _most(pools: Array[Node]) -> Dictionary:
	var most: Dictionary = {}
	for pool: Node in pools:
		var fx := pool as FxPool
		var kinds: Dictionary = fx.get("_kinds")
		for kind: String in kinds:
			var k: Dictionary = kinds[kind]
			most[kind] = maxi(Num.i(most.get(kind, 0)), Num.i(k["peak"]))
	return most


## The true peaks per pool and per kind, the measurement's validity, and the bar.
func _pools(pools: Array[Node], shipped: Dictionary, provisional: bool) -> void:
	_check.call(not pools.is_empty(), "the city has an FxPool (render_opt.fx_pool on by default)")
	for pool: Node in pools:
		var fx := pool as FxPool
		var where := str(fx.get_parent().get_parent().name)
		print("COUNTS the next line is the pool under %s" % where)
		print(fx.report())  # its own line: the sizing tool reads lines starting "FXPOOL peak/slots"
		_check.call(
			fx.fallbacks == 0,
			(
				"the measuring slots (%d a kind, %s) never all ran busy under %s"
				% [MEASURE, MEASURE_MORE, where]
			)
		)
	var most := _most(pools)
	var peaks: PackedStringArray = []  # the sizing tool's format, measuring slots as the count
	var when: PackedStringArray = []
	var line: PackedStringArray = []
	var over: PackedStringArray = []
	for kind: String in most:
		var slots := Num.i(shipped.get(kind, 0))
		var jump: Array = _jump.get(kind, [0, 0])
		peaks.append("%s=%d/%d" % [kind, most[kind], _measure(kind)])
		when.append("%s@%d(+%d@%d)" % [kind, Num.i(_peak_at.get(kind, 0)), jump[0], jump[1]])
		line.append("%s=%d/%d" % [kind, most[kind], slots])
		if Num.i(most[kind]) > slots:
			over.append(kind)
	print("NOTICE: FXPOOL peak/slots %s fallbacks=0" % " ".join(peaks))
	print("COUNTS peak at frame (most taken in one frame at frame): %s" % " ".join(when))
	var state := "provisional, printed only" if provisional else "the bar"
	print("NOTICE: FxPool true peak/shipped slots %s (%s)" % [" ".join(line), state])
	if provisional:
		var note := "FxPool sizes are provisional (render_opt.fx_pool.provisional_sizes): printed"
		_check.call(
			true, "%s; %d kinds peak over their slots (%s)" % [note, over.size(), ",".join(over)]
		)
		return
	_check.call(
		over.is_empty(),
		(
			"every FxPool kind's true peak on the route fits its shipped slots (over: %s; %s)"
			% [",".join(over), " ".join(line)]
		)
	)
