extends SceneTree
## Captures each species' first branch powers in a real rampage with scripted input, for the
## lead's review: reptilian Tail Sweep + Momentum (zig-zag charges), insectoid Wing Buzz (leap,
## hold to glide), cephalopod Hydra Limbs (stand among buildings). Stills along the way; pair
## with --write-movie for the clip. Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1280x720 --windowed --fixed-fps 60 \
##     --write-movie <dir>/<species>.avi --script tools/capture/capture_branch.gd \
##     -- --species=<id> --out=<dir>

const Kit := preload("res://tools/capture/capture_kit.gd")
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
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"out": _out, "species": _species})
	_out = str(a["out"])
	_species = str(a["species"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var levels: Dictionary = LEVELS[_species]
	var rampage := Kit.rampage(_species, Kit.stats(_species, levels, _species), 1)
	rampage.scripted = _input
	root.add_child(rampage)
	for i: int in FRAMES:
		await physics_frame
		_frame = i
		if SHOTS.has(i):
			Kit.still(self, _out, "%s_%03d" % [_species, i])
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
