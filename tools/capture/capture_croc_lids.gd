extends SceneTree
## The croc at one stage standing in a real rampage at the game camera, with its lower lids shut: each
## lid_lo bone turned `--open` degrees about its lid axis (tools/kaiju_skin/lid_flaps.py: n = the bone's
## head->tail, up = rig up made square to n, axis = n x up; a positive turn carries n towards up), the
## pose a blink closes to (D-190). Saves a 1080p still and a 2x crop round the head. No input: the sim's
## own stomps and rakes play on.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_croc_lids.gd -- --out=<dir> --stage=2 --open=100 [--seconds=3]

const Kit := preload("res://tools/capture/capture_kit.gd")
const LIDS: Array[String] = ["lid_lo_l", "lid_lo_r"]
const CROP := Vector2i(560, 420)
const HEAD_BONE := "head1"

var _out := "user://croc_lids"
var _stage := 2
var _open := 100.0
var _seconds := 3.0


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"out": _out, "stage": _stage, "open": _open, "seconds": _seconds})
	_out = str(a["out"])
	_stage = Num.i(a["stage"])
	_open = Num.f(a["open"])
	_seconds = Num.f(a["seconds"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var levels: Dictionary = Kit.STAGE_LEVELS[_stage]
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", levels), 1)
	root.add_child(rampage)
	await rampage.wait_loaded()
	var aim: Node3D = rampage.find_child("BreathAim", false, false)
	if aim != null:  # the breath's aim wedge is a game aid, not part of the shot
		aim.set_physics_process(false)
		aim.visible = false
	while rampage.sim.emerge.active:
		await process_frame
	var rig: KaijuRig = rampage._kaiju._rig
	var shut := {}
	for lid in LIDS:
		if not rig.has_bone(lid):
			push_error("capture_croc_lids: no %s bone at stage %d" % [lid, _stage])
			quit(1)
			return
		shut[lid] = Basis(_lid_axis(rig, lid), deg_to_rad(_open))
	var hold := LidHold.new()
	hold.rig = rig
	hold.shut = shut
	root.add_child(hold)
	await Kit.frames(self, int(_seconds * 60.0))
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join("lids_shut_stage%d.png" % _stage))
	var at := rig.bone(HEAD_BONE).global_position if rig.has_bone(HEAD_BONE) else rig.global_position
	var centre := Kit.image_point(self, rampage._camera, at, Vector2(img.get_size()))
	Kit.crop_2x(img, centre, CROP, _out.path_join("lids_shut_stage%d_2x.png" % _stage))
	print("capture_croc_lids: stage %d, lids shut %.0f deg, saved" % [_stage, _open])
	quit()


## Holds the lids shut after everything else has posed the rig this frame (the clip player sets
## every bone, lids included, so the hold runs last: the highest process priority).
class LidHold:
	extends Node
	var rig: KaijuRig
	var shut: Dictionary = {}

	func _ready() -> void:
		process_priority = 1 << 20

	func _process(_delta: float) -> void:
		for lid: String in shut:
			var turn: Basis = shut[lid]
			rig.pose_basis(lid, turn)


## The lid's closing axis in the bone's own rest space (its rest basis composed up to the rig root).
func _lid_axis(rig: KaijuRig, lid: String) -> Vector3:
	var b := Basis.IDENTITY
	var bone_name := lid
	while bone_name != "":
		b = rig.rest_of(bone_name).basis * b
		bone_name = rig.parent_of(bone_name)
	var inv := b.orthonormalized().inverse()
	var n := rig.dir_of(lid).normalized()
	var up := inv * Vector3.UP
	up = (up - n * n.dot(up)).normalized()
	return n.cross(up).normalized()
