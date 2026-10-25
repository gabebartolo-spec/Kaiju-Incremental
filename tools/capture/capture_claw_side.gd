extends SceneTree
## One side-on clip of the claw swipe's raking arm (docs/claw_swipe_plan.md) for the motion check:
## the young croc rakes once, then the Colossus, each on a plain stage at its run body scale, framed
## to its own size from the raking arm's side, at game speed. 6 s at 60 fps. Needs a window (the
## off-screen no_focus override.cfg) and --write-movie.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/c.avi \
##     --script tools/capture/capture_claw_side.gd

const Kit := preload("res://tools/capture/capture_kit.gd")
const DT := 1.0 / 60.0
## Each stage's shot (frames), the windup cue's frame in it, and the settle before recording.
const SHOT := 180
const WINDUP_AT := 20
const SETTLE := 40
## Camera: vertical fov (deg); its distance and aim (height, and how far toward the snout) as
## shares of the snout tip's height, so each body fills the frame alike.
const FOV := 40.0
const CAM_DIST := 2.6
const AIM_UP := 0.6
const AIM_AHEAD := 0.35
const SHOTS := [["baby", 0.5, "Young croc"], ["adult", 1.3, "Colossus"]]


func _initialize() -> void:
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var empty: Array[Dictionary] = []
	var sim := RampageSim.new({}, Content.tuning(), empty, Seeds.make("army", 0))
	var stage := Node3D.new()
	stage.add_child(CityView.new(sim, Seeds.make("fx", 0), false))
	var cam := Camera3D.new()
	cam.fov = FOV
	stage.add_child(cam)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 48)
	label.position = Vector2(48, 36)
	var hud := CanvasLayer.new()
	hud.add_child(label)
	stage.add_child(hud)
	root.add_child(stage)
	var hit := roundi(Num.f(Content.section("powers")["swipe_windup"]) / DT)
	for shot: Array in SHOTS:
		var colors: Dictionary = Content.species_def("reptilian")["colors"]
		var kaiju := KaijuModel.new("reptilian", colors, str(shot[0]))
		kaiju.scale = Vector3.ONE * Num.f(shot[1])
		stage.add_child(kaiju)
		for i: int in SETTLE:
			kaiju.animate(DT, 0.0)
		var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
		var side := signf(rig.dir_of("arm_r0").x)
		var snout := rig.tail_world("head1") - kaiju.global_position
		var aim := Vector3(0, snout.y * AIM_UP, snout.z * AIM_AHEAD)
		cam.position = aim + Vector3(side * snout.y * CAM_DIST, 0, 0)
		cam.look_at(aim)
		label.text = str(shot[2])
		for f: int in SHOT:
			if f == WINDUP_AT:
				kaiju.tail_sweep(side, "claw_windup")
			if f == WINDUP_AT + hit:
				kaiju.tail_sweep(side, "claw")
			kaiju.animate(DT, 0.0)
			await process_frame
		kaiju.queue_free()
	quit(0)
