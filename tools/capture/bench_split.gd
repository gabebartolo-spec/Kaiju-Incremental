extends SceneTree
## Where a rampage's frame time lands, by node: plays growth stage N's city (as bench_rampage),
## lets it settle, then hides each visual child of the rampage and of its CityView in turn for
## FRAMES frames and prints the GPU and frame time saved. Needs a window (the off-screen no_focus
## override.cfg). Used for the 1.5x play area's frame-time bar (D-254).
##   godot --path . --resolution 3840x2160 --windowed --script tools/capture/bench_split.gd \
##     -- --stage=3 --preset=medium

const Kit := preload("res://tools/capture/capture_kit.gd")

## --live: the rampage plays on while measuring (each hidden stretch is compared with the shown
## stretches either side of it), else it is frozen.
var _live := false
## --at=N: frames played before measuring (90: past the start).
var _at := 90
## Frames measured per state (shown, hidden).
var FRAMES := 30
## Savings under this (ms) are not printed: a tank or a helicopter, noise.
const NOISE_MS := 0.3
## Frames left to settle after a visibility change.
const SETTLE := 5


func _initialize() -> void:
	var a := Kit.args({"stage": 3, "preset": "", "live": false, "at": 90, "frames": 30})
	_at = Num.i(a["at"])
	_live = a["live"] == true
	FRAMES = Num.i(a.get("frames", 30))
	PlayerSettings.graphics = str(a["preset"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred(Num.i(a["stage"]))


func _run(stage: int) -> void:
	await process_frame
	var levels: Dictionary = Kit.STAGE_LEVELS[stage - 1]
	var layout := CityGrowth.layout(Content.tuning(), stage, Seeds.make("city", 0))
	var stats := Kit.stats("reptilian", levels, "reptilian")
	var rampage := Kit.autoplay(self, "reptilian", stats, 2, layout)
	Kit.measure_on(self)
	await Kit.frames(self, _at)
	if not _live:
		rampage.process_mode = Node.PROCESS_MODE_DISABLED  # a still scene: only drawing differs
	await Kit.frames(self, 20)
	var nodes: Array[Node3D] = []
	for node: Node in rampage.get_children():
		if node is Node3D:
			nodes.append(node)
		if node is CityView:
			for sub: Node in node.get_children():
				if sub is Node3D:
					nodes.append(sub)
	for node: Node3D in nodes.duplicate():
		if node is StreetLife:  # its people, cars, police and matches one by one
			for sub: Node in node.get_children():
				if sub is Node3D:
					nodes.append(sub)
	var base := await _measure()
	print("all shown: gpu %.2f ms, frame %.2f ms" % [base.x, base.y])
	for node: Node3D in nodes:
		if not node.visible or node is Label3D:
			continue
		var shown := base
		if _live:
			shown = await _measure()
		node.visible = false
		var off := await _measure()
		node.visible = true
		if _live:
			shown = (shown + await _measure()) * 0.5
		if absf(shown.x - off.x) < NOISE_MS and absf(shown.y - off.y) < NOISE_MS:
			continue
		print(
			(
				"hide %s: gpu -%.2f ms, frame -%.2f ms"
				% [_label(node), shown.x - off.x, shown.y - off.y]
			)
		)
	quit()


func _label(node: Node) -> String:
	var script: Script = node.get_script()
	var named := script.resource_path.get_file() if script != null else node.get_class()
	return "%s %s" % [named, node.name] if not str(node.name).begins_with("@") else named


## Average (gpu ms, frame ms) over FRAMES frames after SETTLE.
func _measure() -> Vector2:
	await Kit.frames(self, SETTLE)
	var vp := root.get_viewport_rid()
	var gpu := 0.0
	var last := Time.get_ticks_usec()
	var gap := 0.0
	for n: int in FRAMES:
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var now := Time.get_ticks_usec()
		gap += (now - last) / 1000.0
		last = now
	return Vector2(gpu / FRAMES, gap / FRAMES)
