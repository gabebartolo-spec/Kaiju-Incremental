extends SceneTree
## Bakes the title screen colossus (director 2026-10-22: a reptilian silhouette in the inferno) into
## black-on-transparent PNGs, seen from behind and the side (a yaw each), from the game's own adult
## reptilian model (assets/kaiju/reptilian_adult). The title draws them as billboards, so the screen
## builds in no time (building the model took seconds). Local GPU only:
##   godot --path . --windowed --resolution 1280x720 --script tools/capture/bake_colossus.gd -- \
##     --out=assets/title [--yaws=45,90,135] [--pick=2] [--preview=<png>]
## --pick=N saves only pose N, as colossus_0.png (the title uses one pose).
## Writes colossus_0.png .. colossus_N.png (every pose cropped to the same box) and, with
## --preview, a sheet of the poses in colour over a flame-coloured sky so they can be judged.

const SIZE := 2048
## World units the picture spans vertically; the model is 10 units tall.
const SPAN := 26.0
## Height the camera looks at (the model stands on 0 and is 10 tall).
const CENTER_Y := 5.0
const WARMUP := 12
## Seconds of walking between two baked poses, and the speed it walks at (0..1).
const POSE_GAP_S := 0.3
const WALK := 0.8
## The silhouette's pinholes and seams (thin gaps between voxel rows, which the title lights as
## streaks along the jaw) are closed by growing then shrinking the shape by this many pixels.
const CLOSE_RADIUS := 4
## The eye, from the head bones (world units): this far along the skull from the back of the head,
## this far out to the camera's side and this far up.
const EYE_ALONG := 1.3
const EYE_OUT := 0.95
const EYE_UP := -0.3

var _out := "res://assets/title"
var _yaws: Array[float] = [60.0]
var _poses := 1
var _pick := -1
var _preview := ""
## Where the eye is in each pose's picture, as shares of its width and height (printed).
var _eyes: Array[Vector2] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--pick="):
			_pick = int(arg.substr(7))
		elif arg.begins_with("--yaws="):
			_yaws.clear()
			for yaw: String in arg.substr(7).split(","):
				_yaws.append(float(yaw))
			_poses = _yaws.size()
		elif arg.begins_with("--preview="):
			_preview = arg.substr(10)
	_run.call_deferred()


func _run() -> void:
	var species := Content.species_def("reptilian")
	var colors: Dictionary = species["colors"]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var model := KaijuModel.new("reptilian", colors, "adult")
	viewport.add_child(model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = SPAN
	viewport.add_child(camera)
	camera.position = Vector3(0.0, CENTER_Y, 40.0)
	camera.look_at(Vector3(0.0, CENTER_Y, 0.0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30.0, 20.0, 0.0)
	viewport.add_child(light)
	var shots: Array[Image] = []
	var colour: Array[Image] = []
	for _i: int in WARMUP:
		model.animate(1.0 / 60.0, WALK)
		await process_frame
	for pose: int in _poses:
		# The camera orbits the model: yaw 0 is the back view, 90 faces it screen-left, side on.
		var turn := deg_to_rad(_yaws[pose])
		camera.position = Vector3(-sin(turn) * 40.0, CENTER_Y, cos(turn) * 40.0)
		camera.look_at(Vector3(0.0, CENTER_Y, 0.0))
		for _i: int in int(POSE_GAP_S * 60.0):
			model.animate(1.0 / 60.0, WALK)
		await process_frame
		await process_frame
		colour.append(viewport.get_texture().get_image())
		_silhouette(model, true)
		await process_frame
		await process_frame
		shots.append(viewport.get_texture().get_image())
		_silhouette(model, false)
		_eyes.append(_eye_at(model, camera))
		print("pose ", pose, " rect ", shots[pose].get_used_rect())
	var box := Rect2i()
	for shot: Image in shots:
		box = shot.get_used_rect() if box.size == Vector2i.ZERO else box.merge(shot.get_used_rect())
	print("crop ", box)
	for pose: int in _poses:
		var at := (_eyes[pose] - Vector2(box.position)) / Vector2(box.size)
		print("eye pose ", pose, " at (", snappedf(at.x, 0.0001), ", ", snappedf(at.y, 0.0001), ")")
	DirAccess.make_dir_recursive_absolute(_out)
	for pose: int in _poses:
		if _pick >= 0 and pose != _pick:
			continue
		var cut := _close_alpha(shots[pose].get_region(box))
		var name := "colossus_%d.png" % (0 if _pick >= 0 else pose)
		var err := cut.save_png(_out.path_join(name))
		print("saved ", name, " ", err, " ", cut.get_size())
	if _preview != "":
		_sheet(colour, shots, box)
	quit()


## Where the eye is on the picture (pixels): from the head bones, out to the camera's side.
func _eye_at(model: KaijuModel, camera: Camera3D) -> Vector2:
	var rig := model.find_children("*", "KaijuRig", true, false)[0] as KaijuRig
	var back := rig.bone("head0").global_position
	var front := rig.bone("head1").global_position
	var along := (front - back).normalized()
	var to_camera := camera.global_position - front
	var out := Vector3(to_camera.x, 0.0, to_camera.z).normalized()
	var eye := front + along * EYE_ALONG + out * EYE_OUT + Vector3.UP * EYE_UP
	return camera.unproject_position(eye)


## Every mesh of the model black and unlit (or back to its own colours).
func _silhouette(model: Node, on: bool) -> void:
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	for node: Node in model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_override = black if on else null


## The poses side by side over an orange sky: the silhouette above, the lit model below.
func _sheet(colour: Array[Image], shots: Array[Image], box: Rect2i) -> void:
	var width := box.size.x
	var height := box.size.y
	var sheet := Image.create(width * _poses, height * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("c8581c"))
	for pose: int in _poses:
		sheet.blend_rect(shots[pose], box, Vector2i(width * pose, 0))
		sheet.blend_rect(colour[pose], box, Vector2i(width * pose, height))
	for pose: int in _poses:
		for dx: int in range(-6, 7):
			for dy: int in range(-6, 7):
				var dot := Vector2i(_eyes[pose]) - box.position + Vector2i(dx, dy)
				sheet.set_pixelv(dot + Vector2i(width * pose, height), Color("00ff40"))
	sheet.save_png(_preview)


## The picture with its alpha closed: black wherever the shape is, its pinholes filled.
func _close_alpha(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var width := img.get_width()
	var height := img.get_height()
	var data := img.get_data()
	var alpha := PackedByteArray()
	alpha.resize(width * height)
	for i: int in width * height:
		alpha[i] = data[i * 4 + 3]
	alpha = _slide(alpha, width, height, true)
	alpha = _slide(alpha, width, height, false)
	var out := PackedByteArray()
	out.resize(width * height * 4)
	for i: int in width * height:
		out[i * 4 + 3] = alpha[i]
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, out)


## One grow (`grow`) or shrink of the alpha by CLOSE_RADIUS: a max or a min filter, a row pass then
## a column pass.
func _slide(alpha: PackedByteArray, width: int, height: int, grow: bool) -> PackedByteArray:
	var rows := alpha.duplicate()
	for y: int in height:
		for x: int in width:
			var best := 0 if grow else 255
			for k: int in range(-CLOSE_RADIUS, CLOSE_RADIUS + 1):
				var v := alpha[y * width + clampi(x + k, 0, width - 1)]
				best = maxi(best, v) if grow else mini(best, v)
			rows[y * width + x] = best
	var out := rows.duplicate()
	for y: int in height:
		for x: int in width:
			var best := 0 if grow else 255
			for k: int in range(-CLOSE_RADIUS, CLOSE_RADIUS + 1):
				var v := rows[clampi(y + k, 0, height - 1) * width + x]
				best = maxi(best, v) if grow else mini(best, v)
			out[y * width + x] = best
	return out
