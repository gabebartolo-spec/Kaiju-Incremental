extends SceneTree
## The ablation matrix (render plan Phase 0, attribution only, nothing ships): the same seeded
## replay as bench_frames.gd, run to `--at` measured frames (peak ruin), then ONE thing switched
## off and `--measure` frames timed. One row per process (`--row=<name>`); tools/capture/ablate.sh
## runs them all. Prints "ABLATE row=<name> before <GPU ms> after <GPU ms> delta ..." where
## "before" is the 120 frames just ahead of the switch, in the same process, as the control.
##
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 --disable-vsync \
##     --script tools/capture/ablate.gd -- --row=sun_shadows --route-file=<route.json> --out=<dir>
## Rows: baseline buildings kaiju_cubes kaiju_filler kaiju_cube_shadows ground_flat sun_shadows
## ssao ssil far_dof glow fx_hidden volumetric_fog (the last is run C only).

const Lib := preload("res://tools/capture/bench_lib.gd")
const Kit := preload("res://tools/capture/capture_kit.gd")
const CONTROL_FRAMES := 120

var _a: Dictionary
var _lib := Lib.new()


func _initialize() -> void:
	var defaults := Lib.DEFAULTS.duplicate()
	defaults.merge({"row": "baseline", "at": 3000, "measure": 300, "warmup": 120, "out": "user://bench"})
	_a = Kit.args(defaults)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(str(_a["out"]))
	if _a["vsync"] != true:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	if not await _lib.start(self, _a):
		quit(1)
		return
	var vp := root.get_viewport_rid()
	Kit.measure_on(self)
	print("ABLATE gpu=%s" % RenderingServer.get_video_adapter_name())
	var at := Num.i(_a["at"])
	for _i: int in Num.i(_a["warmup"]) + at - CONTROL_FRAMES:
		await process_frame
	var before := await _sample(vp, CONTROL_FRAMES)
	var changed := _apply(str(_a["row"]))
	var after := await _sample(vp, Num.i(_a["measure"]))
	var line := (
		"ABLATE row=%s applied=%s before gpu mean %.3f p50 %.3f | after gpu mean %.3f p50 %.3f p95 %.3f rcpu mean %.3f | delta mean %.3f p50 %.3f (n=%d) stomps=%d falls=%d"
		% [
			_a["row"], changed,
			before[0], before[1], after[0], after[1], after[2], after[3],
			after[0] - before[0], after[1] - before[1], Num.i(_a["measure"]),
			_lib.tally["stomps"], _lib.tally["falls"],
		]
	)
	print(line)
	var f := FileAccess.open("%s/ablate_%s.txt" % [_a["out"], _a["row"]], FileAccess.WRITE)
	f.store_line(line)
	f.close()
	quit()


## [GPU mean, GPU p50, GPU p95, render-CPU mean] over n frames.
func _sample(vp: RID, n: int) -> Array:
	var gpu: Array = []
	var cpu := 0.0
	var sum := 0.0
	for _i: int in n:
		await process_frame
		var g := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		gpu.append(g)
		sum += g
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	gpu.sort()
	return [sum / n, Lib.pct(gpu, 0.5), Lib.pct(gpu, 0.95), cpu / n]


## Switches the row's thing off; returns how many nodes or settings it touched (0 = row not found).
func _apply(row: String) -> int:
	var env: Environment = null
	for node: Node in Lib.nodes_of(self, "WorldEnvironment"):
		env = (node as WorldEnvironment).environment
	var touched := 0
	match row:
		"baseline":
			return 1
		"buildings":
			for node: Node in Lib.nodes_of(self, "BuildingStream"):
				(node as Node3D).visible = false
				touched += 1
		"kaiju_cubes", "kaiju_cube_shadows":
			for skin: Node in Lib.nodes_of(self, "VoxelSkin"):
				for child: Node in skin.get_children():
					if child is MultiMeshInstance3D:
						if row == "kaiju_cubes":
							(child as MultiMeshInstance3D).visible = false
						else:
							(child as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						touched += 1
		"kaiju_filler":
			for skin: Node in Lib.nodes_of(self, "VoxelSkin"):
				for child: Node in skin.get_children():
					if child is MeshInstance3D:
						(child as MeshInstance3D).visible = false
						touched += 1
		"ground_flat":
			var flat := StandardMaterial3D.new()
			flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			flat.albedo_color = Color(0.25, 0.25, 0.25)
			for ground: Node in Lib.nodes_of(self, "CityGround"):
				for mmi: Node in ground.find_children("*", "MultiMeshInstance3D", true, false):
					(mmi as MultiMeshInstance3D).material_override = flat
					touched += 1
		"sun_shadows":
			for sun: Node in Lib.nodes_of(self, "DirectionalLight3D"):
				(sun as DirectionalLight3D).shadow_enabled = false
				touched += 1
		"ssao":
			if env != null:
				env.ssao_enabled = false
				touched = 1
		"ssil":
			if env != null:
				env.ssil_enabled = false
				touched = 1
		"glow":
			if env != null:
				env.glow_enabled = false
				touched = 1
		"volumetric_fog":
			if env != null:
				touched = 1 if env.volumetric_fog_enabled else 0
				env.volumetric_fog_enabled = false
		"far_dof":
			var cam := Kit.game_camera(self)
			if cam != null and cam.attributes is CameraAttributesPractical:
				(cam.attributes as CameraAttributesPractical).dof_blur_far_enabled = false
				touched = 1
		"fx_hidden":
			for kind: String in ["GPUParticles3D", "WeatherView", "Fire"]:
				for node: Node in Lib.nodes_of(self, kind):
					(node as Node3D).visible = false
					touched += 1
	return touched
