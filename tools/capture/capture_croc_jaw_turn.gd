extends SceneTree
## The croc turning its head both ways in a real rampage, side-on, at night (the jaw seam check,
## director 2026-10-28: "is that a slit in crocs jaw? when he looks left or right"). After the rise
## from the river he stands, then the stick is barely pushed (TURN_PUSH: he turns nearly on the
## spot) to his left by TURN_DEG, then to his right by TURN_DEG: the head leads each turn by up to
## ClipGait.HEAD_LEAD_MAX. A free camera stands on his right side, square to where he faced, at
## head height. Prints the frame the turns start (where to cut the clip). With --dump, writes the
## skin's bone matrices each frame of the turns (VoxelSkin.pose, rig space), the rig's world scale
## and the voxel size to <out>/pose.json, for the seam parting measure (tools/kaiju_skin).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/c.avi \
##     --script tools/capture/capture_croc_jaw_turn.gd -- --out=<dir> [--stage=2] [--dump]

const Kit := preload("res://tools/capture/capture_kit.gd")
const TURN_DEG := 60.0
const TURN_PUSH := 0.08  ## stick push (0..1): enough to turn, too little to walk off
const LEFT_S := 2.5  ## seconds pushed to his left, then to his right until the end
const SETTLE_S := 1.0  ## standing after the rise before the first push
const CAM_BACK := 2.4  ## camera distance from the head, in head-to-pelvis lengths
const CAM_TOWARD_HEAD := 0.7  ## aim point from the pelvis (0) to the head (1)

var _out := "user://croc_jaw_turn"
var _stage := 2
var _seconds := 6.0
var _dump := false
var _tod := "night"


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args(
		{"out": _out, "stage": _stage, "seconds": _seconds, "dump": false, "tod": _tod}
	)
	_out = str(a["out"])
	_stage = Num.i(a["stage"])
	_seconds = Num.f(a["seconds"])
	_dump = a["dump"]
	_tod = str(a["tod"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", Kit.STAGE_LEVELS[_stage]), 1)
	Content.set_time(_tod)
	Content.set_weather("clear")
	var start := [-1.0]
	var facing := [Vector2.ZERO]
	rampage.scripted = func(sim: RampageSim) -> Dictionary:
		if start[0] < 0.0:
			return {"move": Vector2.ZERO}
		if facing[0] == Vector2.ZERO:
			facing[0] = sim.facing
		var since: float = start[0]
		var t := sim.elapsed - since
		var deg := TURN_DEG if t < LEFT_S else -TURN_DEG
		var ahead: Vector2 = facing[0]
		# facing rotated +deg is to his left (KaijuModel.animate takes -turn_left as the look)
		return {"move": ahead.rotated(deg_to_rad(deg)) * TURN_PUSH}
	root.add_child(rampage)
	await rampage.wait_loaded()
	var aim: Node3D = rampage.find_child("BreathAim", false, false)
	if aim != null:  # the breath's aim wedge is a game aid, not part of the shot
		aim.set_physics_process(false)
		aim.visible = false
	while rampage.sim.emerge.active:
		await process_frame
	await Kit.frames(self, int(SETTLE_S * 60.0))
	var kaiju: KaijuModel = rampage._kaiju
	var rig: KaijuRig = kaiju._rig
	var head := rig.bone("head1").global_position
	var pelvis := rig.bone("spine0").global_position
	var fwd := Vector3(head.x - pelvis.x, 0.0, head.z - pelvis.z)
	var length := fwd.length()
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var at := pelvis.lerp(head, CAM_TOWARD_HEAD)
	at.y = head.y
	var cam := Kit.camera(root)
	cam.position = at + right * length * CAM_BACK
	cam.look_at(at)
	cam.current = true
	start[0] = rampage.sim.elapsed
	print("capture_croc_jaw_turn: turns start at frame %d" % Engine.get_process_frames())
	var frames: Array = []
	var gait: ClipGait = rig.gait
	var skin: VoxelSkin = kaiju._skin
	for f: int in int(_seconds * 60.0):
		await process_frame
		if not _dump:
			continue
		var mats: Array = []
		for p: Projection in skin.pose:
			mats.append(
				[p.x.x, p.x.y, p.x.z, p.y.x, p.y.y, p.y.z, p.z.x, p.z.y, p.z.z, p.w.x, p.w.y, p.w.z]
			)
		frames.append({"look": gait._look, "state": gait.state, "pose": mats})
	if _dump:
		var out := {
			"stage": _stage,
			"bones": rig.bone_names(),
			"scale": rig.global_transform.basis.get_scale().x,
			"frames": frames,
		}
		var file := FileAccess.open(_out.path_join("pose.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(out))
		file.close()
	print("capture_croc_jaw_turn: done, %d frames" % int(_seconds * 60.0))
	quit()
