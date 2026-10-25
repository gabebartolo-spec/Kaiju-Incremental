extends SceneTree
## One mid-rampage frame at the game camera in a chosen time of day and weather (autoplay, city seed
## 0, the run that plays that time of day, PLAY_FRAMES physics ticks, then paused) for the rain check: <out>/<name>.png, a 2x crop
## round the kaiju (<name>_2x.png), a RAIN_FRAME line (kaiju pixel, GPU and CPU render ms over
## TIME_FRAMES frames). The pause freezes the rain too: the still shows the streaks and splashes in place.
## --nokaiju also saves <name>_nokaiju.png (the kaiju hidden, same frame) for the contrast measure;
## --play=N sets the ticks played before the frame.
## --clip does not pause: it plays CLIP_FRAMES more frames for `--write-movie` (game speed, 60 fps).
## Run it once per shot, clear and rain, so the frame is the same seeded one:
##
##   godot --path . --windowed --fixed-fps 60 --resolution 3840x2160 \
##     --script tools/capture/capture_rain.gd -- --time=night --weather=rain --name=night_rain --out=<dir>
##
## Needs the off-screen no_focus override.cfg (Kit.window_ok).

const PLAY_FRAMES := 600
const SETTLE_FRAMES := 20
const TIME_FRAMES := 240
const CLIP_FRAMES := 360
const CROP := Vector2i(480, 270)  # at 1080p; scaled with the frame

const Kit := preload("res://tools/capture/capture_kit.gd")


func _initialize() -> void:
	var a := Kit.args(
		{
			"species": "reptilian",
			"time": "dusk",
			"weather": "clear",
			"graphics": "medium",
			"name": "shot",
			"out": "user://rain",
			"clip": false,
			"play": PLAY_FRAMES,
			"nokaiju": false,
		}
	)
	DirAccess.make_dir_recursive_absolute(str(a["out"]))
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred(a)


func _run(a: Dictionary) -> void:
	await process_frame
	PlayerSettings.graphics = str(a["graphics"])
	Content.set_time(str(a["time"]))
	Content.set_weather(str(a["weather"]))
	var species := str(a["species"])
	var stats := Kit.stats(species)
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	# Rampage.setup picks the time of day from the run index (the fixed order), so the time asked
	# for is the run played; the city (layout) stays seed 0.
	var run := maxi(0, Content.times().find(str(a["time"])))
	var rampage := Kit.autoplay(self, species, stats, run, layout)
	await Kit.ticks(self, Num.i(a["play"]))
	if a["clip"] == true:
		await Kit.frames(self, CLIP_FRAMES)  # the movie writer records these
		quit()
		return
	paused = true
	await Kit.frames(self, SETTLE_FRAMES)
	Kit.measure_on(self)
	var ms := await Kit.render_ms(self, TIME_FRAMES)
	var shot := root.get_texture().get_image()
	var out := str(a["out"])
	shot.save_png(out.path_join(str(a["name"]) + ".png"))
	var kaiju := rampage.find_children("*", "KaijuModel", true, false)
	var px := Vector2.ZERO
	if not kaiju.is_empty():
		var size := Vector2(shot.get_size())
		var at := (kaiju[0] as Node3D).global_position + Vector3(0, 3, 0)
		px = Kit.image_point(self, root.get_camera_3d(), at, size)
		var crop := Vector2i(Vector2(CROP) * size.y / 1080.0)
		Kit.crop_2x(shot, px, crop, out.path_join(str(a["name"]) + "_2x.png"))
		if a["nokaiju"] == true:  # the same frame without him, for the contrast measure
			for node: Node in kaiju:
				(node as Node3D).visible = false
			await Kit.frames(self, SETTLE_FRAMES)
			root.get_texture().get_image().save_png(out.path_join(str(a["name"]) + "_nokaiju.png"))
	print(
		(
			"RAIN_FRAME %s %s %s kaiju_px %d %d gpu %.2f ms cpu %.2f ms over %d frames"
			% [a["time"], a["weather"], a["graphics"], px.x, px.y, ms[0], ms[1], TIME_FRAMES]
		)
	)
	quit()
