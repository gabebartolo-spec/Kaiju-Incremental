class_name DistrictGround
extends Node3D
## The ground of a real district (CityDistrict): its actual streets at their widths with
## footpaths, the river, parks, squares and rail yards, all in one mesh; and the buildings
## round the playable rect (the skyline: drawn, never destroyed) as one multimesh of boxes.
## Presentation only. Map data © OpenStreetMap contributors, ODbL 1.0.

const MARGIN := 80.0  # ground past the baked area, so the horizon is never a void
const WATER := Color("2c5874")
const WATER_ROUGHNESS := 0.12
const PARK := Color("4f6a3c")
const PLAZA := Color("8c877c")
const RAIL := Color("5a4c40")
const SLEEPERS := Color("2c2622")
const RAIL_WIDTH := 0.35
const SKYLINE_DARKEN := 0.4  # the skyline sits back behind the playable city
## Layer heights: higher layers draw over lower ones (roads cross the river on bridges).
const Y_PARK := 0.010
const Y_RAIL := 0.012
const Y_WATER := 0.014
const Y_WALK := 0.018
const Y_ROAD := 0.022
const Y_TRACK := 0.026

var plan: Dictionary
var _st := SurfaceTool.new()


func _init(p_plan: Dictionary) -> void:
	plan = p_plan


func _ready() -> void:
	var bounds: Rect2 = plan["bounds"]
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_rect(bounds.grow(MARGIN), 0.0, Look.color("outskirts"))
	_rect(bounds, 0.004, Look.color("lot"))
	var order := {"park": Y_PARK, "plaza": Y_PARK + 0.001, "rail": Y_RAIL}
	for use: String in order:
		_areas(use, Num.f(order[use]))
	_streets()
	for line: PackedVector2Array in plan["rails"]:
		for i: int in line.size() - 1:
			_segment(line[i], line[i + 1], RAIL_WIDTH, Y_TRACK, SLEEPERS)
	_commit(1.0)
	# The river on its own, glossy, so it reads as water and not as one more road.
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_areas("water", Y_WATER)
	_commit(WATER_ROUGHNESS)
	_collision(bounds.grow(MARGIN))


func _areas(use: String, y: float) -> void:
	for area: Dictionary in plan["areas"]:
		if str(area["use"]) == use:
			var poly: PackedVector2Array = area["poly"]
			_poly(poly, y, _area_color(use))


func _commit(roughness: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # flat ground, only ever seen from above
	mi.material_override = mat
	add_child(mi)


func _area_color(use: String) -> Color:
	match use:
		"water":
			return WATER
		"park":
			return PARK
		"rail":
			return RAIL
	return PLAZA


## Footpaths first (wider, lighter), then the carriageways over them, then a square at every
## junction as wide as its widest street so corners join cleanly.
func _streets() -> void:
	var nodes: Array[Vector2] = plan["nodes"]
	var walk := Num.f(plan["sidewalk"])
	var asphalt := Look.color("asphalt")
	var kerb := Look.color("lot").lightened(0.12)
	var widest := {}
	for street: Dictionary in plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var w := Num.f(street["width"])
		var paved := walk if str(street["kind"]) != "alley" else 0.0
		_segment(a, b, w + paved * 2.0, Y_WALK, kerb)
		for n: int in [Num.i(street["from"]), Num.i(street["to"])]:
			widest[n] = maxf(Num.f(widest.get(n, 0.0)), w)
	for street: Dictionary in plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		_segment(a, b, Num.f(street["width"]), Y_ROAD, asphalt)
	for n: int in widest:
		var w := Num.f(widest[n])
		_rect(Rect2(nodes[n] - Vector2(w, w) * 0.5, Vector2(w, w)), Y_ROAD, asphalt)


func _segment(a: Vector2, b: Vector2, width: float, y: float, color: Color) -> void:
	var along := b - a
	if along.length() < 0.001:
		return
	var side := along.orthogonal().normalized() * width * 0.5
	_quad([a + side, b + side, b - side, a - side], y, color)


func _rect(r: Rect2, y: float, color: Color) -> void:
	_quad([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)], y, color)


## Four corners in either winding; both triangles face up.
func _quad(c: Array[Vector2], y: float, color: Color) -> void:
	var up := (c[1] - c[0]).cross(c[2] - c[0]) < 0.0
	for i: int in ([0, 1, 2, 0, 2, 3] if up else [0, 2, 1, 0, 3, 2]):
		_vertex(c[i], y, color)


func _poly(poly: PackedVector2Array, y: float, color: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	var up := _signed_area(poly) < 0.0
	for t: int in range(0, tris.size() - 2, 3):
		var order: Array[int] = [tris[t], tris[t + 1], tris[t + 2]]
		if not up:
			order = [tris[t], tris[t + 2], tris[t + 1]]
		for i: int in order:
			_vertex(poly[i], y, color)


func _signed_area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i: int in poly.size():
		sum += poly[i - 1].cross(poly[i])
	return sum * 0.5


func _vertex(p: Vector2, y: float, color: Color) -> void:
	_st.set_normal(Vector3.UP)
	_st.set_color(color)
	_st.add_vertex(Vector3(p.x, y, p.y))


func _collision(r: Rect2) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(r.size.x, 1.0, r.size.y)
	shape.shape = box
	shape.position = Vector3(r.get_center().x, -0.5, r.get_center().y)
	body.add_child(shape)
	add_child(body)


## The skyline round the playable rect: one box per outer building, coloured by style.
static func skyline(outer: Array[Dictionary]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var mesh := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mesh.material = mat
	mm.mesh = mesh
	mm.instance_count = outer.size()
	var styles := Look.styles()
	for i: int in outer.size():
		var b := outer[i]
		var size := Vector3(Num.f(b["w"]), Num.f(b["h"]), Num.f(b["d"]))
		var at := Vector3(Num.f(b["x"]), size.y * 0.5, Num.f(b["z"]))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(size), at))
		var tone := styles[posmod(Num.i(b["style"]) + Num.i(b["osm"]), styles.size())]
		mm.set_instance_color(i, tone.darkened(SKYLINE_DARKEN))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi
