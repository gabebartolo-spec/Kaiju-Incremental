extends SceneTree
## The croc titan's roar as the game plays it: the Behemoth evolution reveal (adolescent ->
## adult) with roar.ogg, for the listening clip. Pair with --write-movie (it records the audio).
## Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/roar.avi --script tools/capture/capture_roar.gd


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var reveal := EvolutionReveal.new()
	reveal.setup(
		Content.species_def("reptilian"), {"size": 2}, {"size": 3}, Content.section("city")
	)
	root.add_child(reveal)
	for _i: int in EvolutionReveal.END_FRAME - 2:
		await process_frame
	quit()
