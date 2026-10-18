extends SceneTree
## The tanks at work (D-066) at the game camera: a Behemoth croc stands at a crossing while tank
## columns drive in by road and deploy to firing posts round it. Clip-only overrides, so it all
## happens inside 18 s (trimmed to a 10 s clip) and inside the frame: columns call in from
## CLIP_SPAWN (not army.spawn_radius) every 1.6 s; the kaiju cannot fall. Everything else is the
## game's own data and code (the helicopters are today's, at their own call-in: none come in
## 18 s). Stills along the way; pair with --write-movie (ci_capture.sh --movie) for the clip.
## Needs a window and the no-focus override.cfg (or CI: tools/capture/ci_capture.sh).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_military.gd -- --out=<dir> [--seconds=18]

const SHOTS: Array[int] = [300, 480, 600, 720, 780, 840, 900, 960, 1060]
## Where columns call in from, metres from the kaiju (the game's is army.spawn_radius).
const CLIP_SPAWN := 44.0
## Where the kaiju stands: a crossing at the north end of the Behemoth city (the same spot as
## round 3's clip, so the critic compares like with like).
const CLIP_AT := Vector2(5, -70)
## Mid-clip the kaiju strides east down the avenue at the tanks posted there (frames, at 60 fps),
## so the take shows them fall back out of its reach and post again.
const WALK_FRAMES := Vector2i(540, 780)
const WALK := Vector2(1, 0)

var _out := "user://military"
var _seconds := 18.0
var _frame := 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		if arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), {"claws": 1, "evolve1": 1}, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	stats["hp"] = 100000.0  # the clip watches the army: the kaiju must not fall mid-take
	var tier := Num.i(stats["size"])
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0)), 1
	)
	rampage.sim.kaiju_pos = CLIP_AT  # before the view is built, so it starts there
	rampage.scripted = _input
	root.add_child(rampage)
	await physics_frame
	var sim := rampage.sim
	sim.army["spawn_radius"] = CLIP_SPAWN
	sim.army["start_interval"] = 1.6
	sim.army_units._spawn_timer = 0.3
	for i: int in roundi(_seconds * 60.0):
		_frame = i
		await physics_frame
		if SHOTS.has(i):
			var path := _out.path_join("military_%04d.png" % i)
			root.get_viewport().get_texture().get_image().save_png(path)
	quit()


## The kaiju stands side-on to the camera, and strides at the tanks mid-clip (walk).
func _input(sim: RampageSim) -> Dictionary:
	sim.facing = Vector2(1, 0)
	return {"move": walk(_frame)}


## The clip's move at physics frame `frame`.
static func walk(frame: int) -> Vector2:
	return WALK if frame >= WALK_FRAMES.x and frame < WALK_FRAMES.y else Vector2.ZERO
