extends SceneTree
## The croc titan standing in a real rampage at the game camera (D-165, the living predator): no
## input, HUD on. Prints when the rise from the river ends and the breath's top and bottom (the
## seconds into the clip), and with --shots saves a still at the first top and the first bottom
## once the layer is fully in, each with a 2x crop on the back. --stomps=0 stops the sim's own
## stomps (a stomp every 0.7 s lifts a foot and shakes the camera), to see the breath alone. Needs
## a window; pair with --write-movie for a clip.
## The breath trade (D-188): --no-claws (no claw rake: the arms stay still), --lock=<file> (the game
## camera held exactly where it was 2 s after the rise; the first run writes the file, the others
## read it, so panels of separate runs line up), and the options, all off by default: --gain=<x>
## (whole-body push), --head=<x> and --chest=<x> (lift), --swell=<x> (width), --plate=<x> (crests).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/c.avi \
##     --script tools/capture/capture_idle_game.gd -- --out=<dir> --stage=2 --seconds=24 \
##     [--shots] [--run=2] [--stomps=false]

const Kit := preload("res://tools/capture/capture_kit.gd")
const CROP := Vector2i(560, 420)

var _out := "user://idle_game"
var _stage := 2
var _seconds := 24.0
var _shots := false
var _stomps := true
var _quiet := false
var _px := false
var _no_claws := false
var _breath_only := false
var _lock := ""
var _hold: Callable
var _locked := Transform3D.IDENTITY
var _fov := 60.0
var _probe := BreathProbe.new()
var _options := {
	"push_gain": 1.0, "head_gain": 1.0, "chest_gain": 1.0, "swell": 0.0, "plate_lift": 0.0
}
var _run_index := 1  ## the run: its time of day is Content.time_for_run(run)


func _initialize() -> void:
	var a := Kit.args(
		{
			"out": _out,
			"stage": _stage,
			"seconds": _seconds,
			"shots": false,
			"stomps": true,
			"quiet": false,
			"px": false,
			"no_claws": false,
			"breath_only": false,
			"lock": "",
			"gain": 1.0,
			"head": 1.0,
			"chest": 1.0,
			"swell": 0.0,
			"plate": 0.0,
			"run": 1
		}
	)
	_out = str(a["out"])
	_stage = Num.i(a["stage"])
	_seconds = Num.f(a["seconds"])
	_shots = a["shots"]
	_stomps = a["stomps"]
	_quiet = a["quiet"]
	_px = a["px"]
	_no_claws = a["no_claws"]
	_breath_only = a["breath_only"]
	_lock = str(a["lock"])
	_options = {
		"push_gain": Num.f(a["gain"]),
		"head_gain": Num.f(a["head"]),
		"chest_gain": Num.f(a["chest"]),
		"swell": Num.f(a["swell"]),
		"plate_lift": Num.f(a["plate"])
	}
	_run_index = Num.i(a["run"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var levels: Dictionary = Kit.STAGE_LEVELS[_stage].duplicate()
	if _no_claws:
		levels.erase("claws")
	var trade: Dictionary = Content.section("croc_idle")["trade"]
	for key: String in _options:
		trade[key] = _options[key]
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", levels), _run_index)
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	root.add_child(rampage)
	await rampage.wait_loaded()
	var aim: Node3D = rampage.find_child("BreathAim", false, false)
	if aim != null:  # the breath's aim wedge is a game aid, not part of the shot
		aim.set_physics_process(false)
		aim.visible = false
	if not _stomps:
		rampage.sim.stats["stomp_interval"] = 100000.0
		rampage.sim._stomp_timer = 100000.0
	if _no_claws:  # the claw rake (every 4 s) lifts an arm 25 px: not the breath
		rampage.sim.stats["swipe_damage"] = 0.0
	if _quiet:  # no tanks, no helicopters: nothing to rake, no hits, no camera shake
		rampage.sim.army_units._spawn_timer = 1.0e9
		rampage.sim.air._spawn_timer = 1.0e9
		rampage.sim.tanks.clear()
	while rampage.sim.emerge.active:
		await process_frame
	var begin := Engine.get_process_frames()
	print(
		"capture_idle_game: run %d, time of day %s" % [_run_index, Content.time_for_run(_run_index)]
	)
	print("capture_idle_game: emerged at frame %d (%.2f s)" % [begin, float(begin) / 60.0])
	var gait: ClipAlive = rampage._kaiju._rig.gait
	gait.life.breath_only = _breath_only  # measuring: nothing but the breath moves
	if not _lock.is_empty():
		await _lock_camera(rampage)
	if _px:
		await _px_pair(rampage, gait)
		_release()
		quit()
		return
	var spine: Node3D = gait.rig.bone("spine2")
	var seen: Array[float] = []
	var shot_top := false
	var shot_bottom := false
	var rake_last := 0.0
	var hands: Array[Vector3] = []
	var hand_still := true
	while Engine.get_process_frames() - begin < int(_seconds * 60.0):
		await process_frame
		var at := float(Engine.get_process_frames() - begin) / 60.0
		var now := gait.life.breath
		seen.append(now)
		if gait.swing._rake_t > 0.0 and rake_last == 0.0:
			print("capture_idle_game: a claw rake starts at %.2f s" % at)
		rake_last = gait.swing._rake_t
		var hand := gait.rig.tail_world("arm_l2")
		hands.append(hand)
		if hands.size() > 30 and hand.distance_to(hands[-30]) > 0.5 and hand_still:
			hand_still = false
			print(
				(
					"capture_idle_game: the left hand swings out at %.2f s (rake_t %.2f)"
					% [at, rake_last]
				)
			)
		elif hands.size() > 30 and hand.distance_to(hands[-30]) < 0.1:
			hand_still = true
		if seen.size() > 2 and gait.life.weight >= 1.0:
			var top := seen[-2] > 0.5 and seen[-2] > seen[-1] and seen[-2] >= seen[-3]
			var bottom := seen[-1] <= 0.0001 and seen[-2] > 0.0001  # breathed out
			if top or bottom:
				print(
					(
						"capture_idle_game: breath %s at %.2f s (frame %d)"
						% ["top" if top else "bottom", at, Engine.get_process_frames()]
					)
				)
			if _shots and top and not shot_top:
				shot_top = true
				_snap(rampage, "breath_top", spine.global_position)
				_note("top", gait, true)
				await _empty_shot(rampage, "top")
			if _shots and bottom and not shot_bottom:
				shot_bottom = true
				_snap(rampage, "breath_bottom", spine.global_position)
				_note("bottom", gait, false)
				await _empty_shot(rampage, "bottom")
	if shot_top and shot_bottom and not _lock.is_empty():
		print("capture_idle_game: on screen at the game camera, 1080p:\n" + _probe.report())
	_release()
	quit()


## --px: with the world frozen at the game camera, three stills: the kaiju hidden (px_empty), the
## breath at its top (px_top: the biggest push, at the top of the curve, the lag down the back
## as played) and at rest (px_rest), so the only difference between the last two is the breath.
func _px_pair(rampage: Rampage, gait: ClipAlive) -> void:
	while gait.life.weight < 1.0:
		await process_frame
	var skin: VoxelSkin = rampage._kaiju._skin
	var cfg := Content.section("croc_idle")
	var amp: Array = cfg["skin_amp"]
	var peak := Num.f(amp[_stage]) * KaijuModel.MODEL_HEIGHT
	var lag := Num.f(cfg["skin_lag"])
	paused = true
	for pass_name: String in ["empty", "top", "rest"]:
		rampage._kaiju.visible = pass_name != "empty"
		for mat: ShaderMaterial in [skin._cubes, skin._fill]:
			mat.set_shader_parameter("breath", peak if pass_name == "top" else 0.0)
			mat.set_shader_parameter("breath_phase", 0.4)
			mat.set_shader_parameter("breath_lag", lag)
		for i: int in 4:
			await process_frame
		root.get_texture().get_image().save_png(
			_out.path_join("px_%s_%d.png" % [pass_name, _stage])
		)
	print("capture_idle_game: px stills saved (push %.3f rig units, lag %.2f)" % [peak, lag])


## Holds the camera where it is (or, if the file exists, where the file says: the first run's),
## from the next frame on, whatever the game does to it (the follow, a kick, the shake).
func _lock_camera(rampage: Rampage) -> void:
	for i: int in 120:
		await process_frame
	var cam: Camera3D = rampage._camera
	var locked := cam.global_transform
	var fov := cam.fov
	if FileAccess.file_exists(_lock):
		var saved: Array = JSON.parse_string(FileAccess.get_file_as_string(_lock))
		locked = Transform3D(
			Basis(
				Vector3(Num.f(saved[0]), Num.f(saved[1]), Num.f(saved[2])),
				Vector3(Num.f(saved[3]), Num.f(saved[4]), Num.f(saved[5])),
				Vector3(Num.f(saved[6]), Num.f(saved[7]), Num.f(saved[8]))
			),
			Vector3(Num.f(saved[9]), Num.f(saved[10]), Num.f(saved[11]))
		)
		fov = Num.f(saved[12])
	else:
		var b := locked.basis
		var row := [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z]
		row.append_array([locked.origin.x, locked.origin.y, locked.origin.z, fov])
		var file := FileAccess.open(_lock, FileAccess.WRITE)
		file.store_string(JSON.stringify(row))
	var hold := func() -> void:
		RenderingServer.camera_set_transform(cam.get_camera_rid(), locked)
		RenderingServer.camera_set_perspective(cam.get_camera_rid(), fov, cam.near, cam.far)
	_hold = hold
	_locked = locked
	_fov = fov
	RenderingServer.frame_pre_draw.connect(hold)
	print("capture_idle_game: camera held at %s" % str(locked.origin))


func _note(label: String, gait: ClipAlive, pushed: bool) -> void:
	if _lock.is_empty():
		return
	_probe.setup(_locked, _fov, root.get_visible_rect().size)
	_probe.record(label, gait, pushed)


func _release() -> void:
	if _hold.is_valid() and RenderingServer.frame_pre_draw.is_connected(_hold):
		RenderingServer.frame_pre_draw.disconnect(_hold)


## The same view a frame later without the kaiju (the silhouette is what differs); it shows again.
func _empty_shot(rampage: Rampage, label: String) -> void:
	rampage._kaiju.visible = false
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(_out.path_join("empty_%s_%d.png" % [label, _stage]))
	rampage._kaiju.visible = true


func _snap(rampage: Rampage, shot_name: String, at: Vector3) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join("%s_%d.png" % [shot_name, _stage]))
	var centre := Kit.image_point(self, rampage._camera, at, Vector2(img.get_size()))
	Kit.crop_2x(img, centre, CROP, _out.path_join("%s_%d_2x.png" % [shot_name, _stage]))
