extends SceneTree
## The Behemoth (the croc's middle stage) on the adult skeleton playing the Colossus's takes
## (D-484), in its own city at the game camera: it walks north long enough for the walk to blend
## into the run, lashes on the signature button (--lash=S, seconds after the rise, comma list),
## stands, and sweeps its tail (the tail stat on, so the automatic sweep plays). Prints each clip
## state change ("TAKE t <state> <layer>"), for cutting the clip.
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --write-movie <dir>/b.avi --script tools/capture/capture_behemoth_takes.gd \
##     -- --seconds=22 [--walk=12] [--lash=4,9]

const Kit := preload("res://tools/capture/capture_kit.gd")
const BEHEMOTH_LEVELS := 1  ## Kit.STAGE_LEVELS: the Behemoth
const BEHEMOTH_TIER := 2  ## its city (CityGrowth size tier)

var _seconds := 22.0
var _walk := 12.0
var _lash: Array[float] = [4.0, 9.0]


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"seconds": _seconds, "walk": _walk, "lash": "4,9"})
	_seconds = Num.f(a["seconds"])
	_walk = Num.f(a["walk"])
	_lash.clear()
	for s: String in str(a["lash"]).split(",", false):
		_lash.append(float(s))
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Content.set_time("dusk")  # D-359
	var levels: Dictionary = Kit.STAGE_LEVELS[BEHEMOTH_LEVELS].duplicate()
	levels["tail"] = 1  # the automatic tail sweep needs the tail stat
	var layout := CityGrowth.layout(Content.tuning(), BEHEMOTH_TIER, Seeds.make("city", 0))
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", levels), 1, layout)
	var risen: Array[float] = []
	var walk := _walk
	var lash := _lash
	rampage.scripted = func(sim: RampageSim) -> Dictionary:
		if risen.is_empty() and not sim.emerge.active:
			risen.append(sim.elapsed)
		if risen.is_empty():
			return {}
		var t := sim.elapsed - risen[0]
		var press := false
		for at: float in lash:
			press = press or (t >= at and t < at + 0.05)
		return {"move": Vector2(0, -1) if t < walk else Vector2.ZERO, "signature": press}
	root.add_child(rampage)
	await rampage.wait_loaded()
	var aim: Node3D = rampage.find_child("BreathAim", false, false)
	if aim != null:  # the breath's aim wedge is a game aid, not part of the shot
		aim.set_physics_process(false)
		aim.visible = false
	while rampage.sim.emerge.active:
		await process_frame
	var gait: ClipGait = rampage._kaiju._rig.gait
	print(
		(
			"capture_behemoth_takes: risen at frame %d, %d bones, keyed lash %s, window %s"
			% [
				Engine.get_process_frames(),
				gait.rig.bone_names().size(),
				gait.clips.has_clip("lash_r"),
				root.get_visible_rect().size
			]
		)
	)
	var start := Engine.get_process_frames()
	var was := ""
	while Engine.get_process_frames() - start < int(_seconds * 60.0):
		await process_frame
		var now := "%s %s" % [gait.state, gait.lash.clip if gait.lash != null else ""]
		var frame := Engine.get_process_frames() - start
		if now != was:
			print("TAKE %.2f %s" % [float(frame) / 60.0, now])
			was = now
		if frame % 30 == 0:
			_log_frame(rampage, gait, frame)
	quit()


## Every half second: the croc's snout, pelvis, tail tip and toes, and the camera (eye, turn in
## degrees, fov), so a shot's framing is checked from the logged positions before filming.
func _log_frame(rampage: Rampage, gait: ClipGait, frame: int) -> void:
	var rig := gait.rig
	var pts: Array[String] = []
	for b: String in ["head1", "spine0", "tail11", "leg_l3", "leg_r3"]:
		var p := rig.tail_world(b)
		pts.append("%.2f,%.2f,%.2f" % [p.x, p.y, p.z])
	var cam := rampage._camera
	var e := cam.global_position
	var r := cam.global_rotation_degrees
	print(
		(
			"POS f=%d pts=%s eye=%.2f,%.2f,%.2f,%.1f,%.1f,%.1f fov=%.1f"
			% [frame, ";".join(pts), e.x, e.y, e.z, r.x, r.y, r.z, cam.fov]
		)
	)
