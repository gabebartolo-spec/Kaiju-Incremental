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
## Where the kaiju's claw reaches, in the swipe's own band (body-scale units from its feet): the
## first helicopter hangs this far ahead and to the side (a kill nothing covers), the second where
## the nearest low block's face is.
const FIRST_AT := Vector2(8.5, 4.4)
const SECOND_AT := Vector2(10.5, -3.5)
## Where the second clip helicopter waits, beside the claw's band.
const WAIT_AT := Vector2(10.5, -10.0)
## The 2x crop's size in pixels (1x), and how high above the street it is centred.
const CROP := Vector2i(520, 330)
const CROP_HEIGHT := 6.0
## The clip: frames before the burst, from the burst to the spin's kill, and the whole shot.
## The tallest building (metres) a wreck is dropped beside.
const LOW_BLOCK := 30
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
	_rampage.sim.powers.swipe._timer = 999.0  # the kaiju's claw swings only when the shot calls it
	_rampage.sim._stomp_timer = 99999.0  # and it does not stomp: a footfall is not the cause
	if _clip:
		await _clip_run()
	else:
		await _stills()
	quit()


func _stills() -> void:
	_spot = _spot_from(FIRST_AT)
	var burst := await _spawn([_spot] as Array[Vector2])
	await _swat(burst[0], true)
	await _shots("burst", [2, 12, 30, 60, 100])
	await Kit.frames(self, SETTLE_WRECK)
	_spot = _block_beside(_spot_from(SECOND_AT))
	var hung := _spot_from(SECOND_AT)
	var spin := await _spawn([hung] as Array[Vector2])
	await _swat(spin[0], false, _spot)
	await _shots("spin", [8, 35, 70, 105])
	var sim := _rampage.sim
	var limit := 0
	while not sim.air.falling.is_empty() and limit < 400:
		await physics_frame  # until the wreck lands
		limit += 1
	await process_frame
	await _shots("crash", [0, 12, 40, 80, 200, 330])
	print("buildings alive at the end %d" % _alive())


## The 6 s clip: two helicopters hung over the street, each killed by the kaiju's own claw swipe
## (its arm lifts first, the rake lands on them): the first blows apart, then the second spins down
## to its crash. It starts at CLIP_LEAD (the movie also holds the setup: the frame is printed).
func _clip_run() -> void:
	var first := _spot_from(FIRST_AT)
	var block := _block_beside(_spot_from(SECOND_AT))
	var wait := _spot_from(WAIT_AT)  # out of the first swipe's reach until it is the second's turn
	var both := await _spawn([first, wait] as Array[Vector2])
	print("clip starts at frame %d" % Engine.get_frames_drawn())
	_trace()
	await Kit.frames(self, CLIP_LEAD)
	await _swat(both[0], true)
	await _slide(both[1], wait, _spot_from(SECOND_AT), CLIP_GAP - 15)
	await Kit.frames(self, 15)
	await _swat(both[1], false, block)
	await Kit.frames(self, CLIP_FRAMES - CLIP_LEAD - CLIP_GAP)


## Stills `name`_<n> the n frames after now (n counted from the last still's moment).
func _shots(shot: String, at: Array) -> void:
	var waited := 0
	for n: int in at:
		await Kit.frames(self, n - waited)
		waited = n
		_still("%s_%03d" % [shot, n])


## Spawns a helicopter for each of `toward` and hangs it there (the sim's own orbit, flattened to a
## fixed point: no dive, no sweep) for PARK frames, so the view draws it before the shot.
func _spawn(toward: Array[Vector2]) -> Array[AirWing.Heli]:
	var sim := _rampage.sim
	sim.air.cfg["orbit_speed"] = 0.0
	sim.air.cfg["dive"] = 1.0
	sim.events.clear()
	var helis: Array[AirWing.Heli] = []
	for n: int in toward.size():
		var heli := sim.air.spawn()
		var out: Vector2 = toward[n] - sim.kaiju_pos
		heli.angle = out.angle()
		heli.radius = out.length()
		heli.cruise = out.length()
		heli.pos = toward[n]
		helis.append(heli)
		_hand_over(sim)
	for i: int in PARK:
		await physics_frame
	for node: Node3D in _rampage._powers.helis():
		print("parked helicopter opacity %.2f" % Num.f(node.get_meta("opacity", 1.0)))
	return helis


## The kaiju's own claw swipe downs `heli`: the arm lifts (the swipe's windup, 0.3 s) and the rake
## lands on it, through the sim's own hit path. `apart` sets the blow's weight: a killing blow
## that blows it apart in the air, or a glancing one that spins it down. Returns on the frame the
## sim downs it.
func _swat(heli: AirWing.Heli, apart: bool, land := Vector2.ZERO) -> void:
	var sim := _rampage.sim
	sim.air.cfg["blow_apart"] = 0.0 if apart else 99.0
	if not apart:
		_aim_fall(heli, land)
	heli.hp = 0.5
	var swipe: ClawSwipe = sim.powers.swipe
	swipe._wound = false  # the arm lifts (the windup cue) only if the swipe is not already wound
	swipe._timer = Num.f(sim.powers_cfg["swipe_windup"]) + 0.01
	var before := sim.air.destroyed
	var guard := 0
	print(
		(
			"swat: kaiju %s facing %s band %.1f..%.1f x %.1f, heli at %s hp %.1f swipes %d"
			% [
				sim.kaiju_pos,
				sim.facing,
				Num.f(sim.powers_cfg["swipe_near"]) * sim.body_scale(),
				Num.f(sim.powers_cfg["swipe_far"]) * sim.body_scale(),
				sim.stat("swipe_width") * sim.body_scale(),
				heli.pos,
				heli.hp,
				swipe.swipes
			]
		)
	)
	while sim.air.destroyed == before and guard < 120:
		await physics_frame
		guard += 1
		if guard % 20 == 0:
			print(
				(
					"  f%d destroyed %d hp %.1f timer %.2f pos %s"
					% [guard, sim.air.destroyed, heli.hp, swipe._timer, heli.pos]
				)
			)
	_report_dither()
	swipe._timer = 999.0  # the next one is called by the shot, never by the clock
	print("swat: downed after %d frames, blow %.1f" % [guard, heli.last_blow])


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


## Prints the lowest screen-door opacity on any dying helicopter part now in the view (1 = solid).
func _report_dither() -> void:
	var low := 1.0
	var parts := 0
	for node: Node in _rampage._powers._wrecks._debris.find_children(
		"*", "MultiMeshInstance3D", true, false
	):
		var mat := (node as MultiMeshInstance3D).material_override as ShaderMaterial
		if mat != null and mat.shader != null and mat.shader.code.contains("ember_light"):
			parts += 1
			low = minf(low, Num.f(mat.get_shader_parameter("opacity")))
	print("dither check: %d voxel parts in the view, lowest opacity %.2f" % [parts, low])


## Logs one line a frame for the clip (stdout "T,..."): a fixed ground point's screen position (the
## camera's kick, px at 1080p), both arm tips, the burning hull's height, screen point and roll, the
## falling wreck's height and yaw. The measured table of the report comes from it.
func _trace() -> void:
	var cam := root.get_viewport().get_camera_3d()
	var model: KaijuModel = _rampage._kaiju
	print(
		"T,n,rake_t,cam_x,cam_y,armL_x,armL_y,armR_x,armR_y,hull_y,hull_x,hull_py,roll,fall_y,yaw"
	)
	for n: int in CLIP_FRAMES - CLIP_LEAD + 10:
		var sim := _rampage.sim
		var feet := Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		var ref := cam.unproject_position(feet + Vector3(sim.facing.x, 0.0, sim.facing.y) * 6.0)
		var arm_l := cam.unproject_position(model._rig.tail_world("arm_l2"))
		var arm_r := cam.unproject_position(model._rig.tail_world("arm_r2"))
		var wrecks: HeliWreck = _rampage._powers._wrecks  # made on the first death
		var swing := (model._rig.gait as BipedGait).swing
		var hull := Vector3.ZERO
		var hull_px := Vector2.ZERO
		var roll := 0.0
		for piece: HeliDebris.Piece in [] if wrecks == null else wrecks._debris._pieces:
			if piece.heavy and is_instance_valid(piece.node):
				hull = piece.node.global_position
				hull_px = cam.unproject_position(hull)
				roll = rad_to_deg(piece.node.rotation.z)
				break
		var fall_y := 0.0
		var fall_yaw := 0.0
		for fall: HeliWreck.Fall in [] if wrecks == null else wrecks._falling.values():
			fall_y = fall.node.position.y
			fall_yaw = rad_to_deg(fall.yaw)
		print(
			(
				"T,%d,%.2f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.2f,%.1f,%.1f,%.1f,%.2f,%.1f"
				% [
					n,
					swing._rake_t,
					ref.x,
					ref.y,
					arm_l.x,
					arm_l.y,
					arm_r.x,
					arm_r.y,
					hull.y,
					hull_px.x,
					hull_px.y,
					roll,
					fall_y,
					fall_yaw
				]
			)
		)
		await process_frame


## Moves a hung helicopter from `from` to `to` over `frames` frames (its orbit's angle and radius).
func _slide(heli: AirWing.Heli, from: Vector2, to: Vector2, frames: int) -> void:
	var sim := _rampage.sim
	for n: int in frames:
		var at := from.lerp(to, float(n + 1) / frames)
		var out := at - sim.kaiju_pos
		heli.angle = out.angle()
		heli.radius = out.length()
		heli.cruise = out.length()
		await physics_frame


## Aims the sim's fall: the seeded draw that picks a falling wreck's drift direction is set to one
## that drifts `heli` onto `land` (fall_drift set to the distance), so it crashes on that block.
func _aim_fall(heli: AirWing.Heli, land: Vector2) -> void:
	var air := _rampage.sim.air
	var way := land - heli.pos
	air.cfg["fall_drift"] = way.length()
	var want := fposmod(way.angle(), TAU) / TAU
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 400000:
		rng.seed = seed_value
		if absf(rng.randf() - want) < 0.0004:
			air._fall_rng.seed = seed_value
			break
	print("fall aimed: %.1f m, angle share %.4f" % [way.length(), want])


## The point `at` (body-scale units: ahead, to the side) from the kaiju's feet, on the ground plane.
func _spot_from(at: Vector2) -> Vector2:
	var sim := _rampage.sim
	var ahead := sim.facing
	return sim.kaiju_pos + (ahead * at.x + ahead.orthogonal() * at.y) * sim.body_scale()


## Events made outside a step (this script's spawn and kill) go to the view as a step's would.
func _hand_over(sim: RampageSim) -> void:
	for event: Dictionary in sim.events:
		_rampage._on_event(event)


## Standing voxels of the building the wreck lands beside: what its smashed floors lower.
func _alive() -> int:
	if _block < 0:
		return 0
	var grid := _rampage.sim.carving.frame(_block)  # the fine grid, once the building is carved
	if grid != null:
		return grid.alive_count
	return _rampage.sim.buildings[_block].frame.alive_count


## The spot moved to the camera-side face of the nearest low building, so the wreck's crash smashes
## its floors where the camera sees them (the sim's crash hits what is within crash_radius).
func _block_beside(from: Vector2) -> Vector2:
	var best := from
	var gap := INF
	_block = -1
	for b: RampageSim.Building in _rampage.sim.buildings:
		if b.height > LOW_BLOCK or b.w < 5 or b.frame.alive_count == 0:
			continue
		var face := Vector2(b.x, b.z + b.d * 0.5 + 1.2)  # the camera-side face
		if face.distance_to(from) < gap:
			gap = face.distance_to(from)
			_block = _rampage.sim.buildings.find(b)
			best = face
	print("spot %s -> %s (%.1f off)" % [from, best, gap])
	return best
