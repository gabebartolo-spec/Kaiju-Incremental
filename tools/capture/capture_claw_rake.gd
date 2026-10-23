extends SceneTree
## The croc standing still in a real rampage at the game camera (no input: the sim's own claw
## rakes, every 2 s, alternating arms, are all that happens). For the heavy claw rake's proof: a
## clip of --seconds from the moment the rise from the river ends (pair with --write-movie), and
## with --shots a 2x crop round the arms at the load, the strike (the sim's hit) and the
## follow-through of the first rake. Needs a window; the off-screen no_focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/rake.avi
##     --script tools/capture/capture_claw_rake.gd -- --out=<dir> --stage=1 --seconds=6 [--shots]
##   --stage 0 young croc, 1 Behemoth, 2 Colossus (Kit.STAGE_LEVELS)

const Kit := preload("res://tools/capture/capture_kit.gd")
const CROP := Vector2i(640, 480)
## Seconds past the hit where the follow-through still is taken (the overshoot's far end).
const FOLLOW := 0.18
## The claw counts as seen when it is this many pixels outside the torso's screen box.
const MARGIN_PX := 1.0

var _out := "user://claw_rake"
var _seconds := 6.0
var _stage := 1
var _shots := false
var _seen: Array[Dictionary] = []  # per frame of a rake: its time, and does the camera see the claw


func _initialize() -> void:
	var a := Kit.args({"out": _out, "seconds": _seconds, "stage": _stage, "shots": false})
	_out = str(a["out"])
	_seconds = Num.f(a["seconds"])
	_stage = Num.i(a["stage"])
	_shots = a["shots"]
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var levels: Dictionary = Kit.STAGE_LEVELS[_stage]
	var stats := Kit.stats("reptilian", levels)
	stats["stomp_interval"] = 9999.0  # standing, no footstep: nothing but the rake moves the camera
	var rampage := Kit.rampage("reptilian", stats, 1)
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	root.add_child(rampage)
	await rampage.wait_loaded()
	var aim: Node3D = rampage.find_child("BreathAim", false, false)
	if aim != null:  # the breath's aim wedge is a game aid, not part of the shot
		aim.set_physics_process(false)
		aim.visible = false
	while rampage.sim.emerge.active:
		await process_frame
	print("capture_claw_rake: emerged at frame %d" % Engine.get_process_frames())
	var start := Engine.get_process_frames()
	var swing: BipedSwing = (rampage._kaiju._rig.gait as BipedGait).swing
	var taken: Array[String] = []
	var chest := _cells(swing.rig, ["spine1", "spine2"])
	var body := _cells(swing.rig, ["spine0", "spine1", "spine2"])
	while Engine.get_process_frames() - start < int(_seconds * 60.0):
		await process_frame
		_record(rampage, swing, chest, body)
		if not _shots or not swing.has_method("rake_marks"):
			continue
		var t: float = swing.call("rake_time")
		var marks: Dictionary = swing.call("rake_marks")
		var want := {
			"load": Num.f(marks["load_end"]),
			"strike": Num.f(marks["hit"]),
			"follow": Num.f(marks["hit"]) + FOLLOW,
		}
		for shot_name: String in want:
			if t >= Num.f(want[shot_name]) and t >= 0.0 and not taken.has(shot_name):
				taken.append(shot_name)
				_snap(rampage, "stage%d_%s" % [_stage, shot_name], swing)
	print("capture_claw_rake: stills %s" % [taken])
	_report(swing)
	quit()


## The torso voxels as [bone, local point] pairs (every 3rd: the silhouette needs only its edge).
func _cells(rig: KaijuRig, bones: Array[String]) -> Array[Array]:
	var out: Array[Array] = []
	for n: String in bones:
		var part := rig.voxels_of(n)
		var k := 0
		for cell: Vector3i in part.cells:
			k += 1
			if k % 3 == 0:
				out.append([rig.bone(n), Vector3(cell) * rig.voxel_size() - rig.head_of(n)])
	return out


## The screen box of a set of torso voxels, as the game camera shows them now.
func _box(cam: Camera3D, cells: Array[Array]) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for pair: Array in cells:
		var bone: Node3D = pair[0]
		var local: Vector3 = pair[1]
		var p := cam.unproject_position(bone.global_transform * local)
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)


## One frame: while a rake runs, the claw's screen spot against the chest's and the body's boxes (it
## shows when it is outside the box by at least a pixel margin), from the real game camera.
func _record(rampage: Rampage, swing: BipedSwing, chest: Array[Array], body: Array[Array]) -> void:
	var t: float = swing.call("rake_time")
	if t < 0.0:
		return
	var cam: Camera3D = rampage._camera
	var tip := swing.rake_tip()
	var claw := cam.unproject_position(tip)
	var seen := {"t": t}
	seen["chest"] = not _box(cam, chest).grow(MARGIN_PX).has_point(claw)
	seen["body"] = not _box(cam, body).grow(MARGIN_PX).has_point(claw)
	# the streak on screen: the diagonal of its marks' box, and the nearest mark's gap to the claw
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var head := INF
	for point: Vector3 in swing.rake_trail():
		var p := cam.unproject_position(point)
		lo = lo.min(p)
		hi = hi.max(p)
		head = minf(head, p.distance_to(claw))
	seen["trail_px"] = (hi - lo).length() if head < INF else 0.0
	seen["head_px"] = head if head < INF else -1.0
	_seen.append(seen)


## Per swipe: the frames round the sim hit (the first at or past it, 4 each side) and the wind-up
## frames (2 after the cue to 5 before the hit's window) in which the camera sees the claw.
func _report(swing: BipedSwing) -> void:
	var marks: Dictionary = swing.rake_marks()
	var hit := Num.f(marks["hit"])
	var first := 0
	for i: int in _seen.size() + 1:
		if i == _seen.size() or (i > 0 and Num.f(_seen[i]["t"]) < Num.f(_seen[i - 1]["t"])):
			_swipe_report(_seen.slice(first, i), hit)
			first = i


func _swipe_report(frames: Array, hit: float) -> void:
	var at := 0
	while at < frames.size() and Num.f(frames[at]["t"]) < hit:
		at += 1
	var line := "stage %d hit frame %d of %d:" % [_stage, at, frames.size()]
	for key: String in ["chest", "body"]:
		var round_hit := 0
		for i: int in range(maxi(0, at - 4), mini(frames.size(), at + 5)):
			round_hit += 1 if frames[i][key] else 0
		var windup := 0
		for i: int in range(2, maxi(2, at - 4)):
			windup += 1 if frames[i][key] else 0
		line += (
			" %s: round hit %d of 9, wind-up %d of %d;" % [key, round_hit, windup, maxi(0, at - 6)]
		)
	line += " trail px (extent / head gap) on the hit frame and 3 after:"
	for i: int in range(at, mini(frames.size(), at + 4)):
		line += " %.0f/%.0f" % [frames[i]["trail_px"], frames[i]["head_px"]]
	print("VIS ", line)


func _snap(rampage: Rampage, shot_name: String, swing: BipedSwing) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(shot_name + ".png"))
	var rig := swing.rig
	var at: Vector3 = swing.call("rake_tip")  # the 2x crop is on the claw
	var centre := Kit.image_point(self, rampage._camera, at, Vector2(img.get_size()))
	Kit.crop_2x(img, centre, CROP, _out.path_join(shot_name + "_2x.png"))
