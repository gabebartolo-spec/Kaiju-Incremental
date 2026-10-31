class_name GlobeView
extends Node3D
## The campaign's hologram globe of Tellus Nova (D-418; Overworld plan row G2): a hologram shell
## sphere (globe_hologram.gdshader) and, just outside it, a land sphere that reads the landmass
## mask (globe_land.gdshader). It spins idly; a left-drag turns it (sideways spins, up and down
## tilts) and releasing resumes the spin. The pointer is hit-tested against the same mask: the
## continent under it lights up, and a click that did not drag emits continent_picked. The globe
## only presents; which continents are offered is campaign state (D-420), read by later rows.

signal continent_picked(id: String)

const HOLOGRAM := preload("res://scenes/globe_hologram.gdshader")
const LAND := preload("res://scenes/globe_land.gdshader")
const MASK := preload("res://assets/overworld/tellus_nova_mask.png")

const RADIUS := 1.0
const LAND_LIFT := 1.003  # the land sphere's radius over the shell's, so the two never fight
const SEGMENTS := 96
const RINGS := 48
const CAMERA_DISTANCE := 3.4
const CAMERA_FOV := 38.0
const START_TILT := 0.3  # rad, the globe leans toward the camera so the north reads
const TILT_LIMIT := 1.1  # rad either way
const IDLE_SPIN := 0.25  # rad/s
const DRAG_RAD_PER_PX := 0.006
const CLICK_SLOP_PX := 6.0  # a press that moves further than this is a drag, not a pick

## The continent the pointer is over ("" for sea or off the globe).
var hovered := ""
var yaw := 0.0
var spin := true

var _camera: Camera3D
var _tilt: Node3D
var _globe: Node3D
var _land_mat: ShaderMaterial
var _mask: Image
var _ids: Array[String] = []
var _dragging := false
var _drag_px := 0.0


func _ready() -> void:
	_mask = MASK.get_image()
	if _mask.get_format() != Image.FORMAT_L8:
		_mask.convert(Image.FORMAT_L8)
	for def: Dictionary in Content.continents():
		var id: String = def["id"]
		_ids.append(id)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UiKit.BG
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_camera.position = Vector3(0.0, 0.0, CAMERA_DISTANCE)
	add_child(_camera)

	_tilt = Node3D.new()
	_tilt.rotation.x = START_TILT
	add_child(_tilt)
	_globe = Node3D.new()
	_tilt.add_child(_globe)

	var shell := ShaderMaterial.new()
	shell.shader = HOLOGRAM
	shell.set_shader_parameter("tint", UiKit.ACCENT)
	_globe.add_child(_sphere(RADIUS, shell))
	_land_mat = ShaderMaterial.new()
	_land_mat.shader = LAND
	_land_mat.set_shader_parameter("tint", UiKit.ACCENT)
	_land_mat.set_shader_parameter("mask", MASK)
	_globe.add_child(_sphere(RADIUS * LAND_LIFT, _land_mat))


func _process(delta: float) -> void:
	if spin and not _dragging:
		yaw += IDLE_SPIN * delta
	_globe.rotation.y = yaw


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = true
			_drag_px = 0.0
		elif _dragging:
			_dragging = false
			var id := continent_at(button.position)
			if _drag_px <= CLICK_SLOP_PX and id != "":
				continent_picked.emit(id)
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	if _dragging:
		_drag_px += motion.relative.length()
		yaw += motion.relative.x * DRAG_RAD_PER_PX
		set_tilt(_tilt.rotation.x + motion.relative.y * DRAG_RAD_PER_PX)
		_globe.rotation.y = yaw
	_set_hovered(continent_at(motion.position))


func tilt() -> float:
	return _tilt.rotation.x


func set_tilt(rad: float) -> void:
	_tilt.rotation.x = clampf(rad, -TILT_LIMIT, TILT_LIMIT)


func camera() -> Camera3D:
	return _camera


## A point given in the globe's own frame (the frame uv_of reads), in world space as it turns now.
func surface_global(local: Vector3) -> Vector3:
	_globe.force_update_transform()
	return _globe.to_global(local)


## The continent id under a screen point, "" for sea or a point off the globe: the camera ray meets
## the land sphere's near side, the hit turns into the globe's own frame and reads the mask there.
func continent_at(screen: Vector2) -> String:
	_globe.force_update_transform()
	var origin := _camera.project_ray_origin(screen)
	var dir := _camera.project_ray_normal(screen)
	var centre := _globe.global_position
	var r := RADIUS * LAND_LIFT
	var along := (centre - origin).dot(dir)
	var miss := (origin + dir * along - centre).length_squared()
	if miss > r * r:
		return ""
	var hit := origin + dir * (along - sqrt(r * r - miss))
	var local := _globe.global_transform.affine_inverse() * hit
	var value := id_at_uv(_mask, uv_of(local))
	return _ids[value - 1] if value > 0 and value <= _ids.size() else ""


## The mask UV of a point in the globe's own frame, matching SphereMesh's mapping: u turns from +z
## toward +x round the axis, v runs from the north pole (0) to the south (1).
static func uv_of(local: Vector3) -> Vector2:
	var n := local.normalized()
	return Vector2(fposmod(atan2(n.x, n.z) / TAU, 1.0), acos(clampf(n.y, -1.0, 1.0)) / PI)


## The mask's value (0 sea, 1..7 the continents in D-420 order) at a UV, nearest texel.
static func id_at_uv(mask: Image, uv: Vector2) -> int:
	var x := clampi(int(uv.x * mask.get_width()), 0, mask.get_width() - 1)
	var y := clampi(int(uv.y * mask.get_height()), 0, mask.get_height() - 1)
	return roundi(mask.get_pixel(x, y).r * 255.0)


func _set_hovered(id: String) -> void:
	if id == hovered:
		return
	hovered = id
	_land_mat.set_shader_parameter("hover_id", _ids.find(id) + 1)


func _sphere(radius: float, mat: ShaderMaterial) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = SEGMENTS
	sphere.rings = RINGS
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.material_override = mat
	return mesh
