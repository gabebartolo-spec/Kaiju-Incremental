extends SceneTree
## Helicopter deaths at the game camera (HeliWreck, D-140): one helicopter blown apart in the
## air, then one spun down burning onto a block, crew bailing out, and its crash. Stills at the
## key moments, each a full 1x frame plus a 2x crop on the helicopter; with --clip a 6 s run
## (a burst, then a spin to its crash) for --write-movie instead. Needs a window and the
## no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_heli_deaths.gd -- --out=<dir> --run=1   (1 night, 3 noon)

const Kit := preload("res://tools/capture/capture_kit.gd")
const LEVELS := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1, "r_ablaze": 1}
const SETTLE := 120
## Where each helicopter is put, from the kaiju's feet, in body-scale units (camera looks down -z).
const SPOT := Vector3(6.0, 0.0, -9.0)
## The 2x crop's size in pixels (1x), and how high above the street it is centred.
const CROP := Vector2i(520, 330)
const CROP_HEIGHT := 6.0
## The clip: frames before the burst, from the burst to the spin's kill, and the whole run.
## The tallest building (metres) a wreck is dropped beside.
const LOW_BLOCK := 9
const CLIP_LEAD := 20
const CLIP_GAP := 110
const CLIP_FRAMES := 360

var _out := "user://heli_deaths"
var _clip := false
var _rampage: Rampage
var _spot := Vector2.ZERO


func _initialize() -> void:
	var a := Kit.args({"out": _out, "run": 1, "clip": false})
	_out = str(a["out"])
	_clip = a["clip"] == true
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
	_aim(false)
	_rampage.sim.time_left = 600.0
	var air := _rampage.sim.air
	air.cfg["bailout_chance"] = 1.0  # the shot shows a crew bailing out (seeded otherwise)
	air.cfg["fire_interval"] = 999.0  # it never strafes the kaiju in the shot
	_spot = _rampage.sim.kaiju_pos + Vector2(SPOT.x, SPOT.z) * _rampage.sim.body_scale()
	print("body scale %.2f" % _rampage.sim.body_scale())
	_spot = _block_beside(_spot)
	if _clip:
		await _clip_run()
	else:
		await _stills()
	quit()


func _stills() -> void:
	await _down(1.0, "burst", [1, 20, 60])
	await Kit.frames(self, 120)
	await _down(0.2, "spin", [10, 60], [0, 12, 40, 80])  # then the crash, shot after its frame
	await Kit.frames(self, 30)
	print("buildings alive at the end %d" % _alive())


## The 6 s clip: a burst, then a spin down to its crash; every frame is the movie's.
func _clip_run() -> void:
	await Kit.frames(self, CLIP_LEAD)
	var frames := CLIP_LEAD
	await _kill(1.0)
	await Kit.frames(self, CLIP_GAP)
	frames += CLIP_GAP
	await _kill(0.2)
	await Kit.frames(self, CLIP_FRAMES - frames)


## Spawns a helicopter over the spot, holds it there a moment, then downs it with a last blow of
## `share` of its hp; stills `name` the frames in `at` after, then (for a spin) each `after`
## frame past the crash.
func _down(share: float, shot: String, at: Array, after := []) -> void:
	await _kill(share, true)
	var waited := 0
	for n: int in at:
		await Kit.frames(self, n - waited)
		waited = n
		_still("%s_%03d" % [shot, n])
	if after.is_empty():
		return
	var sim := _rampage.sim
	var limit := 0
	var alive := _alive()
	while not sim.air.falling.is_empty() and limit < 400:
		await physics_frame  # until the wreck lands
		limit += 1
	await process_frame
	print("buildings alive %d -> %d" % [alive, _alive()])
	waited = 0
	for n: int in after:
		await Kit.frames(self, n - waited)
		waited = n
		_still("crash_%03d" % n)


## Puts a helicopter over the spot and downs it with a blow of `share` of its hp. `settle`: the
## frames it is first given to get onto its circle (the view draws it) before it is parked.
func _kill(share: float, settle := false) -> void:
	var sim := _rampage.sim
	sim.events.clear()
	var heli := sim.air.spawn()
	_hand_over(sim)
	for i: int in 45:  # the view gets it onto its circle, then we park it over the block
		heli.pos = _spot
		heli.angle = (_spot - sim.kaiju_pos).angle()
		await physics_frame
	var hp := Num.f(sim.air.cfg["hp"])
	heli.hp = hp * share * 0.5
	sim.events.clear()
	sim.air.hit(func(_p: Vector2, _r: float) -> float: return 1.0, hp * share, true)
	for down: AirWing.Falling in sim.air.falling:
		down.drift = Vector2.ZERO  # it falls onto the block below
	for event: Dictionary in sim.events:
		if event.has("dx"):
			event["dx"] = 0.0
			event["dz"] = 0.0
	_hand_over(sim)
	if settle:
		await process_frame


## The game's frame as a still, and a 2x crop of it round the spot (the helicopter's height).
func _still(shot_name: String) -> void:
	var path := Kit.still(self, _out, shot_name)
	var cam := root.get_viewport().get_camera_3d()
	var shot := Image.load_from_file(path)
	var world := Vector3(_spot.x, CROP_HEIGHT, _spot.y)
	var at := Kit.image_point(self, cam, world, Vector2(shot.get_size()))
	var metre := Kit.image_point(self, cam, world + Vector3.RIGHT, Vector2(shot.get_size()))
	print("%s: centre %s, %.1f px per metre" % [shot_name, at, at.distance_to(metre)])
	Kit.crop_2x(shot, at, CROP, _out.path_join(shot_name + "_2x.png"))


## Shows or hides the ready breath's aim wedge (BreathAim sets itself every physics frame).
func _aim(on: bool) -> void:
	for node: Node in _rampage.get_children():
		if node is BreathAim:
			node.set_physics_process(on)
			(node as Node3D).visible = false


## Events made outside a step (this script's spawn and kill) go to the view as a step's would.
func _hand_over(sim: RampageSim) -> void:
	for event: Dictionary in sim.events:
		_rampage._on_event(event)


## Standing voxels in the whole city: what a crash's smashed floors lower.
func _alive() -> int:
	var total := 0
	for b: RampageSim.Building in _rampage.sim.buildings:
		total += b.frame.alive_count
	return total


## The spot moved to the camera-side face of the nearest low building, so the wreck's crash smashes
## its floors where the camera sees them (the sim's crash hits what is within crash_radius).
func _block_beside(from: Vector2) -> Vector2:
	var best := from
	var gap := INF
	for b: RampageSim.Building in _rampage.sim.buildings:
		if b.height > LOW_BLOCK or b.w < 5 or b.frame.alive_count == 0:
			continue
		var d := Vector2(b.x, b.z).distance_to(from)
		if d < gap:
			gap = d
			best = Vector2(b.x, b.z + b.d * 0.5 + 1.0)
	print("spot %s -> %s (%.1f off)" % [from, best, gap])
	return best
