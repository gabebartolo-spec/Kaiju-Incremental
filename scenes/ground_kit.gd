class_name GroundKit
extends RefCounted
## What CityGround lays down for the ground shader (ground_slab.gdshader): the slab kinds, the
## instance custom data that carries them, and the one material (with the look's numbers) every
## ground-family surface shares. Presentation only.

const SLAB_SHADER := preload("res://scenes/ground_slab.gdshader")
const CONCRETE := preload("res://scenes/concrete_stand.gdshader")
const CONCRETE_FAR := preload("res://scenes/concrete_stand_far.gdshader")
## The shader's uniforms, each read from the look as "ground_<name>" (data/looks.json).
const BLOCK_KEYS: Array[String] = [
	"block",
	"block_noise",
	"patch_noise",
	"speck_chance",
	"speck_dark",
	"seam",
	"fade_near",
	"fade_far",
	"mottle",
	"track",
	"tar",
	"patch_dark",
	"stain",
	"gutter",
	"panel",
	"damp",
	"streak",
	"soil",
	"paving",
	"band_h",
	"night_floor"
]
## What a slab is (ground_slab.gdshader's kind, in the instance custom data) and which way a
## street runs.
const K_ASPHALT := 0
const K_ROAD := 1
const K_PAVEMENT := 2
const K_LAWN := 3
const K_CONCRETE := 4
const K_DECK := 5
const K_PAINT := 6
const K_JUNCTION := 7  # a junction box: both streets' lanes, no gutter
const ALONG_X := 0
const ALONG_Z := 1
const TURNED := 2
const NO_WATER := -100.0  # a concrete face with no water line


## Instance custom data for a surface kind (ground_slab.gdshader): `water_y` is a concrete
## face's water line.
static func kind(slab_kind: int, water_y: float = 0.0) -> Color:
	return Color(float(slab_kind), water_y, 0.0, 0.0)


## A street's custom data: the centre line split into a big and a small part, so the half-float
## instance buffer keeps it exact to a few millimetres.
static func road_kind(slab_kind: int, axis: int, centre: float, half_width: float) -> Color:
	var big := roundf(centre / 16.0) * 16.0
	return Color(float(slab_kind) + float(axis) / 8.0, big, centre - big, half_width)


## The ground's material (ground_slab.gdshader, the one ground shader) with the look's numbers.
static func material(map_seed: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SLAB_SHADER
	apply_look(mat, map_seed)
	return mat


## The look's ground numbers (surface_detail.gdshaderinc's uniforms) and the city's map seed, so
## the same seed lays the same ground, on a material of any shader that includes the surface
## family.
static func apply_look(mat: ShaderMaterial, map_seed: int) -> void:
	for key: String in BLOCK_KEYS:
		mat.set_shader_parameter(key, Look.value("ground_" + key))
	mat.set_shader_parameter("seed", float(map_seed % 997))


## The slabs ({"t": transform, "c": colour, "d": kind data}) as one MultiMesh of boxes.
static func slab_instances(slabs: Array[Dictionary], mat: ShaderMaterial) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var box := BoxMesh.new()
	box.material = mat
	mm.mesh = box
	mm.instance_count = slabs.size()
	for i: int in slabs.size():
		var t: Transform3D = slabs[i]["t"]
		var c: Color = slabs[i]["c"]
		var d: Color = slabs[i]["d"]
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, c)
		mm.set_instance_custom_data(i, d)
	return _instance(mm)


## The paint boxes (transforms) as one MultiMesh.
static func paint_instances(paint: Array[Transform3D], mat: ShaderMaterial) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.material = mat
	mm.mesh = box
	mm.instance_count = paint.size()
	for i: int in paint.size():
		mm.set_instance_transform(i, paint[i])
	return _instance(mm)


static func _instance(mm: MultiMesh) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## rects with every hole cut out of them, as the rects left over.
static func cut(rects: Array[Rect2], holes: Array[Rect2]) -> Array[Rect2]:
	var out: Array[Rect2] = rects.duplicate()
	for hole: Rect2 in holes:
		var left: Array[Rect2] = []
		for r: Rect2 in out:
			var common := r.intersection(hole)
			if not r.intersects(hole) or common.get_area() <= 0.0:
				left.append(r)
				continue
			left.append(Rect2(r.position, Vector2(r.size.x, common.position.y - r.position.y)))
			left.append(Rect2(r.position.x, common.end.y, r.size.x, r.end.y - common.end.y))
			var mid := Rect2(r.position.x, common.position.y, 0.0, common.size.y)
			left.append(Rect2(mid.position, Vector2(common.position.x - r.position.x, mid.size.y)))
			left.append(Rect2(common.end.x, mid.position.y, r.end.x - common.end.x, mid.size.y))
		out.assign(left.filter(func(q: Rect2) -> bool: return q.size.x > 0.0 and q.size.y > 0.0))
	return out


## The skyline's concrete: the ground's concrete look and numbers (concrete_stand.gdshader).
static func concrete_material(haze: float, hazy: bool, map_seed: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CONCRETE_FAR if hazy else CONCRETE
	apply_look(mat, map_seed)
	mat.set_shader_parameter("haze_color", Look.color("fog_color"))
	mat.set_shader_parameter("haze", haze)
	return mat


## The flat ground the city's physics debris lands on (moved here from CityView).
static func floor_body() -> StaticBody3D:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(800.0, 1.0, 800.0)
	shape.shape = box_shape
	shape.position.y = -0.5
	ground.add_child(shape)
	return ground
