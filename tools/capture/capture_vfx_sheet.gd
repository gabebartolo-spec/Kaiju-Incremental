extends SceneTree
## The VFX look sheet's evidence (docs/VFX_STYLE.md): every effect family the game draws today,
## played one at a time beside a standing reptilian at the game camera, each saved at its peak
## frame with its screen point in <out>/points.json. tools/capture/vfx_sheet.py lays them out as
## one labelled contact sheet. Needs a window (no --headless) and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_vfx_sheet.gd -- --out=<dir> --run=1
## --run: the run index, which picks the time of day (1 night, 3 noon).
## --only=a,b: just those effects (no breath or ultimate); --after=N: still them N frames in.

const Kit := preload("res://tools/capture/capture_kit.gd")
## The adolescent body with the breath upgraded and the ultimate owned.
const LEVELS := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1, "sig_power": 2, "r_beam": 1}
const SETTLE := 120
## The run's clock for the whole sheet (the default rampage ends before the ultimate).
const RUN_SECONDS := 600.0
## Frames left between effects so the last one has cleared.
const GAP := 200
## Where an effect plays, from the kaiju's feet, in body-scale units (the camera looks down -z).
const SPOT := Vector3(7.0, 0.0, -7.0)
## A fire away from the kaiju and the screen centre, where the smoke shader keeps its column.
const FAR_SPOT := Vector3(-14.0, 0.0, -22.0)
## The kaiju's right foot, from its feet (the footfall cloud's shot: the foot is in frame).
const FOOT_SPOT := Vector3(1.6, 0.0, 0.3)
## The stomp ring's radius argument (body scale units; in the game 1.3 x the stomp's reach) and
## the tree puff's size and peak opacity (the city's tree_puff_size and tree_puff_alpha).
const STOMP_RADIUS := 9.75
const TREE_SIZE := 2.0
const TREE_ALPHA := 0.6
## The sim's tail sweep reach (data/tuning.json tail_reach), in body-scale units.
const TAIL_REACH := 11.0
## The side view for the breath and the ultimate (the game camera looks down their length).
const SIDE_DISTANCE := 26.0
const SIDE_HEIGHT := 9.0

var _out := "user://vfx_sheet"
var _rampage: Rampage
var _points: Dictionary = {}
var _px: Dictionary = {}
var _input: Dictionary = {}
var _only := PackedStringArray()
var _after := 0


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"out": _out, "run": 1, "only": "", "after": 0})
	_out = str(a["out"])
	_only = str(a["only"]).split(",", false)
	_after = Num.i(a["after"])
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
	# The ready flare (AbilityFx.ready_pulse, a gold four-point star on the kaiju's eyes) fires the
	# moment the power charges: charge it now and let it play out, so it is not in the cells.
	_rampage.sim.ability_ready_in = 0.0
	await _frames(90)
	var city := _city()
	var fx := city.fx
	var bs := _rampage.sim.body_scale()
	await _shot("fire_ground", 240, func(p: Vector3) -> void: city.fire(p, 1.0))
	await _shot("fire_building", 240, func(p: Vector3) -> void: _building_fire(city, p))
	await _shot("fire_none", 240, func(_p: Vector3) -> void: pass)  # the same frame, no fire
	await _shot(
		"fire_far_smoke",
		300,
		func(_p: Vector3) -> void: city.fire(_feet() + FAR_SPOT * bs, 1.5),
		FAR_SPOT
	)
	await _shot("explosion_wreck", 6, func(p: Vector3) -> void: TankFx.wreck(city, p))
	await _shot("dust_cloud", 25, func(p: Vector3) -> void: fx.dust(p, 2.0 * bs))
	await _shot(
		"dust_topple",
		25,
		func(p: Vector3) -> void: fx.dust(p, 2.0 * bs, Color(0.8, 0.78, 0.72, 0.5))
	)
	await _shot(
		"dust_footfall",
		12,
		func(_p: Vector3) -> void: fx.footfall(_feet() + FOOT_SPOT * bs, 1.5 * bs, false),
		FOOT_SPOT
	)
	await _shot(
		"dust_tree_puff", 8, func(p: Vector3) -> void: fx.tree_puff(p, TREE_SIZE, TREE_ALPHA)
	)
	await _shot("ring_stomp", 17, func(p: Vector3) -> void: fx.shockwave(p, STOMP_RADIUS * bs))
	await _shot("ring_tail_sweep", 17, func(p: Vector3) -> void: _tail_sweep(p, TAIL_REACH * bs))
	await _shot("sparks_shell_hit", 10, func(p: Vector3) -> void: fx.sparks(p + Vector3.UP))
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
	if not _only.is_empty() and not _only.has("breath_aim"):
		_finish()
		return
	_aim(true)
	await _frames(30)
	_still("breath_aim", _feet() + _ahead() * 6.0 * bs)
	await _press("signature", "breath", [10, 24])
	await _frames(GAP * 2)
	await _press("ultimate", "ultimate_beam", [20, 60])
	_finish()


## An estimate of how wide `shot_name`'s effect is on screen at 1080p (px), from its world size at
## `frames` frames in: the ring's front radius at its tween's progress, a puff's mesh and scale.
func _width_px(shot_name: String, at: Vector3, frames: int) -> int:
	var bs := _rampage.sim.body_scale()
	var ring: Dictionary = Content.section("fx")["shockwave"]
	var grown := clampf((frames - 1) / (60.0 * Num.f(ring["seconds"])), 0.0, 1.0)
	var reach := Num.f(ring["radius_scale"]) * 1.2
	var metres := 0.0
	match shot_name:
		"ring_stomp":
			metres = 2.0 * grown * STOMP_RADIUS * bs * reach
		"ring_tail_sweep":
			metres = 2.0 * grown * TAIL_REACH * bs
		"dust_tree_puff":
			metres = TREE_SIZE * Fx.TREE_PUFF_SCALE * 1.2
		"dust_footfall":
			metres = 3.0 * 1.05 * 1.5 * bs * 0.88 + 1.2 * 1.5 * bs  # a puff at this age, and its box
		"sparks_deflect":
			metres = 5.5 * bs * 0.465  # the flare's soft core, FWHM of exp(-4 r^2) in its quad
		_:
			return 0
	var cam := root.get_viewport().get_camera_3d()
	var size := Vector2(root.get_texture().get_image().get_size())
	var right := cam.global_transform.basis.x * metres * 0.5
	var a := Kit.image_point(self, cam, at - right, size)
	var b := Kit.image_point(self, cam, at + right, size)
	return roundi(absf(b.x - a.x))


func _finish() -> void:
	_points["_px"] = _px
	var file := FileAccess.open(_out.path_join("points.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_points))
	file.close()
	quit()


## Plays `play` at the effect spot, stills `after` frames later, then waits for it to clear.
func _shot(shot_name: String, after: int, play: Callable, spot := SPOT) -> void:
	if not _only.is_empty() and not _only.has(shot_name):
		return
	var p := _spot()
	play.call(p)
	await _frames(_after if _after > 0 else after)
	var at := _feet() + spot * _rampage.sim.body_scale()
	_still(shot_name, at + Vector3.UP * (4.0 if spot == FAR_SPOT else 1.0))
	_px[shot_name] = _width_px(shot_name, at, _after if _after > 0 else after)
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
	cam.fov = CameraTuning.fov()
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


## The tail sweep's ring as PowersView draws it for the sim's event (out to the tail's reach),
## centred on `at`. The dust line it also throws is family 3 (shot as dust_cloud) and the kaiju's
## own tail model would sweep across the frame: both are left out so the ring itself is seen.
func _tail_sweep(at: Vector3, reach: float) -> void:
	_city().fx.shockwave_to(at, reach)


## A burning building as the game lights it: a fire on each roof quarter (fire_spread.view_size).
func _building_fire(city: CityView, p: Vector3) -> void:
	var size := Num.f(_rampage.sim.powers_cfg["fire"]["view_size"])
	for off: Vector3 in [Vector3(-1.6, 0, -1.2), Vector3(1.6, 0, -1.2), Vector3(-1.6, 0, 1.2)]:
		city.fire(p + off + Vector3(0, 5.0, 0), size)


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
