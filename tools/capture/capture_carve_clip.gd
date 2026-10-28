extends SceneTree
## The fine-grid clip (destruction plan stage 1, D-327): a real autoplayed rampage in the stage's
## own city, at the game camera and game speed. It logs every falling piece the fine view draws
## (CityCarve: a node with its own cells) when it shows: the time, building, fall kind, frames it
## waited and where its pivot falls on the screen, so the ~6 s cut around one (ffmpeg -ss <t-2>
## -t 6) shows a building carved and falling from its own cells. Needs a window and the no-focus
## override.cfg; record with --write-movie.
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <out.avi> \
##     --script tools/capture/capture_carve_clip.gd -- --stage=3 --level=2 --seconds=30

const Kit := preload("res://tools/capture/capture_kit.gd")
## Frames after the rampage is freed, so deferred frees run before the engine exits.
const DRAIN_FRAMES := 30

var _opt := {}
var _seen := {}  # piece instance id -> true once logged


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_opt = Kit.args({"stage": 3, "level": 2, "seconds": 30.0, "species": "reptilian"})
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := str(_opt["species"])
	var stats := Kit.stats(species, Kit.STAGE_LEVELS[Num.i(_opt["level"])], species)
	var layout := CityGrowth.layout(Content.tuning(), Num.i(_opt["stage"]), Seeds.make("city", 0))
	var rampage := Kit.autoplay(self, species, stats, 0, layout)
	var frames := 0
	while frames < int(Num.f(_opt["seconds"]) * 60.0):
		await process_frame
		frames += 1
		if rampage._city != null and rampage._city.is_loaded:
			_log(rampage._city, frames)
	var carve := rampage._city.carve
	print(
		(
			"CLIP carve on %s shown %d unseen %d worst_wait %d"
			% [carve.on, carve.shown, carve.unseen, carve.worst_wait]
		)
	)
	rampage.queue_free()  # Rampage lets go of the sim's rings (D-179), as log_smoke does
	await Kit.frames(self, DRAIN_FRAMES)
	quit()


## Each fine piece the frame it first shows.
func _log(city: CityView, frames: int) -> void:
	var cam := Kit.game_camera(self)
	for id: int in city._falling:
		var f: Dictionary = city._falling[id]
		var node: Node3D = f["node"]
		if not node.has_meta("since") or not node.visible or _seen.has(node.get_instance_id()):
			continue
		_seen[node.get_instance_id()] = true
		var pivot: Vector3 = node.get_meta("pivot")
		var parts: Array = node.get_meta("parts")
		var where := "behind"
		if not cam.is_position_behind(pivot):
			where = str(cam.unproject_position(pivot).round())
		print(
			(
				"CLIP t=%.2f fall %d %s parts %d waited %d frames, pivot %s on screen %s"
				% [
					frames / 60.0,
					id,
					str(f["kind"]),
					parts.size(),
					Engine.get_process_frames() - Num.i(node.get_meta("since")),
					pivot.round(),
					where
				]
			)
		)
