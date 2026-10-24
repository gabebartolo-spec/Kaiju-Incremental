class_name TitleShore
extends Node3D
## The far shore's embankment for the title screen (#99): a stone sea wall with a lit promenade and
## a row of street lamps along the whole shore, so the towers stand on a visible edge instead of
## fading into the bay, and the fires' and windows' reflections streaking the water below it.
## Presentation only; numbers in tuning "title" "shore". The far shore's buildings start 12 m
## back from its edge (CitySkyline), so the wall and the promenade have the strip in front.

const REFLECT := preload("res://scenes/title_shore.gdshader")
const LEDGE := preload("res://scenes/title_ledge.gdshader")
## The wall's face is at the shore line; the strip behind it is the promenade (m).
const PROMENADE := 9.0
const WATER_Y := -0.8
const MAX_FIRES := 12
## Lamp posts stand this far back from the ledge's lip (m).
const POST_BACK := 2.4

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


## Lamp posts along the promenade, each with a warm glow at its head: spaced unevenly, a few of
## them dead (tuning "lamp_jitter", "lamp_out"), so the row is not a string of identical discs.
func _lamps(span: float, top: float) -> void:
	var height := Num.f(_cfg["lamp_height"])
	var spots := _lamp_spots(span)
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	var post := BoxMesh.new()
	post.size = Vector3(0.3, height, 0.3)
	post.material = _lit_material(Color("1a1a20"), Color.BLACK, 0.0)
	posts.mesh = post
	posts.instance_count = spots.size()
	var heads := MultiMesh.new()
	heads.transform_format = MultiMesh.TRANSFORM_3D
	heads.mesh = _glow_quad(Color(str(_cfg["lamp_color"])))
	heads.instance_count = spots.size()
	var z := _shore_z - Num.f(_cfg["lamp_back"])
	for i: int in spots.size():
		var x := spots[i].x
		posts.set_instance_transform(
			i, Transform3D(Basis(), Vector3(x, top + 0.3 + height / 2.0, z))
		)
		var head_size := Vector3.ONE * Num.f(_cfg["lamp_glow"]) * spots[i].y
		heads.set_instance_transform(
			i, Transform3D(Basis.from_scale(head_size), Vector3(x, top + 0.3 + height, z))
		)
	for mm: MultiMesh in [posts, heads]:
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


## Where the lamps stand: x along the promenade and a glow scale, some positions dropped.
func _lamp_spots(span: float) -> Array[Vector2]:
	var gap := Num.f(_cfg["lamp_gap"])
	var rng := Seeds.make("title_lamps", 0)
	var spots: Array[Vector2] = []
	for i: int in int(span * 2.0 / gap):
		if rng.randf() < Num.f(_cfg["lamp_out"]):
			continue
		var wander := rng.randf_range(-1.0, 1.0) * Num.f(_cfg["lamp_jitter"])
		spots.append(Vector2(-span + (i + 0.5 + wander) * gap, rng.randf_range(0.75, 1.15)))
	return spots


## The play area's embankment along the bottom of the picture: a stone ledge out past the quay,
## its top a little above the water and its edge lit, so the view stands on a shore too.
func _ledge(span: float) -> void:
	var from := Num.f(_cfg["ledge_from"])
	var depth := Num.f(_cfg["ledge_depth"])
	var top := Num.f(_cfg["ledge_top"])
	var z := _coast_z - from - depth / 2.0
	var body := Vector3(span * 2.0, top - WATER_Y, depth)
	var mid_y := (top + WATER_Y) / 2.0
	var edge_z := _coast_z - from - depth
	add_child(_box(body, Vector3(0.0, mid_y, z), _ledge_material(span, edge_z)))
	var cap := _lit_material(
		Color(str(_cfg["ledge_cap"])), Color(str(_cfg["promenade_glow"])), Num.f(_cfg["ledge_glow"])
	)
	var cap_at := Vector3(0.0, top + 0.12, edge_z + 0.7)
	add_child(_box(Vector3(span * 2.0, 0.25, 1.4), cap_at, cap))
	_kerb(span, top, edge_z)
	_railing(span, top, edge_z)
	_posts(span, top, edge_z)


## The ledge's paving: slabs, a pool of lamplight under every lamp, the fires' glow on the lip.
func _ledge_material(span: float, edge_z: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LEDGE
	mat.set_shader_parameter("stone_colour", Color(str(_cfg["ledge_color"])))
	mat.set_shader_parameter("pool_colour", Color(str(_cfg["lamp_color"])))
	mat.set_shader_parameter("fire_colour", Color(str(_cfg["fire_reflect"])))
	mat.set_shader_parameter("lamp_gap", Num.f(_cfg["post_gap"]))
	mat.set_shader_parameter("lamp_span", span)
	mat.set_shader_parameter("lamp_z", edge_z + POST_BACK)
	mat.set_shader_parameter("lip_z", edge_z)
	var pool: Array = _cfg["pool_radius"]
	mat.set_shader_parameter("pool_radius", Vector2(Num.f(pool[0]), Num.f(pool[1])))
	mat.set_shader_parameter("pool_strength", Num.f(_cfg["pool_strength"]))
	mat.set_shader_parameter("fire_strength", Num.f(_cfg["ledge_fire"]))
	var xs := PackedFloat32Array(_fires)
	if not xs.is_empty():
		var total := 0.0
		for x: float in xs:
			total += x
		mat.set_shader_parameter("fire_x", total / xs.size())
	return mat


## Kerb stones along the ledge's lip: pale blocks with gaps, so the edge reads as cut stone.
func _kerb(span: float, top: float, edge_z: float) -> void:
	var gap := Num.f(_cfg["kerb_gap"])
	var count := int(span * 2.0 / gap)
	var mm := _blocks(Vector3(gap * 0.88, 0.3, 0.7), Color(str(_cfg["kerb_color"])), count)
	for i: int in count:
		var at := Vector3(-span + (i + 0.5) * gap, top + 0.3, edge_z + 1.5)
		mm.multimesh.set_instance_transform(i, Transform3D(Basis(), at))
	add_child(mm)


## A railing along the lip: thin dark uprights and a top rail, a black silhouette over the water.
func _railing(span: float, top: float, edge_z: float) -> void:
	var gap := Num.f(_cfg["rail_gap"])
	var height := Num.f(_cfg["rail_height"])
	var color := Color(str(_cfg["rail_color"]))
	var thick := Num.f(_cfg["rail_thick"])
	var count := int(span * 2.0 / gap)
	var mm := _blocks(Vector3(thick, height, thick), color, count)
	for i: int in count:
		var at := Vector3(-span + (i + 0.5) * gap, top + 0.45 + height / 2.0, edge_z + 0.9)
		mm.multimesh.set_instance_transform(i, Transform3D(Basis(), at))
	add_child(mm)
	var rail := _lit_material(color, Color.BLACK, 0.0)
	add_child(
		_box(
			Vector3(span * 2.0, thick * 0.7, thick),
			Vector3(0.0, top + 0.45 + height, edge_z + 0.9),
			rail
		)
	)
	add_child(
		_box(
			Vector3(span * 2.0, thick * 0.5, thick * 0.8),
			Vector3(0.0, top + 0.45 + height * 0.5, edge_z + 0.9),
			rail
		)
	)


## A few tall lamp posts with warm heads and, between them, low bollards, along the ledge.
func _posts(span: float, top: float, edge_z: float) -> void:
	var gap := Num.f(_cfg["post_gap"])
	var height := Num.f(_cfg["post_height"])
	var count := int(span * 2.0 / gap)
	var mm := _blocks(Vector3(0.22, height, 0.22), Color(str(_cfg["post_color"])), count)
	for i: int in count:
		var x := -span + (i + 0.5) * gap
		mm.multimesh.set_instance_transform(
			i, Transform3D(Basis(), Vector3(x, top + 0.3 + height / 2.0, edge_z + POST_BACK))
		)
		var head := _box(
			Vector3(0.4, 0.28, 0.4),
			Vector3(x, top + 0.3 + height, edge_z + POST_BACK),
			_lit_material(
				Color("4a3416"), Color(str(_cfg["lamp_color"])), Num.f(_cfg["post_energy"])
			)
		)
		add_child(head)
		var halo := MeshInstance3D.new()
		halo.mesh = _glow_quad(Color(Color(str(_cfg["lamp_color"])), Num.f(_cfg["post_halo"])))
		halo.scale = Vector3.ONE * Num.f(_cfg["post_glow"])
		halo.position = head.position
		add_child(halo)
	add_child(mm)
	_bollards(span, top, edge_z)


## Low bollards along the ledge, between the posts.
func _bollards(span: float, top: float, edge_z: float) -> void:
	var color := Color(str(_cfg["rail_color"]))
	var bollard_gap := Num.f(_cfg["bollard_gap"])
	var bollards := int(span * 2.0 / bollard_gap)
	var bm := _blocks(
		Vector3(
			Num.f(_cfg["bollard_width"]),
			Num.f(_cfg["bollard_height"]),
			Num.f(_cfg["bollard_width"])
		),
		color.lightened(0.1),
		bollards
	)
	for i: int in bollards:
		var x := -span + (i + 0.5) * bollard_gap + 3.0
		bm.multimesh.set_instance_transform(
			i,
			Transform3D(
				Basis(), Vector3(x, top + 0.3 + Num.f(_cfg["bollard_height"]) / 2.0, edge_z + 3.2)
			)
		)
	add_child(bm)


func _blocks(size: Vector3, color: Color, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _lit_material(color, Color.BLACK, 0.0)
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## A soft additive billboard glow in `color`.
func _glow_quad(color: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	mat.albedo_texture = FarFire.soft_disc()
	mat.albedo_color = color
	quad.material = mat
	return quad


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
	mat.set_shader_parameter("sheet_length", length)
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
