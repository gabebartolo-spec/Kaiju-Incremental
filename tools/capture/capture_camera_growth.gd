extends SceneTree
## Camera growth candidates (research 19, ROADMAP B): the same seeded run (city seed 0, the
## reptilian, run 0) at a stage's body, with the gameplay camera's "camera" tuning overridden by a
## candidate from tools/capture/camera_candidates.json (no production code reads them); the
## look-ahead is the game's own (camera A, D-121: CameraFollow, tuning "camera" lead_*).
## From the handover tick it saves every frame as JPG to <out>/frames (for the labelled clips),
## a still at --still=<s>, and prints the self-check per frame summarised: the kaiju's share of
## screen height (its drawn box, the sim's kaiju_height x body scale, its highest bone), its feet
## and the ground just in front of them in frame, and the camera inside a standing chunk of a
## building.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_camera_growth.gd -- --candidate=B --stage=3 --mode=rampage \
##     --out=<dir> [--seconds=8] [--still=4]
## --mode=stand: no input (the kaiju stands where it rose); rampage: autoplay. --check-only: the
## self-check alone, no frames saved (runs --headless: the camera and sim are the same).

const CANDIDATES := "res://tools/capture/camera_candidates.json"
const Kit := preload("res://tools/capture/capture_kit.gd")
const SPECIES := "reptilian"
## Ground in front of the feet that must stay in frame (R 2.2): this many body scales toward the
## camera.
const GROUND_AHEAD := 4.0
## Clip frames are JPG at this quality: a 1080p PNG takes ~300 ms to save, and the city keeps
## streaming in on its workers meanwhile (memory grows with wall time); JPG takes ~30 ms.
const JPG_QUALITY := 0.95
## The feet sight line ends this high above the ground (units) and is sampled this often.
const FEET_SIGHT := 0.5
const SIGHT_STEP := 0.5

var _candidate := "A"
var _stage := 1
var _mode := "rampage"
var _out := "user://camera_growth"
var _seconds := 8.0
var _still := 4.0
var _rampage: Rampage
var _camera: Camera3D
var _frames := 0
var _share_sum := 0.0
var _sim_sum := 0.0
var _rig_sum := 0.0
var _share_min := 9.0
var _share_max := 0.0
var _feet_out := 0
var _ground_out := 0
var _inside := 0
var _hidden := 0
var _fall_hidden := 0
var _fall_over := 0
var _top_out := 0
var _centre_out := 0
var _sim_min := 9.0
var _top_min := 9.0
var _head_hidden := 0
## The drawn body's bone boxes (HeadFrame.points), made on the first frame.
var _head: HeadFrame
var _sim_max := 0.0
var _check_only := false
## --no-frames: render at the game's frame timing but save nothing (with --trace).
var _no_frames := false
## --depth-share=<f>: overrides tuning camera.lead_depth_share (a before/after of the lead).
var _depth_share := -1.0
## --trace: one TRACE line per frame (time, sim share, head top, eye distance, lead, offset).
var _trace := false


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate="):
			_candidate = arg.substr(12)
		elif arg.begins_with("--stage="):
			_stage = arg.substr(8).to_int()
		elif arg.begins_with("--mode="):
			_mode = arg.substr(7)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--seconds="):
			_seconds = arg.substr(10).to_float()
		elif arg == "--check-only":
			_check_only = true
		elif arg == "--no-frames":
			_no_frames = true
		elif arg == "--trace":
			_trace = true
		elif arg.begins_with("--depth-share="):
			_depth_share = arg.substr(14).to_float()
		elif arg.begins_with("--still="):
			_still = arg.substr(8).to_float()
	DirAccess.make_dir_recursive_absolute(_out.path_join("frames"))
	_run.call_deferred()


## The candidate's camera block for this stage, written over data/tuning.json "camera".
func _apply_candidate() -> void:
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATES))
	var block: Dictionary = all[_candidate]["stages"][str(_stage)]
	var cam := Content.section("camera")
	for key: String in ["offset", "fov", "zoom_base", "zoom_per_scale"]:
		cam[key] = block[key]
	if _depth_share >= 0.0:
		cam["lead_depth_share"] = _depth_share


func _run() -> void:
	await process_frame
	_apply_candidate()
	var species := Content.species_def(SPECIES)
	var tree := UpgradeTree.new(Content.upgrades(), Kit.STAGE_LEVELS[_stage - 1], SPECIES)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	_rampage = Rampage.new()
	var layout := CityGrowth.layout(Content.tuning(), _stage, Seeds.make("city", 0))
	_rampage.setup(species, stats, layout, 0)
	if _mode == "stand":
		_rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	else:
		_rampage.set_autoplay(true)
	root.add_child(_rampage)
	await _rampage.wait_loaded()
	_camera = _rampage.get_viewport().get_camera_3d()
	while _rampage.sim.emerge.active:
		await physics_frame
	var scale := _rampage.sim.body_scale()
	var zoom := CameraTuning.zoom(scale)
	var off := CameraTuning.offset() * zoom
	var pitch := rad_to_deg(atan2(off.y - 3.5 * scale, off.z))
	print(
		(
			"CAMGROW %s stage %d %s: body %.2f zoom %.3f dist %.1f height %.1f pitch %.1f fov %.0f lead %.1f"
			% [
				_candidate,
				_stage,
				_mode,
				scale,
				zoom,
				off.length(),
				off.y,
				pitch,
				CameraTuning.fov(),
				CameraTuning.lead(scale)
			]
		)
	)
	var frames := int(_seconds * 60.0)
	for frame: int in frames:
		if _check_only:  # the next tick's physics_frame: after this frame's _process (fades, camera)
			await physics_frame
			_check_frame(int(root.get_viewport().get_visible_rect().size.y))
			continue
		await process_frame
		if _no_frames:  # the real render's frame timing, nothing saved
			_check_frame(int(root.get_viewport().get_visible_rect().size.y))
			continue
		await RenderingServer.frame_post_draw
		var image := root.get_viewport().get_texture().get_image()
		image.save_jpg(_out.path_join("frames/f%04d.jpg" % frame), JPG_QUALITY)
		if frame == int(_still * 60.0):
			image.save_png(_out.path_join("still.png"))
		_check_frame(image.get_height())
	var n := maxi(1, _frames)
	var fmt := "CAMCHECK %s stage %d %s: model share mean %.1f%% min %.1f%% max %.1f%%,"
	fmt += " sim height %.1f%% (min %.1f%% max %.1f%%), highest bone %.1f%%;"
	fmt += " highest drawn point %.1f%% from the top, head in the top margin %d,"
	fmt += " centre outside the middle %d;"
	fmt += " feet out %d, ground ahead out %d, camera inside a solid building %d,"
	fmt += " feet hidden behind a solid building %d, body behind a falling section %d (solid %d),"
	fmt += " head behind a solid building or section %d,"
	fmt += " of %d frames"
	var row := [
		_candidate,
		_stage,
		_mode,
		100.0 * _share_sum / n,
		100.0 * _share_min,
		100.0 * _share_max,
		100.0 * _sim_sum / n,
		100.0 * _sim_min,
		100.0 * _sim_max,
		100.0 * _rig_sum / n,
		100.0 * _top_min,
		_top_out,
		_centre_out,
		_feet_out,
		_ground_out,
		_inside,
		_hidden,
		_fall_over,
		_fall_hidden,
		_head_hidden,
		n
	]
	print(fmt % row)
	quit()


func _kaiju() -> KaijuModel:
	return root.find_children("*", "KaijuModel", true, false)[0]


## The self-check for one drawn frame.
func _check_frame(height: int) -> void:
	var kaiju := _kaiju()
	var box := AABB()
	var first := true
	for node: Node in kaiju.find_children("*", "VisualInstance3D", true, false):
		var vis := node as VisualInstance3D
		if not vis.is_visible_in_tree():
			continue
		var b := vis.global_transform * vis.get_aabb()
		box = b if first else box.merge(b)
		first = false
	# The drawn body's ground point (KaijuModel.focus, the root bone): the reptilian's node sits
	# mid-tail, ~5.6 body units behind its hips, so a share measured there swings as it turns.
	var feet := kaiju.focus()
	var top := Vector3(feet.x, box.end.y, feet.z)
	var feet_y := _camera.unproject_position(feet).y
	var top_y := _camera.unproject_position(top).y
	var share := (feet_y - top_y) / height
	_frames += 1
	_share_sum += share
	var tall := feet + Vector3(0, _rampage.sim.reach_height(), 0)
	var top_y2 := _camera.unproject_position(tall).y
	var sim_share := (feet_y - top_y2) / height
	_sim_sum += sim_share
	_sim_min = minf(_sim_min, sim_share)
	_sim_max = maxf(_sim_max, sim_share)
	var cam_cfg := Content.section("camera")
	var skull := tall
	var head_rig: KaijuRig = kaiju.get("_rig")
	if head_rig != null and head_rig.bone_names().has("head0"):
		skull = head_rig.bone("head0").global_position  # the drawn head, ahead of the feet
	var top_px := _drawn_top(kaiju)  # the highest drawn point (the snout), not the sim's column
	_top_min = minf(_top_min, top_px / height)
	if top_px < Num.f(cam_cfg["safe_top"]) * height:
		_top_out += 1  # the head within safe_top of the frame's top (or above it)
	var width := float(root.get_viewport().get_visible_rect().size.x)
	var mid := (_camera.unproject_position(feet) + _camera.unproject_position(skull)) * 0.5
	var margin := (1.0 - Num.f(cam_cfg["safe_centre"])) * 0.5
	if absf(mid.x / width - 0.5) > 0.5 - margin or absf(mid.y / height - 0.5) > 0.5 - margin:
		_centre_out += 1  # the body's middle outside the middle safe_centre of the frame
	if _trace:
		var follow: CameraFollow = _rampage.get("_follow")
		var row := [_frames, sim_share * 100.0, 100.0 * top_px / height, 100.0 * top_y2 / height]
		row += [_camera.global_position.distance_to(feet), follow.lead.x, follow.lead.z]
		row += [follow.offset.length(), follow.offset.y, follow.focus.x - feet.x]
		row += [follow.focus.z - feet.z, feet.x, feet.y, feet.z]
		row += [rad_to_deg(follow.head.tilt) if follow.head != null else 0.0]
		var fmt := "TRACE %d sim %.1f top %.1f column %.1f dist %.2f lead %.2f %.2f off %.2f y %.2f"
		var shake: CameraShake = _rampage.get("shake")
		row += [rad_to_deg(shake.turn(_rampage.sim.body_scale(), PlayerSettings.motion()).y)]
		var back := _camera.global_transform.basis.z
		var cam := [rad_to_deg(atan2(back.x, back.z)), rad_to_deg(asin(back.y))]
		cam += [_camera.global_position.x, _camera.global_position.z]
		var turn := shake.turn(_rampage.sim.body_scale(), PlayerSettings.motion())
		cam += [rad_to_deg(turn.x), rad_to_deg(turn.y)]
		print((fmt + " ff %.2f %.2f feet %.1f %.1f %.1f tilt %.2f shake %.2f") % row)
		print("CAM %d yaw %.3f pitch %.3f at %.2f %.2f shk %.3f %.3f" % ([_frames] + cam))
	var head := feet.y
	var rig: KaijuRig = kaiju.get("_rig")
	if rig != null:
		for bone: String in rig.bone_names():
			head = maxf(head, rig.bone(bone).global_position.y)
	_rig_sum += (feet_y - _camera.unproject_position(Vector3(feet.x, head, feet.z)).y) / height
	_share_min = minf(_share_min, share)
	_share_max = maxf(_share_max, share)
	if feet_y < 0.0 or feet_y > height or _camera.is_position_behind(feet):
		_feet_out += 1
	var ahead := feet + Vector3(0, 0, GROUND_AHEAD * _rampage.sim.body_scale())
	var ahead_y := _camera.unproject_position(ahead).y
	if ahead_y > height or _camera.is_position_behind(ahead):
		_ground_out += 1
	var eye := _camera.global_position
	var opaque := _opaque()
	for b: RampageSim.Building in opaque:
		var c := Vector3i((eye - Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5)).floor())
		if b.frame != null and b.frame.inside(c) and b.frame.alive(c):
			_inside += 1  # the eye in a standing chunk of a building drawn solid
			break
	if _blocked(eye, feet + Vector3(0, FEET_SIGHT, 0), opaque):
		_hidden += 1
	if head_rig != null and head_rig.bone_names().has("head1"):
		var heads := PackedVector3Array([skull, head_rig.bone("head1").global_position])
		var solid_head := _blocked(eye, heads[0], opaque) or _blocked(eye, heads[1], opaque)
		_head_hidden += 1 if solid_head else 0  # the drawn head behind something drawn solid


## The screen y (px) of the highest drawn point of `kaiju` (HeadFrame's bone-box corners), else
## its node.
func _drawn_top(kaiju: KaijuModel) -> float:
	var top := _camera.unproject_position(kaiju.global_position).y
	if _head == null:
		_head = HeadFrame.new(kaiju)
	for corner: Vector3 in _head.points():
		if not _camera.is_position_behind(corner):
			top = minf(top, _camera.unproject_position(corner).y)
	return top


## The buildings drawn solid this frame (BuildingFade's opacity 1): a faded one hides nothing.
func _opaque() -> Array[RampageSim.Building]:
	var city: CityView = _rampage.get("_city")
	var fade: BuildingFade = city.get("_fade")
	var out: Array[RampageSim.Building] = []
	for n: int in _rampage.sim.buildings.size():
		if fade == null or fade.opacity(n) >= 1.0:
			out.append(_rampage.sim.buildings[n])
	return out


## Whether a standing chunk of one of `buildings` lies on the segment from `eye` to `to`
## (sampled every SIGHT_STEP units), so the player cannot see that point.
func _blocked(eye: Vector3, to: Vector3, buildings: Array[RampageSim.Building]) -> bool:
	var lo := Vector2(minf(eye.x, to.x), minf(eye.z, to.z))
	var hi := Vector2(maxf(eye.x, to.x), maxf(eye.z, to.z))
	var steps := ceili(eye.distance_to(to) / SIGHT_STEP)
	for b: RampageSim.Building in buildings:
		if b.frame == null:
			continue
		if b.x + b.w * 0.5 < lo.x or b.x - b.w * 0.5 > hi.x:
			continue
		if b.z + b.d * 0.5 < lo.y or b.z - b.d * 0.5 > hi.y:
			continue
		var corner := Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5)
		for i: int in range(1, steps):
			var c := Vector3i((eye.lerp(to, float(i) / steps) - corner).floor())
			if b.frame.inside(c) and b.frame.alive(c):
				return true
	return false
