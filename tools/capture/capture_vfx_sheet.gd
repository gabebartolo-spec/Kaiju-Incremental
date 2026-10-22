extends SceneTree
## The VFX look sheet's evidence (docs/VFX_STYLE.md): every effect family the game draws today,
## played one at a time beside a standing reptilian at the game camera, each saved at its peak
## frame with its screen point in <out>/points.json. tools/capture/vfx_sheet.py lays them out as
## one labelled contact sheet. Needs a window (no --headless) and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_vfx_sheet.gd -- --out=<dir> --run=1
## --run: the run index, which picks the time of day (1 night, 3 noon).

const Kit := preload("res://tools/capture/capture_kit.gd")
## The adolescent body with the breath upgraded and the ultimate owned.
const LEVELS := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1, "sig_power": 2, "r_beam": 1}
const SETTLE := 120
## The run's clock for the whole sheet (the default rampage ends before the ultimate).
const RUN_SECONDS := 600.0
## Frames left between effects so the last one has cleared.
const GAP := 150
## Where an effect plays, from the kaiju's feet, in body-scale units (the camera looks down -z).
const SPOT := Vector3(7.0, 0.0, -7.0)
## A fire away from the kaiju and the screen centre, where the smoke shader keeps its column.
const FAR_SPOT := Vector3(-14.0, 0.0, -22.0)
## The side view for the breath and the ultimate (the game camera looks down their length).
const SIDE_DISTANCE := 26.0
const SIDE_HEIGHT := 9.0

var _out := "user://vfx_sheet"
var _rampage: Rampage
var _points: Dictionary = {}
var _input: Dictionary = {}


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
	_rampage.scripted = func(_sim: RampageSim) -> Dictionary: return _take_input()
	root.add_child(_rampage)
	await _rampage.wait_loaded()
	while _rampage.sim.emerge.active:
		await physics_frame
	await _frames(SETTLE)
	_rampage.sim.time_left = RUN_SECONDS  # every effect plays before the clock ends the run
	_aim(false)  # the ready breath's wedge is drawn over everything; back on for the breath
	var city := _city()
	var fx := city.fx
	var bs := _rampage.sim.body_scale()
	await _shot("fire_ground", 240, func(p: Vector3) -> void: city.fire(p, 1.0))
	await _shot(
		"fire_far_smoke",
		300,
		func(_p: Vector3) -> void: city.fire(_feet() + FAR_SPOT * bs, 1.5),
		FAR_SPOT
	)
	await _shot("explosion_wreck", 6, func(p: Vector3) -> void: TankFx.wreck(city, p, 0.0))
	await _shot("dust_cloud", 25, func(p: Vector3) -> void: fx.dust(p, 2.0 * bs))
	await _shot(
		"dust_topple",
		25,
		func(p: Vector3) -> void: fx.dust(p, 2.0 * bs, Color(0.8, 0.78, 0.72, 0.5))
	)
	await _shot("dust_footfall", 12, func(p: Vector3) -> void: fx.footfall(p, 1.5 * bs, false))
	await _shot("dust_tree_puff", 8, func(p: Vector3) -> void: fx.tree_puff(p, 2.0, 0.45))
	await _shot("ring_stomp", 8, func(p: Vector3) -> void: fx.shockwave(p, 3.0 * bs))
	await _shot(
		"ring_tail_sweep", 8, func(p: Vector3) -> void: city.ring(p, 4.0 * bs, UiKit.WARN, 0.35)
	)
	await _shot("sparks_shell_hit", 4, func(p: Vector3) -> void: fx.sparks(p + Vector3.UP))
	await _shot(
		"sparks_deflect",
		4,
		func(p: Vector3) -> void: _rampage.ability_fx.deflect(p + Vector3.UP, Vector3.UP)
	)
	await _shot("debris", 18, func(p: Vector3) -> void: _debris(city, p))
	await _shot(
		"ability_stomp_cracks",
		12,
		func(p: Vector3) -> void: _rampage.ability_fx.stomp_cracks(p, 3.0 * bs, 3.0)
	)
	await _shot(
		"ability_leap_crater",
		10,
		func(p: Vector3) -> void: _rampage.ability_fx.leap_land(p, 3.0 * bs, 1.0)
	)
	await _shot("ability_claw", 8, func(_p: Vector3) -> void: _claw(city, bs))
	await _shot(
		"ability_regen",
		40,
		func(_p: Vector3) -> void: _rampage.ability_fx.regen(_feet() + Vector3.UP * 3.0 * bs, true)
	)
	_rampage.ability_fx.regen(Vector3.ZERO, false)
	await _frames(GAP)
	_aim(true)
	await _frames(30)
	_still("breath_aim", _feet() + _ahead() * 6.0 * bs)
	await _press("signature", "breath", [10, 24])
	await _frames(GAP * 2)
	await _press("ultimate", "ultimate_beam", [20, 60])
	var file := FileAccess.open(_out.path_join("points.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_points))
	file.close()
	quit()


## Plays `play` at the effect spot, stills `after` frames later, then waits for it to clear.
func _shot(shot_name: String, after: int, play: Callable, spot := SPOT) -> void:
	var p := _spot()
	play.call(p)
	await _frames(after)
	var at := _feet() + spot * _rampage.sim.body_scale()
	_still(shot_name, at + Vector3.UP * (1.0 if spot == SPOT else 4.0))
	await _frames(GAP)
	for fire: Variant in _city().get("_fires"):  # put out what the shot lit
		if is_instance_valid(fire):
			var lit: Fire = fire
			lit.go_out()


## Presses a button for one physics frame and stills the frames in `at` after it.
func _press(button: String, shot_name: String, at: Array) -> void:
	_input = {button: true}
	await physics_frame
	await physics_frame
	_input = {}
	var waited := 0
	for n: int in at:
		await _frames(n - waited)
		waited = n
		_still("%s_%02d" % [shot_name, n], _feet() + _ahead() * 6.0 * _rampage.sim.body_scale())
		await _side_still("%s_side_%02d" % [shot_name, n])


## The same moment from the kaiju's right, level with its chest: one frame on a side camera.
func _side_still(shot_name: String) -> void:
	var game_cam := root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 4000.0
	_rampage.add_child(cam)
	var bs := _rampage.sim.body_scale()
	var right := Vector3(-_ahead().z, 0.0, _ahead().x)
	cam.position = _feet() + right * SIDE_DISTANCE * bs + Vector3(0, SIDE_HEIGHT * bs, 0)
	var look := _feet() + _ahead() * 8.0 * bs + Vector3.UP * 3.0 * bs
	cam.look_at(look)
	cam.current = true
	await process_frame
	_still(shot_name, look)
	game_cam.current = true
	cam.queue_free()


## Shows or hides the ready breath's aim wedge (BreathAim sets itself every physics frame).
func _aim(on: bool) -> void:
	for node: Node in _rampage.get_children():
		if node is BreathAim:
			node.set_physics_process(on)
			(node as Node3D).visible = false


func _still(shot_name: String, world: Vector3) -> void:
	Kit.still(self, _out, shot_name)
	var cam := root.get_viewport().get_camera_3d()
	var size := Vector2(root.get_texture().get_image().get_size())
	var px := Kit.image_point(self, cam, world, size)
	_points[shot_name] = [px.x, px.y]


func _take_input() -> Dictionary:
	return _input


func _debris(city: CityView, p: Vector3) -> void:
	for n: int in 14:
		var out := Vector3.FORWARD.rotated(Vector3.UP, TAU * n / 14.0)
		var color := Color("8a8780") if n % 2 == 0 else Color("b9a58a")
		city.debris(p + out * 0.6 + Vector3(0, 1.0, 0), color, out + Vector3(0, 1.4, 0))


func _claw(city: CityView, bs: float) -> void:
	var event := {
		"side": 1.0, "near": 1.5 * bs, "far": 6.0 * bs, "width": 2.0 * bs, "top": 4.0 * bs
	}
	ClawSlash.play(city, _feet(), _ahead(), event, {})


func _city() -> CityView:
	return _rampage.get("_city")


func _feet() -> Vector3:
	return Vector3(_rampage.sim.kaiju_pos.x, 0.0, _rampage.sim.kaiju_pos.y)


func _ahead() -> Vector3:
	return Vector3(_rampage.sim.facing.x, 0.0, _rampage.sim.facing.y)


func _spot() -> Vector3:
	return _feet() + SPOT * _rampage.sim.body_scale()


func _frames(n: int) -> void:
	await Kit.frames(self, n)
