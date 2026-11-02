class_name TitleShore
extends Node3D
## The far shore's embankment for the title screen (#99): a stone sea wall with a lit promenade and
## a row of street lamps along the whole shore, so the towers stand on a visible edge instead of
## fading into the bay, and the fires' and windows' reflections streaking the water below it.
## Presentation only; numbers in tuning "title" "shore". The far shore's buildings start 12 m
## back from its edge (CitySkyline), so the wall and the promenade have the strip in front.

const REFLECT := preload("res://scenes/title_shore.gdshader")
const SAND := preload("res://scenes/title_sand.gdshader")
## The wall's face is at the shore line; the strip behind it is the promenade (m).
const PROMENADE := 9.0
const WATER_Y := -0.8
const MAX_FIRES := 12
## The shallows sit this far over the bay at the lap's low point, so they never flicker in it (m).
const TIDE_LIFT := 0.03

var _cfg: Dictionary
var _shore_z: float
var _cam: Vector3
var _fires: PackedFloat32Array
var _coast_z: float
var _water: ShaderMaterial
var _sand: ShaderMaterial
var _ripple: Dictionary
var _lap: Dictionary
var _bay: Dictionary
var _tide: Array[Node3D] = []
var _tide_rest := PackedFloat32Array()
var _time := 0.0


## places: "shore_z" (the far shore's edge, world z), "coast_z" (the play area's quay, where the
## near beach starts), "cam" (where the title's camera stands) and "fires" (the x of each burning
## tower, for their reflections).
func _init(cfg: Dictionary, places: Dictionary) -> void:
	_cfg = cfg
	_ripple = places["ripple"]
	_bay = places["water"]
	_lap = Content.section("water")["lap"]
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
	_beach(span)


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


## The play area's beach along the bottom of the picture (director 2026-11-02: "meant to be a
## beach"): a strip of sand from under the picture's bottom edge sloping down into the bay, the
## game's own sand (grains, wet along the waterline) going under the water past its lip, and the
## bay lapping up it (_tide).
func _beach(span: float) -> void:
	var near_z := _coast_z - Num.f(_cfg["beach_from"])
	var depth := Num.f(_cfg["beach_depth"])
	var grade := (Num.f(_cfg["beach_top"]) - WATER_Y) / depth
	var under := Num.f(_cfg["beach_under"])
	var step := Num.f(_cfg["beach_step"])
	# The sand swells and dips along the shore (two seeded waves), so the waterline wanders.
	var rng := Seeds.make("title_beach", 0)
	var wander := Num.f(_cfg["beach_wander"])
	var length := Num.f(_cfg["beach_wander_length"])
	var phase := Vector2(rng.randf() * TAU, rng.randf() * TAU)
	var cols := ceili(span * 2.0 / step) + 1
	var rows := ceili(depth + under) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)  # unlit sand (title_sand.gdshader): the normal is never read
	for j: int in rows:
		var back := minf(j, depth + under)  # metres from the near edge toward the bay
		for i: int in cols:
			var x := -span + i * step
			var swell := sin(x / length + phase.x) + 0.5 * sin(x / (length * 0.37) + phase.y)
			var at := Vector3(
				x, Num.f(_cfg["beach_top"]) - grade * back + wander * swell, near_z - back
			)
			st.set_uv(Vector2(at.x, at.z) / (HarbourView.GRAIN * HarbourView.GRAIN_TILE))
			st.add_vertex(at)
	for j: int in rows - 1:
		for i: int in cols - 1:
			var a := j * cols + i
			for k: int in [a, a + cols, a + 1, a + 1, a + cols, a + cols + 1]:  # clockwise from above
				st.add_index(k)
	var sand := MeshInstance3D.new()
	sand.mesh = st.commit()
	_sand = _sand_material(grade)
	sand.material_override = _sand
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sand)
	_shallows(span, near_z - depth)


## The sand's look: the game's grains and wet line (HarbourView), at night, the fires on it.
func _sand_material(grade: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SAND
	mat.set_shader_parameter("grains", HarbourView._grains(Look.color("sand")))
	mat.set_shader_parameter("wet_width", Num.f(_lap["wet_width"]))
	mat.set_shader_parameter("wet_dark", Num.f(_lap["wet_dark"]))
	mat.set_shader_parameter("night", Num.f(_cfg["beach_night"]))
	mat.set_shader_parameter("grade", grade)
	mat.set_shader_parameter("tide_y", WATER_Y + TIDE_LIFT)
	mat.set_shader_parameter("foam_color", Color(str(_cfg["beach_foam"])))
	mat.set_shader_parameter("foam_width", Num.f(_cfg["beach_foam_width"]))
	mat.set_shader_parameter("fire_colour", Color(str(_cfg["fire_reflect"])))
	mat.set_shader_parameter("fire_reach", Num.f(_cfg["beach_fire_reach"]))
	mat.set_shader_parameter("fire_strength", Num.f(_cfg["beach_fire"]))
	if not _fires.is_empty():
		var total := 0.0
		for x: float in _fires:
			total += x
		mat.set_shader_parameter("fire_x", total / _fires.size())
	return mat


## The bay's edge over the sand's lip, in the bay's own colour (tuning title variant "water"): it
## and the reflections rise and fall with the game's lap (tuning water.lap height, period), so the
## water runs a few metres up the shallow sand and back.
func _shallows(span: float, edge_z: float) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(span * 2.0, Num.f(_cfg["beach_under"]) * 2.0)
	var mat := _lit_material(Color(str(_bay["color"])), Color.BLACK, 0.0)
	mat.roughness = Num.f(_bay["roughness"])
	mesh.material = mat
	var water := MeshInstance3D.new()
	water.mesh = mesh
	water.position = Vector3(0.0, WATER_Y + TIDE_LIFT, edge_z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_rides_tide(water)


## The lap's rise this frame (m, 0 .. height): the shallows and the reflections over them follow it.
func _process(delta: float) -> void:
	_time += delta
	var period := Num.f(_lap["period"])
	var rise := Num.f(_lap["height"]) * (0.5 + 0.5 * sin(TAU * _time / period))
	for i: int in _tide.size():
		_tide[i].position.y = _tide_rest[i] + rise
	_sand.set_shader_parameter("tide_y", WATER_Y + TIDE_LIFT + rise)


func _rides_tide(node: Node3D) -> void:
	_tide.append(node)
	_tide_rest.append(node.position.y)


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
	_rides_tide(sheet)  # above the shallows, or they would hide the streaks near the beach
