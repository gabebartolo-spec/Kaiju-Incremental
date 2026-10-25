extends SceneTree
## One side-on clip of the claw swipe's raking arm (docs/claw_swipe_plan.md) for the motion check:
## the young croc rakes once, then the Colossus, each on a plain stage at its run body scale, framed
## to its own size from the raking arm's side, at game speed. 6 s at 60 fps. Needs a window (the
## off-screen no_focus override.cfg) and --write-movie.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <dir>/c.avi \
##     --script tools/capture/capture_claw_side.gd [-- --still=<dir> --name=<shot>]
## --front: the young croc alone, 4 s, the camera in front of him at chest height looking back.
## --still: no movie; one PNG of the young croc standing at rest (arms in their held pose) instead.
## Both modes print where the near arm shows against the body's side-view silhouette, in px at the
## run's resolution: at rest, the share of the hand and of the forearm's outer half outside it; at
## each rake's hit frame, how far the claw tip is in front of the chest outline, in hand lengths.

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
## _arm_px: points sampled along each part, and the margin (px) a point must clear the outline by.
const SAMPLES := 11
const VOXEL_PX := 2.0
const SHOTS := [["baby", 0.5, "Young croc"], ["adult", 1.3, "Colossus"]]
## --only=<n>: just the first n shots (1: the young croc).
## --front: its shot length (frames), windup frame, the camera's height, the height it looks at and
## its distance in front of the snout (shares of the snout's height).
const FRONT_SHOT := 240
const FRONT_WINDUP := 40
const FRONT_UP := 0.55
const FRONT_LOOK := 0.72
const FRONT_DIST := 1.8

var _still := ""
var _name := "rest"
var _only := 0
var _front := false


func _initialize() -> void:
	var a := Kit.args({"still": "", "name": _name, "only": 0, "front": false})
	_front = a["front"]
	if _front:
		_only = 1
	_only = maxi(_only, Num.i(a["only"]))
	_still = str(a["still"])
	_name = str(a["name"])
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
	for shot: Array in SHOTS.slice(0, _only if _only > 0 else SHOTS.size()):
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
		var shot_frames := SHOT
		var windup_at := WINDUP_AT
		if _front:  # in front of him at chest height, looking back at him
			cam.position = Vector3(0, snout.y * FRONT_UP, snout.z - snout.y * FRONT_DIST)
			aim = Vector3(0, snout.y * FRONT_LOOK, 0)
			shot_frames = FRONT_SHOT
			windup_at = FRONT_WINDUP
		cam.look_at(aim)
		label.text = str(shot[2])
		if _still != "":
			label.text = "%s, %s" % [shot[2], _name]
			for f: int in 30:
				kaiju.animate(DT, 0.0)
				await process_frame
			print(Kit.still(self, _still, _name))
			print("%s at rest: %s" % [shot[2], _arm_px(rig, cam, side)])
			break
		for f: int in shot_frames:
			if f == windup_at:
				kaiju.tail_sweep(side, "claw_windup")
			if f == windup_at + hit:
				kaiju.tail_sweep(side, "claw")
			kaiju.animate(DT, 0.0)
			await process_frame
			if f == windup_at + hit and not _front:
				print("%s at the hit: %s" % [shot[2], _arm_px(rig, cam, side)])
		kaiju.queue_free()
	quit(0)


## The near arm against the body's side-view silhouette (every voxel of the bones that are not arms,
## projected): {"hand_out", "fore_out"} shares of points along the hand and the forearm's outer half
## that fall outside it, and "ahead" (px the claw tip is in front of the chest outline on its row),
## "hand_px" (the hand's length on screen) and "ahead_hands" (ahead / hand_px).
func _arm_px(rig: KaijuRig, cam: Camera3D, side: float) -> Dictionary:
	var rows: Dictionary = {}  # screen row -> Vector2(leftmost, rightmost) of the body
	var points := 0
	for bone_name: String in rig.skins:
		var held: Variant = rig.skins[bone_name]
		if bone_name.begins_with("arm_") or not is_instance_valid(held):
			continue
		var mmi: MultiMeshInstance3D = held
		var mm := mmi.multimesh
		for i: int in mm.instance_count:
			var p := cam.unproject_position(
				mmi.global_transform * mm.get_instance_transform(i).origin
			)
			var row := roundi(p.y)
			points += 1
			var span: Vector2 = rows.get(row, Vector2(INF, -INF))
			rows[row] = Vector2(minf(span.x, p.x), maxf(span.y, p.x))
	var arm := "r" if signf(rig.dir_of("arm_r0").x) == side else "l"
	var fore := "arm_%s1" % arm
	var hand := "arm_%s2" % arm
	var ahead_dir := signf(
		(
			(
				cam.unproject_position(rig.global_position - rig.global_basis.z)
				- cam.unproject_position(rig.global_position)
			)
			. x
		)
	)
	var outside := func(p: Vector2) -> bool:
		var span: Vector2 = rows.get(roundi(p.y), Vector2(INF, -INF))
		return p.x < span.x - VOXEL_PX or p.x > span.y + VOXEL_PX
	var hand_out := 0
	var fore_out := 0
	for k: int in SAMPLES:
		var t := float(k) / (SAMPLES - 1)
		var h0 := rig.bone(hand).global_position
		var f0 := rig.bone(fore).global_position.lerp(rig.tail_world(fore), 0.5)
		hand_out += (
			1 if outside.call(cam.unproject_position(h0.lerp(rig.tail_world(hand), t))) else 0
		)
		fore_out += (
			1 if outside.call(cam.unproject_position(f0.lerp(rig.tail_world(fore), t))) else 0
		)
	var tip := cam.unproject_position(rig.tail_world(hand))
	var hand_px := tip.distance_to(cam.unproject_position(rig.bone(hand).global_position))
	var span: Vector2 = rows.get(roundi(tip.y), Vector2(INF, -INF))
	var edge := span.y if ahead_dir > 0.0 else span.x
	var ahead := (tip.x - edge) * ahead_dir if is_finite(edge) else INF
	return {
		"hand_out": snappedf(float(hand_out) / SAMPLES, 0.01),
		"fore_out": snappedf(float(fore_out) / SAMPLES, 0.01),
		"ahead_px": snappedf(ahead, 0.1),
		"hand_px": snappedf(hand_px, 0.1),
		"ahead_hands": snappedf(ahead / maxf(hand_px, 0.001), 0.01),
		"body_points": points,
	}
