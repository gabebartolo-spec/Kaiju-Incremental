extends SceneTree
## Captures each species' first branch powers in a real rampage with scripted input, for the
## lead's review: reptilian Tail Sweep + Momentum (zig-zag charges), insectoid Wing Buzz (leap,
## hold to glide), cephalopod Hydra Limbs (stand among buildings). Stills along the way; pair
## with --write-movie for the clip. Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1280x720 --windowed --fixed-fps 60 \
##     --write-movie <dir>/<species>.avi --script tools/capture/capture_branch.gd \
##     -- --species=<id> --out=<dir>

const FRAMES := 60 * 9
const SHOTS: Array[int] = [120, 220, 320, 420, 520]
const LEVELS := {
	"reptilian": {"claws": 2, "r_tail": 2, "r_momentum": 2},
	"insectoid": {"claws": 1, "i_scuttle": 1, "i_glide": 2},
	"cephalopod": {"claws": 1, "c_hydra": 4},
}

var _out := "user://branch"
var _species := "reptilian"
var _frame := 0
var _target := Vector2(INF, INF)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		if arg.begins_with("--species="):
			_species = arg.substr(10)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var species := Content.species_def(_species)
	var levels: Dictionary = LEVELS[_species]
	var tree := UpgradeTree.new(Content.upgrades(), levels, _species)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var rampage := Rampage.new()
	rampage.setup(
		species, stats, CityGen.generate(Seeds.make("city", 0), Content.section("city")), 1
	)
	rampage.scripted = _input
	root.add_child(rampage)
	for i: int in FRAMES:
		await physics_frame
		_frame = i
		if SHOTS.has(i):
			var path := _out.path_join("%s_%03d.png" % [_species, i])
			root.get_viewport().get_texture().get_image().save_png(path)
	quit()


func _input(sim: RampageSim) -> Dictionary:
	if _frame % 20 == 0:
		_target = sim.nearest_standing(sim.kaiju_pos)
	var toward := Vector2.ZERO
	if _target.x < INF:
		toward = (_target - sim.kaiju_pos).normalized()
	match _species:
		"reptilian":
			# Charge straight for 1.2 s, then cut hard across: momentum, then a tail sweep.
			var leg := _frame / 72
			var dir := toward.rotated(1.7 if leg % 2 == 1 else 0.0)
			return {"move": dir}
		"insectoid":
			# Every 2.5 s: leap, and hold the button for a second to glide on.
			var beat := _frame % 150
			return {"move": toward, "signature": beat == 30, "held": beat >= 30 and beat < 95}
		_:
			# Walk in among the buildings, then stand: the limbs strike all around.
			var close := sim.kaiju_pos.distance_to(_target) < 3.0
			return {"move": Vector2.ZERO if close or _frame > 200 else toward}
