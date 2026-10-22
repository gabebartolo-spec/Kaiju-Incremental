class_name TitleShore
extends Node3D
## The far shore's embankment for the title screen (#99): a stone sea wall with a lit promenade and
## a row of street lamps along the whole shore, so the towers stand on a visible edge instead of
## fading into the bay, and the fires' and windows' reflections streaking the water below it.
## Presentation only; numbers in tuning "title" "shore". The far shore's buildings start 12 m
## back from its edge (CitySkyline), so the wall and the promenade have the strip in front.

const REFLECT := preload("res://scenes/title_shore.gdshader")
## The wall's face is at the shore line; the strip behind it is the promenade (m).
const PROMENADE := 9.0
const WATER_Y := -0.8
const MAX_FIRES := 12

var _cfg: Dictionary
var _shore_z: float
var _cam: Vector3
var _fires: PackedFloat32Array
var _coast_z: float
var _water: ShaderMaterial
var _ripple: Dictionary


## places: "shore_z" (the far shore's edge, world z), "coast_z" (the play area's quay, where the
## near ledge starts), "cam" (where the title's camera stands) and "fires" (the x of each burning
## tower, for their reflections).
func _init(cfg: Dictionary, places: Dictionary) -> void:
	_cfg = cfg
	_ripple = places["ripple"]
	_shore_z = Num.f(places["shore_z"])
	_coast_z = Num.f(places["coast_z"])
	_cam = places["cam"]
	_fires = places["fires"]


func _ready() -> void:
	var span := Num.f(_cfg["half_span"])
	var top := Num.f(_cfg["wall_top"])
	var wall := _box(
		Vector3(span * 2.0, top - WATER_Y, 1.4),
		Vector3(0.0, (top + WATER_Y) / 2.0, _shore_z - 0.7),
		_lit_material(Color(str(_cfg["wall_color"])), Color(str(_cfg["wall_glow"])), 0.0)
	)
	add_child(wall)
	var cap_h := Num.f(_cfg["cap_height"])
	add_child(
		_box(
			Vector3(span * 2.0, cap_h, 2.0),
			Vector3(0.0, top + cap_h / 2.0, _shore_z - 1.0),
			_lit_material(
				Color(str(_cfg["cap_color"])),
				Color(str(_cfg["promenade_glow"])),
				Num.f(_cfg["promenade_energy"])
			)
		)
	)
	add_child(
		_box(
			Vector3(span * 2.0, 0.3, PROMENADE),
			Vector3(0.0, top + 0.15, _shore_z - 2.0 - PROMENADE / 2.0),
			_lit_material(
				Color(str(_cfg["promenade_color"])),
				Color(str(_cfg["promenade_glow"])),
				Num.f(_cfg["promenade_energy"])
			)
		)
	)
	_lamps(span, top)
	_reflections(span)
	_ledge(span)


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _lit_material(color: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = energy
	return mat


## Lamp posts along the promenade, each with a warm glow at its head.
func _lamps(span: float, top: float) -> void:
	var gap := Num.f(_cfg["lamp_gap"])
	var height := Num.f(_cfg["lamp_height"])
	var count := int(span * 2.0 / gap)
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	var post := BoxMesh.new()
	post.size = Vector3(0.3, height, 0.3)
	post.material = _lit_material(Color("1a1a20"), Color.BLACK, 0.0)
	posts.mesh = post
	posts.instance_count = count
	var heads := MultiMesh.new()
	heads.transform_format = MultiMesh.TRANSFORM_3D
	var glow := QuadMesh.new()
	glow.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	mat.albedo_texture = FarFire.soft_disc()
	mat.albedo_color = Color(str(_cfg["lamp_color"]))
	glow.material = mat
	heads.mesh = glow
	heads.instance_count = count
	for i: int in count:
		var x := -span + (i + 0.5) * gap
		var z := _shore_z - Num.f(_cfg["lamp_back"])
		var y := top + 0.3 + height / 2.0
		posts.set_instance_transform(i, Transform3D(Basis(), Vector3(x, y, z)))
		var head := Transform3D(
			Basis.from_scale(Vector3.ONE * Num.f(_cfg["lamp_glow"])),
			Vector3(x, top + 0.3 + height, z)
		)
		heads.set_instance_transform(i, head)
	for mm: MultiMesh in [posts, heads]:
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


## The play area's embankment along the bottom of the picture: a stone ledge out past the quay,
## its top a little above the water and its edge lit, so the view stands on a shore too.
func _ledge(span: float) -> void:
	var from := Num.f(_cfg["ledge_from"])
	var depth := Num.f(_cfg["ledge_depth"])
	var top := Num.f(_cfg["ledge_top"])
	var z := _coast_z - from - depth / 2.0
	var body := Vector3(span * 2.0, top - WATER_Y, depth)
	var mid_y := (top + WATER_Y) / 2.0
	var stone := _lit_material(Color(str(_cfg["ledge_color"])), Color.BLACK, 0.0)
	add_child(_box(body, Vector3(0.0, mid_y, z), stone))
	var cap := _lit_material(
		Color(str(_cfg["ledge_cap"])), Color(str(_cfg["promenade_glow"])), Num.f(_cfg["ledge_glow"])
	)
	var cap_at := Vector3(0.0, top + 0.12, _coast_z - from - depth + 0.7)
	add_child(_box(Vector3(span * 2.0, 0.25, 1.4), cap_at, cap))


## How far the water is shivering (0 still .. 1 a footstep has just landed).
func set_shiver(amount: float) -> void:
	if _water != null:
		_water.set_shader_parameter("shiver", amount)


## The reflections: one sheet over the water from the shore toward the camera.
func _reflections(span: float) -> void:
	var length := Num.f(_cfg["reflect_length"])
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(span * 2.0, length)
	var mat := ShaderMaterial.new()
	mat.shader = REFLECT
	mat.set_shader_parameter("shore_z", _shore_z)
	mat.set_shader_parameter("cam_pos", _cam)
	mat.set_shader_parameter("window_colour", Color(str(_cfg["window_reflect"])))
	mat.set_shader_parameter("fire_colour", Color(str(_cfg["fire_reflect"])))
	mat.set_shader_parameter("window_strength", Num.f(_cfg["window_strength"]))
	mat.set_shader_parameter("fire_strength", Num.f(_cfg["fire_strength"]))
	mat.set_shader_parameter("window_length", Num.f(_cfg["window_length"]))
	mat.set_shader_parameter("fire_length", Num.f(_cfg["fire_length"]))
	mat.set_shader_parameter("fire_radius", Num.f(_cfg["fire_radius"]))
	mat.set_shader_parameter("ripple_amp", Num.f(_ripple["amplitude"]))
	mat.set_shader_parameter("ripple_glow", Num.f(_ripple["glow"]))
	_water = mat
	var xs := PackedFloat32Array(_fires)
	var count := mini(xs.size(), MAX_FIRES)
	xs.resize(MAX_FIRES)
	mat.set_shader_parameter("fire_x", xs)
	mat.set_shader_parameter("fire_count", count)
	mesh.material = mat
	var sheet := MeshInstance3D.new()
	sheet.mesh = mesh
	sheet.position = Vector3(0.0, WATER_Y + 0.04, _shore_z + length / 2.0)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
