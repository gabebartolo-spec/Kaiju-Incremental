extends SceneTree
## Writes the young croc's skin poses frame by frame through its idle, walk and claw swipes (both
## arms), for tools/kaiju_skin/slit_scan.py, which looks for slits in the skin:
##   godot --headless --path . --script tools/kaiju_skin/dump_poses.gd -- <out.json> [stage] [scale]
## Per frame: a tag (idle, walk, swipe_r, swipe_l) and every bone's VoxelSkin.pose matrix (rig
## units, 16 numbers, column-major) in rig.json order.

const DT := 1.0 / 60.0
const WARM := 40
const IDLE := 90
const WALK := 150
const SETTLE := 40
const SWIPE := 110


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var stage := args[1] if args.size() > 1 else "baby"
	var body_scale := float(args[2]) if args.size() > 2 else 0.5
	var colors: Dictionary = Content.species_def("reptilian")["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	kaiju.scale = Vector3.ONE * body_scale
	root.add_child(kaiju)
	var skin: VoxelSkin = kaiju.find_children("*", "VoxelSkin", true, false)[0]
	var hit := roundi(Num.f(Content.section("powers")["swipe_windup"]) / DT)
	var frames: Array = []
	for i: int in WARM:
		kaiju.animate(DT, 0.0)
	for i: int in IDLE:
		kaiju.animate(DT, 0.0)
		frames.append(_frame("idle", skin))
	var step := Vector3.FORWARD * Num.f(Content.section("kaiju")["speed"]) * DT  # the sim's pace
	for i: int in WALK:
		kaiju.position += step
		kaiju.animate(DT, 1.0)
		frames.append(_frame("walk", skin))
	for side: float in [1.0, -1.0]:
		for i: int in SETTLE:
			kaiju.animate(DT, 0.0)
		kaiju.tail_sweep(side, "claw_windup")
		for i: int in SWIPE:
			if i == hit:
				kaiju.tail_sweep(side, "claw")
			kaiju.animate(DT, 0.0)
			frames.append(_frame("swipe_r" if side > 0.0 else "swipe_l", skin))
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string(JSON.stringify({"stage": stage, "frames": frames}))
	f.close()
	print("dumped %d frames" % frames.size())
	quit(0)


func _frame(tag: String, skin: VoxelSkin) -> Dictionary:
	var m: Array = []
	for p: Projection in skin.pose:
		for c: Vector4 in [p.x, p.y, p.z, p.w]:
			m.append_array([c.x, c.y, c.z, c.w])
	return {"tag": tag, "m": m}
