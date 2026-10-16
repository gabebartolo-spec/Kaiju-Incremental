class_name CityView
extends Node3D
## The voxel city and its effects: sky and light, ground, one MultiMesh per building (cells
## bottom-up, so losing layers is a smaller visible_instance_count), tumbling debris, rings,
## flames and floating text. Draws only; RampageSim decides what breaks.

const VOXEL := 1.0
const MAX_DEBRIS := 220
const DEBRIS_PER_LAYER := 5
const STYLE_COLORS: Array[Color] = [
	Color("8d9298"), Color("b59a78"), Color("5f8f95"), Color("4b5260")
]
const WINDOW_DARK := Color("27384a")
const WINDOW_LIT := Color("ffd27a")

var sim: RampageSim
var _rng: RandomNumberGenerator
var _cube_mesh: BoxMesh
var _building_mms: Array[MultiMeshInstance3D] = []
var _debris: Array[RigidBody3D] = []


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	_rng = rng


func _ready() -> void:
	_cube_mesh = BoxMesh.new()
	_cube_mesh.size = Vector3.ONE * VOXEL * 0.94
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.9
	_cube_mesh.material = mat
	_build_environment()
	_build_ground()
	for b: RampageSim.Building in sim.buildings:
		_build_building(b)


func _process(_delta: float) -> void:
	if _debris.size() > MAX_DEBRIS:
		var old: RigidBody3D = _debris.pop_front()
		old.queue_free()


func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6f9fd8")
	sky_mat.sky_horizon_color = Color("e0c9a6")
	sky_mat.ground_horizon_color = Color("e0c9a6")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color("e0c9a6")
	env.fog_density = 0.0012
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.08
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color("fff1dc")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)


func _build_ground() -> void:
	var size := sim.arena_half * 2.0 + 60.0
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(size, 1.0, size)
	shape.shape = box_shape
	shape.position.y = -0.5
	ground.add_child(shape)
	add_child(ground)
	slab(Vector3(size, 0.2, size), Vector3(0, -0.1, 0), Color("5d7a45"))  # outskirts
	var city := (sim.arena_half - Num.f(sim.city["spacing"])) * 2.0
	slab(Vector3(city, 0.2, city), Vector3(0, -0.05, 0), Color("3a3f45"))  # asphalt
	for b: RampageSim.Building in sim.buildings:
		slab(Vector3(b.w + 1.2, 0.2, b.d + 1.2), Vector3(b.x, 0.0, b.z), Color("8a8f94"))


func slab(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
	return mi


func _build_building(b: RampageSim.Building) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _cube_mesh
	mm.instance_count = b.w * b.d * b.height
	var i := 0
	for layer: int in b.height:
		for ix: int in b.w:
			for iz: int in b.d:
				var cell := Vector3i(ix, layer, iz)
				mm.set_instance_transform(i, Transform3D(Basis(), _cell_pos(b, cell)))
				mm.set_instance_color(i, _cell_color(b, cell))
				i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	_building_mms.append(mmi)


func _base_color(b: RampageSim.Building) -> Color:
	return STYLE_COLORS[b.style % STYLE_COLORS.size()]


## cell: (x across, layer, z across).
func _cell_pos(b: RampageSim.Building, cell: Vector3i) -> Vector3:
	return (
		Vector3(b.x - b.w * 0.5 + cell.x + 0.5, cell.y + 0.5, b.z - b.d * 0.5 + cell.z + 0.5)
		* VOXEL
	)


func _cell_color(b: RampageSim.Building, cell: Vector3i) -> Color:
	var base := _base_color(b)
	if cell.y == b.height - 1:
		return base.darkened(0.25)
	var outer := cell.x == 0 or cell.z == 0 or cell.x == b.w - 1 or cell.z == b.d - 1
	if outer and cell.y % 2 == 1:
		var lit := (cell.x * 7 + cell.z * 13 + cell.y * 5 + b.style) % 6 == 0
		return WINDOW_LIT if lit else WINDOW_DARK
	return base * (1.0 - 0.04 * ((cell.x + cell.z + cell.y) % 3))


## A building lost `count` layers: hide them, throw voxels away from the kaiju, leave a
## rubble slab when nothing stands.
func layers_destroyed(index: int, count: int, kaiju_at: Vector3) -> void:
	var b := sim.buildings[index]
	_building_mms[index].multimesh.visible_instance_count = b.layers * b.w * b.d
	var away := (Vector3(b.x, 0, b.z) - kaiju_at).normalized()
	for layer: int in range(b.layers, b.layers + count):
		for _n: int in DEBRIS_PER_LAYER:
			var cell := Vector3i(_rng.randi_range(0, b.w - 1), layer, _rng.randi_range(0, b.d - 1))
			debris(_cell_pos(b, cell), _cell_color(b, cell), away)
	if b.layers == 0:
		slab(Vector3(b.w, 0.5, b.d), Vector3(b.x, 0.25, b.z), _base_color(b).darkened(0.35))


func debris(pos: Vector3, color: Color, away: Vector3) -> void:
	var body := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3.ONE * 0.8
	shape.shape = box_shape
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	body.position = pos
	add_child(body)
	var spread := Vector3(
		_rng.randf_range(-1, 1), _rng.randf_range(0.5, 1.5), _rng.randf_range(-1, 1)
	)
	body.apply_central_impulse((away * 4.0 + spread * 4.0) * body.mass)
	body.angular_velocity = Vector3(
		_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6)
	)
	_debris.append(body)
	var tween := body.create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(body, "scale", Vector3.ONE * 0.01, 0.6)
	tween.tween_callback(func() -> void: _forget_debris(body))


func _forget_debris(body: RigidBody3D) -> void:
	_debris.erase(body)
	body.queue_free()


## A burst of glowing voxels from `from` over a cone along `span` (direction times reach).
func flame_cone(from: Vector3, ground_at: Vector3, span: Vector3, color: Color) -> void:
	for _n: int in 40:
		var spread := span.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
		var target := ground_at + spread * _rng.randf_range(0.4, 1.0) + Vector3(0, 0.5, 0)
		_flame_voxel(from, target, color)


func _flame_voxel(from: Vector3, to: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * _rng.randf_range(0.5, 1.1)
	mesh.material = glow(color, 3.0)
	mi.mesh = mesh
	mi.position = from
	add_child(mi)
	var tween := mi.create_tween()
	tween.tween_property(mi, "position", to, _rng.randf_range(0.18, 0.35))
	tween.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.2)
	tween.tween_callback(mi.queue_free)


static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


## An expanding, fading ring on the ground around `centre`.
func ring(centre: Vector3, radius: float, color: Color, seconds: float) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = mat
	mi.mesh = torus
	mi.position = Vector3(centre.x, 0.3, centre.z)
	mi.scale = Vector3(0.2, 0.3, 0.2)
	add_child(mi)
	var tween := mi.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mi, "scale", Vector3(radius, 0.3, radius), seconds)
	tween.tween_property(mat, "albedo_color:a", 0.0, seconds)
	tween.chain().tween_callback(mi.queue_free)


func float_text(text: String, pos: Vector3, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 96
	l.outline_size = 24
	l.modulate = color
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tween := l.create_tween()
	tween.set_parallel(true)
	tween.tween_property(l, "position", pos + Vector3(0, 3, 0), 1.0)
	tween.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.chain().tween_callback(l.queue_free)
