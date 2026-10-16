extends SceneTree
## Captures the Blender tank (D-042) in a real rampage at the game camera: the kaiju stands while
## tanks roll in, turn their turrets onto it and fire. With --species=cephalopod and Grab and
## Throw, a limb seizes tanks and hurls them. Stills along the way; pair with --write-movie for
## the clip. Needs a window and the no-focus override.cfg (or CI: tools/capture/ci_capture.sh).
##
##   godot --path . --resolution 1280x720 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_tanks.gd -- --species=<id> --out=<dir>

const FRAMES := 60 * 16
const SHOTS: Array[int] = [420, 540, 660, 780, 900]
const LEVELS := {
	"reptilian": {"claws": 1},
	"cephalopod": {"claws": 1, "c_grab": 3},
}

var _out := "user://tanks"
var _species := "reptilian"


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
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {"move": Vector2.ZERO}
	root.add_child(rampage)
	for i: int in FRAMES:
		await physics_frame
		if SHOTS.has(i):
			var path := _out.path_join("tanks_%s_%03d.png" % [_species, i])
			root.get_viewport().get_texture().get_image().save_png(path)
	quit()
