extends SceneTree
## The adult croc (Colossus) standing still in a real autoplay-less rampage at the game camera, HUD
## on: no input, so the sim's own stomps (every 0.7 s) and tail sweeps (every 2 s, D-459) are all
## that happens. Prints when the rise from the river ends (the frame to cut a clip from), and with
## --shots saves a still of the first stomps that plant a foot,
## each with a 2x crop round the croc. Needs a window; pair with --write-movie for a clip.
## --walk=S: he first walks north for S seconds of the rampage, then stands (walking, then
## stomping, in one clip). --stand=S: he stands S seconds after the rise before that walk.
## --feet: a line per frame of the walk (state, clip frame, speed, each foot down and where).
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/c.avi \
##     --script tools/capture/capture_croc_standing.gd -- --out=<dir> --seconds=8 [--shots] \
##     [--walk=3]

const Kit := preload("res://tools/capture/capture_kit.gd")
const ADULT_LEVELS := 2  ## Kit.STAGE_LEVELS: the Colossus
const CROP := Vector2i(560, 420)
## Frames after a stomp lands that its still is taken: the ring and cracks have opened.
const STOMP_SHOT_DELAY := 5
const LOG_MOVE := 0.05  ## world units a frame, --log
const LOG_DIP := 0.05
const STOMP_SHOTS := 3  ## stills of this many stomps

var _out := "user://croc_standing"
var _seconds := 8.0
var _shots := false
var _log := false
var _walk := 0.0
var _stand := 0.0
var _feet := false
var _last_cam := Vector3.ZERO


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args(
		{
			"out": _out,
			"seconds": _seconds,
			"shots": false,
			"log": false,
			"walk": _walk,
			"stand": _stand,
			"feet": false
		}
	)
	_out = str(a["out"])
	_seconds = Num.f(a["seconds"])
	_shots = a["shots"]
	_log = a["log"]
	_walk = Num.f(a["walk"])
	_stand = Num.f(a["stand"])
	_feet = a["feet"]
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var levels: Dictionary = Kit.STAGE_LEVELS[ADULT_LEVELS]
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", levels), 1)
	var walk := _walk
	var stand := _stand
	var risen: Array[float] = []  # sim time the rise ended: --stand counts from there
	rampage.scripted = func(sim: RampageSim) -> Dictionary:
		if risen.is_empty() and not sim.emerge.active:
			risen.append(sim.elapsed)
		var from := 0.0
		if stand > 0.0:
			from = risen[0] + stand if not risen.is_empty() else INF
		var on := sim.elapsed >= from and sim.elapsed < from + walk
		return {"move": Vector2(0, -1)} if on else {}
	root.add_child(rampage)
	await rampage.wait_loaded()
	var aim: Node3D = rampage.find_child("BreathAim", false, false)
	if aim != null:  # the breath's aim wedge is a game aid, not part of the shot
		aim.set_physics_process(false)
		aim.visible = false
	while rampage.sim.emerge.active:
		await process_frame
	print("capture_croc_standing: emerged at frame %d" % Engine.get_process_frames())
	var start := Engine.get_process_frames()
	var gait: ClipGait = rampage._kaiju._rig.gait
	var stomps := 0
	var wait := -1  # frames before the latest stomp's still: the ring has opened by then
	while Engine.get_process_frames() - start < int(_seconds * 60.0):
		await process_frame
		if _feet:
			_log_feet(rampage, gait, Engine.get_process_frames() - start)
		if _log:
			_log_camera(rampage, float(Engine.get_process_frames() - start) / 60.0)
		if not _shots:
			continue
		wait -= 1
		if wait == 0:
			_snap(rampage, "stomp_%d" % stomps, rampage.stomp_ring_at[-1])
		if rampage.stomp_ring_at.size() > stomps:
			stomps = rampage.stomp_ring_at.size()
			if _log:
				print("stomp %d landed: %d street rings alive" % [stomps, _rings(rampage)])
			wait = STOMP_SHOT_DELAY if stomps <= STOMP_SHOTS else -1
	print("capture_croc_standing: stomps landed on a foot %d" % stomps)
	quit()


func _snap(rampage: Rampage, shot_name: String, at: Vector3) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(shot_name + ".png"))
	var centre := Kit.image_point(self, rampage._camera, at, Vector2(img.get_size()))
	Kit.crop_2x(img, centre, CROP, _out.path_join(shot_name + "_2x.png"))


## --log: a line per frame the camera moves a pixel or more, or a dip or shake is on, with the
## stomp count, to tie a jump on screen to its source (footfall dip, shake).
func _log_camera(rampage: Rampage, at: float) -> void:
	var cam := rampage._camera
	var moved := cam.global_position.distance_to(_last_cam)
	_last_cam = cam.global_position
	if moved > LOG_MOVE or rampage._step_dip > LOG_DIP or rampage.shake.trauma > LOG_DIP:
		var line := "t=%.2f cam_moved=%.3f " % [at, moved]
		line += "dip=%.3f trauma=%.3f" % [rampage._step_dip, rampage.shake.trauma]
		print(line, " stomps=%d" % rampage.stomp_ring_at.size())


## --feet: one line a frame: state, clip frame, speed, then each foot (1 down, 0 up) and its spot.
func _log_feet(rampage: Rampage, gait: ClipGait, frame: int) -> void:
	var line := (
		"feet f=%d %s ct=%.1f v=%.2f ph=%.2f"
		% [frame, gait.state, gait.clip_time, gait.speed, gait.step_phase]
	)
	for leg: BipedLeg in gait.legs.slice(0, 2):
		var at := gait.rig.tail_world(leg.tip)
		line += " | %d %.2f %.2f %.2f" % [int(leg.planted), at.x, at.y, at.z]
	var body := gait.rig.global_position
	var sim := rampage.sim
	line += " | body %.2f %.2f stride %.2f" % [body.x, body.z, gait.stride()]
	var at := sim.kaiju_pos
	var sf: Array = sim.body._feet
	var hd: Vector2 = sim.body.heading
	var tail := " | sim %.3f %.2f %.2f %.2f" % [sim.body.stride, sim.stat("speed"), at.x, at.y]
	tail += " | sfeet %.1f %.1f  %.1f %.1f" % [sf[0].x, sf[0].y, sf[1].x, sf[1].y]
	print(line, tail, " | hd %.2f %.2f" % [hd.x, hd.y])


## Street rings (Fx.shockwave planes) alive now.
func _rings(rampage: Rampage) -> int:
	var count := 0
	for node: Node in rampage._city.fx.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is PlaneMesh:
			count += 1
	return count
