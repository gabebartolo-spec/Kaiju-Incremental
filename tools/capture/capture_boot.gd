extends SceneTree
## Times a boot through the real main scene (scenes/main.tscn, as the game starts it): from the
## process launch to the first drawn frame of the title (the sky and the menu) and to the live
## city standing. Local GPU only; pass the launch time so the engine's own start-up counts:
##   LAUNCH=$(date +%s.%N); godot --path . --windowed --resolution 1920x1080 \
##     --script tools/capture/capture_boot.gd -- --launch=$LAUNCH --out=<dir>
## Prints "engine started N ms after launch", "main added", "first title frame ... ms after launch"
## and "city stands ... ms after launch", and saves boot_first.png / boot_city.png (the first drawn
## frame and the frame the city is up) so the picture can be judged.

const MAX_WAIT_MS := 60000

var _out := "user://boot"
var _launch := 0.0


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--launch="):
			_launch = float(arg.substr(9))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


## Milliseconds from the process launch (when it was passed) to now.
func _since_launch() -> int:
	if _launch <= 0.0:
		return Time.get_ticks_msec()
	return int((Time.get_unix_time_from_system() - _launch) * 1000.0)


func _run() -> void:
	print(
		"engine and autoloads up ",
		_since_launch(),
		" ms after launch (",
		Time.get_ticks_msec(),
		" ms engine clock)"
	)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	print("main added ", _since_launch(), " ms after launch")
	await RenderingServer.frame_post_draw
	print("first title frame drawn ", _since_launch(), " ms after launch")
	root.get_texture().get_image().save_png(_out.path_join("boot_first.png"))
	var screen: Node = main.call("screen")
	var backdrops := screen.find_children("*", "TitleBackdrop", true, false)
	if backdrops.is_empty():
		print("no live city")
	else:
		var backdrop := backdrops[0] as TitleBackdrop
		var start := Time.get_ticks_msec()
		while not backdrop.is_loaded and Time.get_ticks_msec() - start < MAX_WAIT_MS:
			await process_frame
		print("city stands ", _since_launch(), " ms after launch")
		for _i: int in 90:
			await process_frame
		root.get_texture().get_image().save_png(_out.path_join("boot_city.png"))
	quit()
