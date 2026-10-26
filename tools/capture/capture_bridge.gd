extends SceneTree
## A road bridge over the river at night on the game camera (director, build 4 comments
## 2026-10-21 #12: "bridge is not connected to land"): the run's start at a stage, the kaiju
## stepped out onto the bank, then the camera's focus moved to the bridge nearest the kaiju so
## both deck ends and their banks are in frame. Saves <out>/bridge_stage<N>.png. Needs a window:
## CI (tools/capture/ci_capture.sh), or off-screen with the no-focus override.
##
##   godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_bridge.gd -- --stage=1 --out=<dir>

const LEVELS: Array[Dictionary] = [{"claws": 2, "hide": 2}, {"claws": 3, "evolve1": 1}]
const NIGHT_RUN := 1  # Content.time_for_run(1) is "night"
const SETTLE := 30  # frames for the camera to settle on the bridge

var _stage := 1
var _out := "user://bridge"


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			_stage = clampi(arg.substr(8).to_int(), 1, LEVELS.size())
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS[_stage - 1])
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var rampage := Rampage.new()
	rampage.setup(
		species,
		stats,
		CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0)),
		NIGHT_RUN
	)
	rampage.autoplay_signature = false
	root.add_child(rampage)
	while rampage.sim.emerge.active:
		await physics_frame
	var plan := CityGen.map(rampage.sim.city)
	var best := Rect2()
	var near := INF
	for deck: Rect2 in CityRiver.bridges(plan, rampage.sim.city):
		var d := deck.get_center().distance_to(rampage.sim.kaiju_pos)
		if d < near:
			near = d
			best = deck
	# The kaiju stands on the bank road just west of the bridge, as in the director's shot.
	rampage.sim.kaiju_pos = Vector2(best.position.x - 6.0, best.position.y - 2.0)
	for frame: int in SETTLE:
		await process_frame
	print("bridge: stage %d, deck %s, kaiju %s" % [_stage, best, rampage.sim.kaiju_pos])
	DirAccess.make_dir_recursive_absolute(_out)
	var path := _out.path_join("bridge_stage%d.png" % _stage)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("bridge: saved %s" % path)
	quit()
