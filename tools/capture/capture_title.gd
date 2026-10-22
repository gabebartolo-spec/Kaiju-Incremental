extends SceneTree
## Captures the title screen (with a save, so CONTINUE shows): the 4K still, and how long the menu
## takes to open and the live city to stand. Local GPU only:
##   godot --path . --windowed --resolution 3840x2160 --script \
##     tools/capture/capture_title.gd -- --out=<dir> [--clip=<seconds>] [--no-city]
## --clip: records that many seconds from the first frame (add --write-movie <f>.avi --fixed-fps 60;
## movie mode mixes the audio itself): the clip starts at the printed frame, no still.
## Prints "menu open <ms>" (the title in the tree to its first drawn frame) and "city stands <ms>".

const AFTER_SHOWN := 1.0  # seconds the city has been fading in before the still
const MAX_WAIT_MS := 60000
## The clip's frame rate (--fixed-fps) and the frames the city's fade-in takes before it starts.
const FPS := 60
const FADE_FRAMES := 100

var _out := "user://title"
var _clip := 0.0
var _city := true


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg == "--no-city":
			_city = false
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
	await process_frame
	await process_frame
	var now := Time.get_ticks_msec()
	print("menu open ", now - t0, " ms; first scene frame ", now, " ms after launch")
	var backdrops := title.find_children("*", "TitleBackdrop", true, false)
	if backdrops.is_empty():
		print("no live city")
	else:
		var backdrop := backdrops[0] as TitleBackdrop
		while not backdrop.is_loaded and Time.get_ticks_msec() - t0 < MAX_WAIT_MS:
			await process_frame
		print("city stands ", Time.get_ticks_msec() - t0, " ms")
	if _clip > 0.0:
		# Frames, not seconds: a --write-movie run steps a fixed 1/FPS per frame whatever the wall clock.
		for _i: int in FADE_FRAMES:
			await process_frame
		print("clip from frame ", Engine.get_frames_drawn(), " for ", int(_clip * FPS), " frames")
		for _i: int in int(_clip * FPS):
			await process_frame
	else:
		var wait := Time.get_ticks_msec() + int(AFTER_SHOWN * 1000.0)
		while Time.get_ticks_msec() < wait:
			await process_frame
		root.get_texture().get_image().save_png(_out.path_join("title.png"))
	quit()
