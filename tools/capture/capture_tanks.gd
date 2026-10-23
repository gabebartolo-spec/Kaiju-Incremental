extends SceneTree
## Captures the Blender vehicles (D-042) in a real rampage at the game camera: the kaiju wades
## into the nearest buildings, tanks roll in, turn their turrets onto it and fire, and once
## enough of the city is down the helicopters arrive. Stills along the way; pair with
## --write-movie (ci_capture.sh --movie) for the clip. With --air the helicopters are called in
## at once and the kaiju stands for 20 s: helicopters circling a baby kaiju that must stay in
## view. Needs a window and the no-focus override.cfg (or CI: tools/capture/ci_capture.sh).
##
##   godot --path . --resolution 1280x720 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_tanks.gd -- --species=<id> [--air] --out=<dir>

const Kit := preload("res://tools/capture/capture_kit.gd")
const FRAMES := 60 * 40
const SHOTS: Array[int] = [600, 900, 1200, 1500, 1800, 2100, 2340]
const AIR_FRAMES := 60 * 20
## In --air mode, a still every this many frames.
const AIR_EVERY := 120
## Frames between picking the next building to walk into.
const RETARGET := 20
const LEVELS := {
	"reptilian": {"claws": 1},
	"cephalopod": {"claws": 1, "c_grab": 3},
}

var _out := "user://tanks"
var _species := "reptilian"
var _frame := 0
var _target := Vector2(INF, INF)
var _air := false


func _initialize() -> void:
	var a := Kit.args({"out": _out, "species": _species, "air": _air})
	_out = str(a["out"])
	_species = str(a["species"])
	_air = a["air"]
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
	await physics_frame
	if _air:  # called in the way a rampage does (through step), as run_flow_tests does
		var air := Content.section("air")
		rampage.sim.chunks_destroyed = (
			Num.i(air["after_chunks"]) + 2 * Num.i(air["max_per_chunks"])
		)
	for i: int in AIR_FRAMES if _air else FRAMES:
		await physics_frame
		_frame = i
		if (_air and i % AIR_EVERY == 0) or (not _air and SHOTS.has(i)):
			Kit.still(self, _out, "tanks_%s_%04d" % [_species, i])
	quit()


## Walk into the nearest standing building and keep wrecking (in --air mode, stand).
func _input(sim: RampageSim) -> Dictionary:
	if _air:
		return {"move": Vector2.ZERO}
	if _frame % RETARGET == 0:
		_target = sim.nearest_standing(sim.kaiju_pos)
	if _target.x == INF or sim.kaiju_pos.distance_to(_target) < 1.0:
		return {"move": Vector2.ZERO}
	return {"move": (_target - sim.kaiju_pos).normalized()}
