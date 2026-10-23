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
## The clip: frames before the burst, from the burst to the spin's kill, and the whole shot.
## The tallest building (metres) a wreck is dropped beside.
const LOW_BLOCK := 9
const CLIP_LEAD := 20
const CLIP_GAP := 100
const CLIP_FRAMES := 360
## The second clip helicopter's angle round the kaiju from the first, and the frames helicopters
## are parked before the shot.
const CLIP_SPREAD := 0.4
const PARK := 45
## Where the reference building fire stands from the wreck's spot.
const REF_OFFSET := Vector2(16.0, 6.0)
## Frames the first burst's wreck is given to lie there and fade (rest and fade seconds, tuning).
const SETTLE_WRECK := 420

var _out := "user://heli_deaths"
var _clip := false
var _rampage: Rampage
var _spot := Vector2.ZERO
var _block := -1  # the building the wreck is dropped beside


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
	PlayerSettings.controls_seen = true  # no first-run controls card over the shot
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
	air.cfg["max"] = 0  # no other helicopter drifts into the shot
	_spot = _rampage.sim.kaiju_pos + Vector2(SPOT.x, SPOT.z) * _rampage.sim.body_scale()
	print("body scale %.2f" % _rampage.sim.body_scale())
	_reference_fire()
	if _clip:
		await _clip_run()
	else:
		await _stills()
	quit()


func _stills() -> void:
	var burst := await _spawn([_spot] as Array[Vector2])
	await _blow(burst[0], 1.0, _spot)
	await _shots("burst", [2, 12, 30, 60, 100])
	await Kit.frames(self, SETTLE_WRECK)
	_spot = _block_beside(_spot)
	var spin := await _spawn([_spot] as Array[Vector2])
	await _blow(spin[0], 0.2, _spot)
	await _shots("spin", [8, 35, 70, 105])
	var sim := _rampage.sim
	var limit := 0
	while not sim.air.falling.is_empty() and limit < 400:
		await physics_frame  # until the wreck lands
		limit += 1
	await process_frame
	await _shots("crash", [0, 12, 40, 80, 200, 330])
	print("buildings alive at the end %d" % _alive())


## The 6 s clip: two helicopters parked over the street; the first is blown apart, then the
## second spins down to its crash. It starts at CLIP_LEAD (the movie also holds the setup: the
## frame is printed, to cut from).
func _clip_run() -> void:
	var sim := _rampage.sim
	var first := sim.kaiju_pos + (_spot - sim.kaiju_pos).rotated(CLIP_SPREAD)
	var both := await _spawn([_spot, first] as Array[Vector2])
	var block := _block_beside(_spot)
	print("clip starts at frame %d" % Engine.get_frames_drawn())
	await Kit.frames(self, CLIP_LEAD)
	await _blow(both[0], 1.0, block)
	await Kit.frames(self, CLIP_GAP)
	await _blow(both[1], 0.2, block)
	await Kit.frames(self, CLIP_FRAMES - CLIP_LEAD - CLIP_GAP)


## Stills `name`_<n> the n frames after now (n counted from the last still's moment).
func _shots(shot: String, at: Array) -> void:
	var waited := 0
	for n: int in at:
		await Kit.frames(self, n - waited)
		waited = n
		_still("%s_%03d" % [shot, n])


## Spawns a helicopter for each of `toward` and parks it on its circle toward that point for
## PARK frames (the view draws it first, then they hold over the street); returns them.
func _spawn(toward: Array[Vector2]) -> Array[AirWing.Heli]:
	var sim := _rampage.sim
	sim.events.clear()
	var helis: Array[AirWing.Heli] = []
	for n: int in toward.size():
		helis.append(sim.air.spawn())
		_hand_over(sim)
	for i: int in PARK:
		for n: int in helis.size():
			var heli: AirWing.Heli = helis[n]
			var at: Vector2 = toward[n]
			heli.pos = at
			heli.angle = (at - sim.kaiju_pos).angle()
		await physics_frame
	for node: Node3D in _rampage._powers.helis():
		print("parked helicopter opacity %.2f" % Num.f(node.get_meta("opacity", 1.0)))
	return helis


## Downs `heli` alone with a last blow of `share` of its hp. A spin falls straight onto `land`
## (the sim's crash point and the view's wreck both), wherever it was hit.
func _blow(heli: AirWing.Heli, share: float, land: Vector2) -> void:
	var sim := _rampage.sim
	var hp := Num.f(sim.air.cfg["hp"])
	heli.hp = hp * share * 0.5
	var at := heli.pos
	sim.events.clear()
	sim.air.hit(
		func(p: Vector2, _r: float) -> float: return 1.0 if p.distance_to(at) < 1.0 else 0.0,
		hp * share,
		true
	)
	for down: AirWing.Falling in sim.air.falling:
		if down.id == heli.id:
			down.drift = Vector2.ZERO
			down.pos = land
	for event: Dictionary in sim.events:
		if event.has("dx"):
			event["dx"] = 0.0
			event["dz"] = 0.0
			event["x"] = land.x
			event["z"] = land.y
	_hand_over(sim)


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


## A street fire (Fire as a building fire is drawn) beside the shot: the flame body is judged
## against it, same camera, same frame.
func _reference_fire() -> void:
	var fire := Fire.new(2.0, 1.0)
	_rampage.add_child(fire)
	fire.global_position = Vector3(_spot.x + REF_OFFSET.x, 0.0, _spot.y + REF_OFFSET.y)


## Events made outside a step (this script's spawn and kill) go to the view as a step's would.
func _hand_over(sim: RampageSim) -> void:
	for event: Dictionary in sim.events:
		_rampage._on_event(event)


## Standing voxels of the building the wreck lands beside: what its smashed floors lower.
func _alive() -> int:
	var grid := _rampage.sim.carving.frame(_block)  # the fine grid, once the building is carved
	var own: VoxelFrame = _rampage.sim.buildings[_block].frame if grid == null else grid
	return own.alive_count


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
			_block = _rampage.sim.buildings.find(b)
			best = Vector2(b.x, b.z + b.d * 0.5 + 1.0)
	print(
		"spot %s -> %s (%.1f off, tier %d)" % [from, best, gap, _rampage.sim.buildings[_block].tier]
	)
	return best
