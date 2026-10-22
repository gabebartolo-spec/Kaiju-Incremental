extends SceneTree
## Captures the title screen (with a save, so CONTINUE shows): the 4K still, and how long the menu
## takes to open and the live city to stand. Local GPU only:
##   godot --path . --windowed --resolution 3840x2160 --script \
##     tools/capture/capture_title.gd -- --out=<dir> [--clip=<seconds>] [--no-city]
## --clip: records that many seconds from the first frame (add --write-movie <f>.avi --fixed-fps 60;
## movie mode mixes the audio itself): the clip starts at the printed frame, no still.
## --reveal=<seconds>: the still is taken that long after an explosion that reveals the colossus.
## --rest: the still waits until the bay is at rest (no footfall shivering it).
## --measure: prints the tower, head and shore pixel numbers (tools/capture/title_measure.gd).
## --variant=night|dusk picks the title's look (tuning "title" "variants").
## --segments: after the clip, plays each sound layer alone for a while (the others' buses muted) so
## its level can be measured on the track; prints "segment <layer> from frame N for M frames".
## Prints "menu open <ms>" (the title in the tree to its first drawn frame) and "city stands <ms>".

const AFTER_SHOWN := 1.0  # seconds the city has been fading in before the still
const MAX_WAIT_MS := 60000
const MEASURE := preload("res://tools/capture/title_measure.gd")
## The clip's frame rate (--fixed-fps) and the frames the city's fade-in takes before it starts.
const FPS := 60
const FADE_FRAMES := 100
## The layers measured alone with --segments: name, the buses left sounding, seconds.
const SEGMENTS := [
	["crowd", [&"Crowd", &"Bed"], 5.0],
	["siren", [&"Ambience", &"Bed"], 5.0],
	["gun", [&"Military", &"Bed"], 14.0],
]

var _out := "user://title"
var _clip := 0.0
var _city := true
var _segments := false
var _reveal := -1.0
var _rest := false
var _measure := false
var _hide_3d := false
var _probe_at := Vector2.ZERO
## Main-loop frames so far (a movie frame each; the frames drawn stop counting when the window is
## off-screen and not shown).
var _frame := 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--no-city":
			_city = false
		elif arg.begins_with("--variant="):
			Content.section("title")["variant"] = arg.substr(10)
		elif arg.begins_with("--reveal="):
			_reveal = float(arg.substr(9))
		elif arg.begins_with("--probe="):
			var pair := arg.substr(8)
			_probe_at = Vector2(float(pair.get_slice(",", 0)), float(pair.get_slice(",", 1)))
		elif arg == "--hide-3d":
			_hide_3d = true
		elif arg == "--rest":
			_rest = true
		elif arg == "--measure":
			_measure = true
		elif arg == "--segments":
			_segments = true
		elif arg.begins_with("--clip="):
			_clip = float(arg.substr(7))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var title := TitleScreen.new()
	title.setup("Reptilian, 3 rampages")
	title.live_city = _city
	var t0 := Time.get_ticks_msec()
	root.add_child(title)
	await _tick()
	await _tick()
	var now := Time.get_ticks_msec()
	print("menu open ", now - t0, " ms; first scene frame ", now, " ms after launch")
	var backdrops := title.find_children("*", "TitleBackdrop", true, false)
	if backdrops.is_empty():
		print("no live city")
	else:
		var backdrop := backdrops[0] as TitleBackdrop
		while not backdrop.is_loaded and Time.get_ticks_msec() - t0 < MAX_WAIT_MS:
			await _tick()
		print("city stands ", Time.get_ticks_msec() - t0, " ms")
	if _clip > 0.0:
		# Frames, not seconds: a --write-movie run steps a fixed 1/FPS per frame whatever the wall clock.
		for _i: int in FADE_FRAMES:
			await _tick()
		print(
			"clip from frame ",
			_frame,
			" (drawn ",
			Engine.get_frames_drawn(),
			") for ",
			int(_clip * FPS),
			" frames"
		)
		for _i: int in int(_clip * FPS):
			await _tick()
		if _segments:
			await _play_segments()
	else:
		var wait := Time.get_ticks_msec() + int(AFTER_SHOWN * 1000.0)
		while Time.get_ticks_msec() < wait:
			await _tick()
		while _rest and not backdrops.is_empty() and (backdrops[0] as TitleBackdrop).shiver() > 0.0:
			await _tick()
		if _hide_3d and not backdrops.is_empty():
			(backdrops[0] as TitleBackdrop).visible = false
		if _measure and not backdrops.is_empty():
			MEASURE.towers_and_head(backdrops[0] as TitleBackdrop, float(root.size.y))
			print("measure frame ", root.size)
		if _probe_at != Vector2.ZERO and not backdrops.is_empty():
			_probe(backdrops[0] as TitleBackdrop, _probe_at)
		if _reveal >= 0.0 and not backdrops.is_empty():
			(backdrops[0] as TitleBackdrop).boom()
			wait = Time.get_ticks_msec() + int(_reveal * 1000.0)
			while Time.get_ticks_msec() < wait:
				await _tick()
		root.get_texture().get_image().save_png(_out.path_join("title.png"))
	quit()


## Debug: what 3D things lie along the camera ray through a screen point (share of the width and
## height), within `reach` metres of the camera, nearest first.
func _probe(backdrop: TitleBackdrop, at: Vector2) -> void:
	var camera := backdrop.find_children("*", "Camera3D", true, false)[0] as Camera3D
	var view := camera.get_viewport() as SubViewport
	var point := Vector2(view.size) * at
	var from := camera.project_ray_origin(point)
	var dir := camera.project_ray_normal(point)
	var hits: Array[String] = []
	for node: Node in backdrop.find_children("*", "VisualInstance3D", true, false):
		var vis := node as VisualInstance3D
		var box := vis.global_transform * vis.get_aabb()
		var along := (box.get_center() - from).dot(dir)
		if along < 0.0 or along > 120.0 or box.size.length() > 30.0:
			continue
		var off := (box.get_center() - from - dir * along).length()
		if off < maxf(box.size.length() * 0.5, 2.0):
			var label := "%06.1f %s %s" % [along, vis.get_class(), vis.get_path()]
			hits.append("%s centre %s size %s" % [label, box.get_center(), box.size])
	for node: Node in backdrop.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var mm := mmi.multimesh
		for i: int in mm.instance_count:
			var pos := mmi.global_transform * mm.get_instance_transform(i).origin
			var along := (pos - from).dot(dir)
			if along > 0.0 and along < 120.0 and (pos - from - dir * along).length() < 3.0:
				hits.append(
					(
						"%06.1f instance %d of %s at %s mesh %s"
						% [along, i, mmi.get_path(), pos, mm.mesh]
					)
				)
	hits.sort()
	for hit: String in hits:
		print("probe ", hit)


func _play_segments() -> void:
	for seg: Array in SEGMENTS:
		var keep: Array = seg[1]
		for at: int in AudioServer.bus_count:
			var label := AudioServer.get_bus_name(at)
			AudioServer.set_bus_mute(
				at, label != "Master" and label != "SFX" and not keep.has(StringName(label))
			)
		var frames := int(Num.f(seg[2]) * FPS)
		print("segment ", seg[0], " from frame ", _frame, " for ", frames, " frames")
		for _i: int in frames:
			await _tick()


func _tick() -> void:
	await process_frame
	_frame += 1
