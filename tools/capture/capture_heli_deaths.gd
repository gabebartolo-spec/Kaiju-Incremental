extends SceneTree
## Helicopter deaths at the game camera (HeliWreck, D-140): one helicopter blown apart in the
## air, then one spun down burning onto a block, crew bailing out, and its crash. Stills at the
## key moments; pair with --write-movie for the clip. Needs a window and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_heli_deaths.gd -- --out=<dir> --run=1

const Kit := preload("res://tools/capture/capture_kit.gd")
const LEVELS := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1, "r_ablaze": 1}
const SETTLE := 120
## Where each helicopter is put, from the kaiju's feet, in body-scale units (camera looks down -z).
const SPOT := Vector3(6.0, 0.0, -9.0)
## The close camera's distance from the spot (body-scale units).
const CLOSE_DISTANCE := 16.0

var _out := "user://heli_deaths"
var _rampage: Rampage


func _initialize() -> void:
	var a := Kit.args({"out": _out, "run": 1})
	_out = str(a["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred(Num.i(a["run"]))


func _run(run: int) -> void:
	await process_frame
	_rampage = Kit.rampage("reptilian", Kit.stats("reptilian", LEVELS), run)
	_rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	root.add_child(_rampage)
	await _rampage.wait_loaded()
	while _rampage.sim.emerge.active:
		await physics_frame
	await Kit.frames(self, SETTLE)
	_rampage.sim.time_left = 600.0
	var air := _rampage.sim.air
	air.cfg["bailout_chance"] = 1.0  # the shot shows a crew bailing out (seeded otherwise)
	air.cfg["fire_interval"] = 999.0  # it never strafes the kaiju in the shot
	await _down(1.0, "burst", [4, 20, 60])
	await Kit.frames(self, 120)
	await _down(0.2, "spin", [10, 60, 110])
	await Kit.frames(self, 60)
	Kit.still(self, _out, "spin_crash_after")
	quit()


## Spawns a helicopter over the spot, holds it there a moment, then downs it with a last blow of
## `share` of its hp; stills `name` the frames in `at` after.
func _down(share: float, shot: String, at: Array) -> void:
	var sim := _rampage.sim
	sim.events.clear()
	var heli := sim.air.spawn()
	_hand_over(sim)
	var bs := sim.body_scale()
	var spot := sim.kaiju_pos + Vector2(SPOT.x, SPOT.z) * bs
	for i: int in 45:  # the view gets it onto its circle, then we park it over the block
		heli.pos = spot
		heli.angle = (spot - sim.kaiju_pos).angle()
		await physics_frame
	var hp := Num.f(sim.air.cfg["hp"])
	heli.hp = hp * share * 0.5
	sim.events.clear()
	sim.air.hit(func(_p: Vector2, _r: float) -> float: return 1.0, hp * share, true)
	_hand_over(sim)
	for down: AirWing.Falling in sim.air.falling:
		down.drift = Vector2.ZERO  # it falls onto the block below
	var waited := 0
	for n: int in at:
		await Kit.frames(self, n - waited)
		waited = n
		Kit.still(self, _out, "%s_%03d" % [shot, n])
		await _close_still("%s_close_%03d" % [shot, n], spot)


## The same moment from a camera CLOSE_DISTANCE off the spot, a little below the helicopter.
func _close_still(shot_name: String, spot: Vector2) -> void:
	var game_cam := root.get_viewport().get_camera_3d()
	var cam := Kit.camera(_rampage)
	var bs := _rampage.sim.body_scale()
	var target := Vector3(spot.x, _rampage.sim.air.altitude() * 0.5, spot.y)
	cam.position = target + Vector3(CLOSE_DISTANCE, 2.0, CLOSE_DISTANCE * 0.6) * bs
	cam.look_at(target)
	cam.current = true
	await process_frame
	Kit.still(self, _out, shot_name)
	game_cam.current = true
	cam.queue_free()


## Events made outside a step (this script's spawn and kill) go to the view as a step's would.
func _hand_over(sim: RampageSim) -> void:
	var powers: PowersView = _rampage.get("_powers")
	var feet := Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
	for event: Dictionary in sim.events:
		powers.on_event(event, feet)
