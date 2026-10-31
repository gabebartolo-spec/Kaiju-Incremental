class_name GlobeView
extends Node3D
## The campaign's hologram globe of Tellus Nova (D-418; Overworld plan rows G2, G4): a hologram
## shell sphere (globe_hologram.gdshader) and, just outside it, a land sphere that reads the
## landmass mask (globe_land.gdshader). It spins idly; a left-drag turns it (sideways spins, up and
## down tilts) and releasing resumes the spin. The pointer is hit-tested against the same mask: the
## continent under it lights up, and a click that did not drag emits continent_picked and flies
## the camera to it (the globe turns it to the centre, the camera closes in, the spin holds); a
## click on sea or Esc flies back out. Each continent carries a mission marker (GlobeMarker) at
## its anchor, projected to the screen every frame. The globe only presents: each continent wears
## its campaign state (Campaign.states, plan row G3, D-430), read from the save when it opens and
## set again with set_states. A locked continent neither lights up nor answers a click, and its
## marker is grey (D-430).

signal continent_picked(id: String)

const HOLOGRAM := preload("res://scenes/globe_hologram.gdshader")
const LAND := preload("res://scenes/globe_land.gdshader")
const MASK := preload("res://assets/overworld/tellus_nova_mask.png")

const RADIUS := 1.0
const LAND_LIFT := 1.003  # the land sphere's radius over the shell's, so the two never fight
const SEGMENTS := 96
const RINGS := 48
const CAMERA_DISTANCE := 3.4
const ZOOM_DISTANCE := 2.6  # the camera's distance from the centre while a continent is selected
const CAMERA_FOV := 38.0
const START_TILT := 0.3  # rad, the globe leans toward the camera so the north reads
const TILT_LIMIT := 1.1  # rad either way
const IDLE_SPIN := 0.25  # rad/s
const DRAG_RAD_PER_PX := 0.006
const CLICK_SLOP_PX := 6.0  # a press that moves further than this is a drag, not a pick
const FLY_S := 0.7  # the fly-to and fly-out time, eased in and out
## Mask px between candidate anchors; an anchor's 8 neighbours this far away share its value.
const ANCHOR_STEP := 4
## A marker fades over this much of the facing range (dot of the surface normal with the view
## direction) as its anchor turns toward the globe's edge; at or below 0 it is hidden.
const MARKER_FADE := 0.25

## The continent the pointer is over ("" for sea or off the globe).
var hovered := ""
## The continent the camera has flown to ("" when it is out at CAMERA_DISTANCE).
var selected := ""
var yaw := 0.0
var spin := true

var _camera: Camera3D
var _tilt: Node3D
var _globe: Node3D
var _land_mat: ShaderMaterial
var _mask: Image
var _ids: Array[String] = []
var _anchors: Array[Vector3] = []  # per mask value, 0 the sea
var _markers: Array[GlobeMarker] = []  # per continent, in _ids order
var _states := {}  # Campaign.State by id, as set_states last gave them
var _dragging := false
var _drag_px := 0.0
var _fly_from := Vector3.ZERO  # yaw, tilt, camera distance
var _fly_to := Vector3.ZERO
var _fly_t := 1.0  # 1 when no flight is under way


func _ready() -> void:
	_mask = MASK.get_image()
	if _mask.get_format() != Image.FORMAT_L8:
		_mask.convert(Image.FORMAT_L8)
	_anchors = anchors(_mask, Content.continents().size())

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
	_land_mat.set_shader_parameter("locked_tint", UiKit.LOCKED)
	_land_mat.set_shader_parameter("conquered_tint", UiKit.GOOD)
	_land_mat.set_shader_parameter("mask", MASK)
	_globe.add_child(_sphere(RADIUS * LAND_LIFT, _land_mat))
	_add_markers()
	var conquered: Array = SaveFile.load_game().get("conquered", [])
	set_states(Campaign.states(Content.continents(), conquered))


## Each continent's look from its Campaign.State, by id (the shader reads them per mask value).
func set_states(states: Dictionary) -> void:
	var per_value := PackedInt32Array()
	per_value.resize(_ids.size() + 1)
	for n in _ids.size():
		per_value[n + 1] = states.get(_ids[n], Campaign.State.LOCKED)
		_markers[n].set_locked(per_value[n + 1] == Campaign.State.LOCKED)
	_land_mat.set_shader_parameter("states", per_value)
	_states = states


## True for a continent the campaign has not opened yet (and for the sea's "").
func locked(id: String) -> bool:
	return _states.get(id, Campaign.State.LOCKED) == Campaign.State.LOCKED


## One GlobeMarker per continent, on a CanvasLayer above the globe, in Content order.
func _add_markers() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	for def: Dictionary in Content.continents():
		var id: String = def["id"]
		_ids.append(id)
		var marker := GlobeMarker.new(str(def["name"]))
		layer.add_child(marker)
		_markers.append(marker)


func _process(delta: float) -> void:
	if _fly_t < 1.0:
		_fly_t = minf(1.0, _fly_t + delta / FLY_S)
		var now := _fly_from.lerp(_fly_to, smoothstep(0.0, 1.0, _fly_t))
		yaw = now.x
		set_tilt(now.y)
		_camera.position.z = now.z
	elif spin and not _dragging and selected == "":
		yaw += IDLE_SPIN * delta
	_globe.rotation.y = yaw
	_place_markers()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and selected != "":
		fly_out()
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = _fly_t >= 1.0
			_drag_px = 0.0
		elif _dragging:
			_dragging = false
			if _drag_px <= CLICK_SLOP_PX:
				_click(_open_at(button.position))
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	if _dragging:
		_drag_px += motion.relative.length()
		yaw += motion.relative.x * DRAG_RAD_PER_PX
		set_tilt(_tilt.rotation.x + motion.relative.y * DRAG_RAD_PER_PX)
		_globe.rotation.y = yaw
	_set_hovered(_open_at(motion.position))


func tilt() -> float:
	return _tilt.rotation.x


func set_tilt(rad: float) -> void:
	_tilt.rotation.x = clampf(rad, -TILT_LIMIT, TILT_LIMIT)


func camera() -> Camera3D:
	return _camera


func flying() -> bool:
	return _fly_t < 1.0


## Turns the continent to the centre of the screen and closes the camera in, over FLY_S; the idle
## spin holds while it is selected.
func fly_to(id: String) -> void:
	var value := _ids.find(id) + 1
	if value == 0:
		return
	selected = id
	var n := _anchors[value]
	var face_yaw := -atan2(n.x, n.z)
	_fly(
		Vector3(
			yaw + wrapf(face_yaw - yaw, -PI, PI),
			clampf(asin(clampf(n.y, -1.0, 1.0)), -TILT_LIMIT, TILT_LIMIT),
			ZOOM_DISTANCE
		)
	)


## Back out to CAMERA_DISTANCE where the globe stands, over FLY_S; the idle spin resumes.
func fly_out() -> void:
	selected = ""
	_fly(Vector3(yaw, tilt(), CAMERA_DISTANCE))


## The unit-sphere point, in the globe's own frame, a continent's marker stands on (ZERO for an
## unknown id).
func anchor_of(id: String) -> Vector3:
	var value := _ids.find(id) + 1
	return _anchors[value] if value > 0 else Vector3.ZERO


func marker(id: String) -> GlobeMarker:
	var n := _ids.find(id)
	return _markers[n] if n >= 0 else null


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


## The point on the unit sphere at a mask UV, the inverse of uv_of.
static func point_of(uv: Vector2) -> Vector3:
	var lon := uv.x * TAU
	var colat := uv.y * PI
	return Vector3(sin(colat) * sin(lon), cos(colat), sin(colat) * cos(lon))


## The mask's value (0 sea, 1..7 the continents in D-420 order) at a UV, nearest texel.
static func id_at_uv(mask: Image, uv: Vector2) -> int:
	var x := clampi(int(uv.x * mask.get_width()), 0, mask.get_width() - 1)
	var y := clampi(int(uv.y * mask.get_height()), 0, mask.get_height() - 1)
	return roundi(mask.get_pixel(x, y).r * 255.0)


## Each mask value's anchor (index 0 the sea, 1..count the continents) as a unit-sphere point: the
## texel well inside its area (its 8 neighbours ANCHOR_STEP px away share it) nearest the area's
## mean direction, so an island chain's marker still stands on land. One pass over the mask.
static func anchors(mask: Image, count: int) -> Array[Vector3]:
	var w := mask.get_width()
	var h := mask.get_height()
	var px := mask.get_data()
	var means: Array[Vector3] = []
	var cands: Array[Array] = []
	for v in count + 1:
		means.append(Vector3.ZERO)
		cands.append([])
	var s := ANCHOR_STEP
	for y in range(s, h - s, s):
		for x in range(0, w, s):
			var v: int = px[y * w + x]
			if v > count:
				continue
			var p := point_of(_texel_uv(x, y, w, h))
			means[v] += p
			if _inside(px, x, y, w, v):
				cands[v].append(p)
	var out: Array[Vector3] = []
	for v in count + 1:
		out.append(_nearest(cands[v], means[v].normalized()))
	return out


## True when the 8 texels ANCHOR_STEP px round (x, y) all hold v; x wraps, y stays in range.
static func _inside(px: PackedByteArray, x: int, y: int, w: int, v: int) -> bool:
	var s := ANCHOR_STEP
	for dy: int in [-s, 0, s]:
		var row := (y + dy) * w
		for dx: int in [-s, 0, s]:
			if (dx != 0 or dy != 0) and px[row + posmod(x + dx, w)] != v:
				return false
	return true


## The point nearest dir (largest dot), or ZERO when there are none.
static func _nearest(points: Array, dir: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_dot := -2.0
	for p: Vector3 in points:
		if p.dot(dir) > best_dot:
			best_dot = p.dot(dir)
			best = p
	return best


static func _texel_uv(x: int, y: int, w: int, h: int) -> Vector2:
	return Vector2((x + 0.5) / w, (y + 0.5) / h)


## The continent under a screen point, or "" over sea, off the globe or on a locked continent.
func _open_at(screen: Vector2) -> String:
	var id := continent_at(screen)
	return "" if locked(id) else id


func _click(id: String) -> void:
	if id != "":
		continent_picked.emit(id)
		fly_to(id)
	elif selected != "":
		fly_out()


func _fly(target: Vector3) -> void:
	_fly_from = Vector3(yaw, tilt(), _camera.position.z)
	_fly_to = target
	_fly_t = 0.0


## Each marker at its anchor on the screen, faded as the anchor turns toward the globe's edge and
## hidden on the far side.
func _place_markers() -> void:
	_globe.force_update_transform()
	var eye := _camera.global_position
	for n in _markers.size():
		var world := _globe.to_global(_anchors[n + 1] * RADIUS * LAND_LIFT)
		var normal := (world - _globe.global_position).normalized()
		var facing := normal.dot((eye - world).normalized())
		var m := _markers[n]
		m.visible = facing > 0.0
		if m.visible:
			m.position = _camera.unproject_position(world)
			m.modulate.a = smoothstep(0.0, MARKER_FADE, facing)


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
