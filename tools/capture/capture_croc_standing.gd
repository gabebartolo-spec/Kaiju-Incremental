extends SceneTree
## The adult croc (Colossus) standing still in a real autoplay-less rampage at the game camera, HUD
## on: no input, so the sim's own stomps (every 0.7 s) and claw rakes (every 2 s) are all that
## happens. Prints when the rise from the river ends (the frame to cut a clip from), and with
## --shots saves a still of the first stomp that plants a foot and of the first rake mid-swing,
## each with a 2x crop round the croc. Needs a window; pair with --write-movie for a clip.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/c.avi \
##     --script tools/capture/capture_croc_standing.gd -- --out=<dir> --seconds=8 [--shots]

const Kit := preload("res://tools/capture/capture_kit.gd")
const ADULT_LEVELS := 2  ## Kit.STAGE_LEVELS: the Colossus
const CROP := Vector2i(560, 420)
## Seconds into a rake (BipedSwing._rake_t) where the arm is across the front: shot mid-swing.
const RAKE_MID := 0.33
## ... and where it is lifted up and out wide of the body (the arm shows beside the chest).
const RAKE_LIFT := 0.2
## Frames after a stomp lands that its still is taken: the ring and cracks have opened.
const STOMP_SHOT_DELAY := 5
const LOG_MOVE := 0.05  ## world units a frame, --log
const LOG_DIP := 0.05
const STOMP_SHOTS := 3  ## stills of this many stomps

var _out := "user://croc_standing"
var _seconds := 8.0
var _shots := false
var _log := false
var _last_cam := Vector3.ZERO


func _initialize() -> void:
	var a := Kit.args({"out": _out, "seconds": _seconds, "shots": false, "log": false})
	_out = str(a["out"])
	_seconds = Num.f(a["seconds"])
	_shots = a["shots"]
	_log = a["log"]
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var levels: Dictionary = Kit.STAGE_LEVELS[ADULT_LEVELS]
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", levels), 1)
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	root.add_child(rampage)
	await rampage.wait_loaded()
	while rampage.sim.emerge.active:
		await process_frame
	print("capture_croc_standing: emerged at frame %d" % Engine.get_process_frames())
	var start := Engine.get_process_frames()
	var gait: ClipGait = rampage._kaiju._rig.gait
	var stomps := 0
	var raked := false
	var lifted := false
	var wait := -1  # frames before the latest stomp's still: the ring has opened by then
	while Engine.get_process_frames() - start < int(_seconds * 60.0):
		await process_frame
		if _log:
			_log_camera(rampage, gait, float(Engine.get_process_frames() - start) / 60.0)
		if not _shots:
			continue
		wait -= 1
		if wait == 0:
			_snap(rampage, "stomp_%d" % stomps, rampage.stomp_ring_at[-1])
		if rampage.stomp_ring_at.size() > stomps:
			stomps = rampage.stomp_ring_at.size()
			wait = STOMP_SHOT_DELAY if stomps <= STOMP_SHOTS else -1
		var rake_t := gait.swing._rake_t
		var arms := gait.rig.bone("arm_l0").global_position
		arms = (arms + gait.rig.bone("arm_r0").global_position) * 0.5
		if not lifted and rake_t > RAKE_LIFT and rake_t < RAKE_MID:
			lifted = true
			_snap(rampage, "rake_lift", arms)
		if not raked and rake_t > RAKE_MID:
			raked = true
			_snap(rampage, "rake_across", arms)
	print("capture_croc_standing: stomps landed on a foot %d, rake shot %s" % [stomps, raked])
	quit()


func _snap(rampage: Rampage, shot_name: String, at: Vector3) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(shot_name + ".png"))
	var centre := Kit.image_point(self, rampage._camera, at, Vector2(img.get_size()))
	Kit.crop_2x(img, centre, CROP, _out.path_join(shot_name + "_2x.png"))


## --log: a line per frame the camera moves a pixel or more, or a dip or shake is on, with the
## rake's clock, to tie a jump on screen to its source (footfall dip, shake, rake).
func _log_camera(rampage: Rampage, gait: ClipGait, at: float) -> void:
	var cam := rampage._camera
	var moved := cam.global_position.distance_to(_last_cam)
	_last_cam = cam.global_position
	if moved > LOG_MOVE or rampage._step_dip > LOG_DIP or rampage.shake.trauma > LOG_DIP:
		var line := "t=%.2f cam_moved=%.3f " % [at, moved]
		line += "dip=%.3f trauma=%.3f" % [rampage._step_dip, rampage.shake.trauma]
		print(line, " rake_t=%.2f stomps=%d" % [gait.swing._rake_t, rampage.stomp_ring_at.size()])
