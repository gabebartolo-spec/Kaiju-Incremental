class_name LandmarkBurst
extends Node3D
## Every section a landmark sheds (a stadium's rim or stands, toppling or dropping) bursts where
## it stands on its break frame (D-078 rounds 4-5): its piece is gone at once and, on that same
## frame, a cloud of dust covers the opening while a few hundred chunks of its own voxels, lit in
## its colours and two or three voxels across, fly outward from the landmark's middle and fall
## for a third of a second before they shrink away; a few real physics fragments settle on the
## street. So no cut face, hinge or lip is ever seen, and the break never reads as a vanish.
## CityView keeps this node in the section's place until the sim lands the fall (it rotates or
## drops it, to no effect: the spray and cloud are top_level), and its landing leaves no strip
## or crush (CityView.fall_land). Tuning: data/tuning.json "landmark_burst".

const SECONDS := 0.15  # a landed landmark section's shrink (retire)
const GRAVITY := 20.0
const DUST := Color(0.78, 0.76, 0.72)

var chunks := 0
var _cfg: Dictionary
var _t := 0.0
var _from := PackedVector3Array()
var _vel := PackedVector3Array()
var _size := PackedFloat32Array()
var _spray: MultiMeshInstance3D
var _clouds: Array[MeshInstance3D] = []
var _cloud_mat: StandardMaterial3D


## True for any section a landmark sheds.
static func bursts(sim: RampageSim, event: Dictionary) -> bool:
	return sim.buildings[Num.i(event["building"])].landmark != ""


## A section that has landed: an ordinary building's goes at once (its debris and rubble take
## over); a landmark's shrinks into its hinge over SECONDS under the dust, so it never pops.
static func retire(node: Node3D, landmark: bool) -> void:
	if not landmark:
		node.queue_free()
		return
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 0.01, SECONDS)
	tween.tween_callback(node.queue_free)


## piece: the lifted section (BuildingView.lift_piece), freed here. view: for its debris and
## dust. event: the sim's fall_start (its building's middle: the spray flies away from it).
func _init(piece: Node3D, view: CityView, event: Dictionary) -> void:
	_cfg = Content.section("landmark_burst")
	var b := view.sim.buildings[Num.i(event["building"])]
	var parts: Array = piece.get_meta("parts", [])
	piece.queue_free()
	if parts.is_empty():
		return
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for part: Dictionary in parts:
		var pos: Vector3 = part["pos"]
		lo = lo.min(pos)
		hi = hi.max(pos)
	var rng := RandomNumberGenerator.new()
	rng.seed = Num.i(event["id"])
	_throw(parts, Vector2(b.x, b.z), rng)
	_cover(lo, hi, rng)
	var every := maxi(1, parts.size() / Num.i(_cfg["fragments"]))
	for n: int in range(0, parts.size(), every):  # a few real fragments settle on the street
		var part: Dictionary = parts[n]
		var pos: Vector3 = part["pos"]
		var color: Color = part["color"]
		view.debris(pos, color, (_outward(pos, Vector2(b.x, b.z)) + Vector3.UP * 0.5).normalized())
	view.fx.dust((lo + hi) * 0.5, clampf((hi - lo).length() * 0.5, 1.0, 4.0))


func _process(delta: float) -> void:
	_t += delta
	if _spray != null:
		var life := Num.f(_cfg["chunk_life"])
		if _t >= life:
			_spray.queue_free()
			_spray = null
		else:
			_draw_spray(1.0 - clampf((_t - life * 0.6) / (life * 0.4), 0.0, 1.0))
	if not _clouds.is_empty():
		var k := _t / Num.f(_cfg["cloud_life"])
		if k >= 1.0:
			for c: MeshInstance3D in _clouds:
				c.queue_free()
			_clouds.clear()
		else:
			for c: MeshInstance3D in _clouds:
				c.scale = Vector3.ONE * (0.8 + 0.7 * k)
			_cloud_mat.albedo_color.a = Num.f(_cfg["cloud_alpha"]) * (1.0 - k * k)


## The spray: every so many of the section's voxels, as a chunk two or three voxels across in
## its own colour (lit), thrown outward and up.
func _throw(parts: Array, middle: Vector2, rng: RandomNumberGenerator) -> void:
	var every := maxi(1, parts.size() / Num.i(_cfg["chunks"]))
	var size: Array = _cfg["chunk_voxels"]
	var speed: Array = _cfg["chunk_speed"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE * BuildingVoxels.VOXEL
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # lit: reads in the night city
	box.material = mat
	mm.mesh = box
	mm.instance_count = ceili(float(parts.size()) / every)
	for n: int in range(0, parts.size(), every):
		var part: Dictionary = parts[n]
		var pos: Vector3 = part["pos"]
		var color: Color = part["color"]
		var i := _from.size()
		_from.append(pos)
		var out := _outward(pos, middle).rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))
		var fling := out * rng.randf_range(Num.f(speed[0]), Num.f(speed[1]))
		_vel.append(fling + Vector3.UP * rng.randf_range(2.0, 6.0))
		mm.set_instance_color(i, color.lightened(Num.f(_cfg["chunk_lift"])))
		_size.append(rng.randf_range(Num.f(size[0]), Num.f(size[1])))
	chunks = _from.size()
	_spray = MultiMeshInstance3D.new()
	_spray.multimesh = mm
	_spray.top_level = true
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spray)
	_draw_spray(1.0)


func _draw_spray(shrink: float) -> void:
	var mm := _spray.multimesh
	for i: int in _from.size():
		var at := _from[i] + _vel[i] * _t + Vector3.DOWN * (0.5 * GRAVITY * _t * _t)
		at.y = maxf(at.y, 0.1)
		var s := _size[i] * shrink
		var turn := Basis(Vector3(1, 1, 0).normalized(), _t * 8.0 + i)
		mm.set_instance_transform(i, Transform3D(turn.scaled(Vector3.ONE * s), at))


## The cloud on the break frame itself: dust balls over the opening, opaque at first, swelling
## and thinning out.
func _cover(lo: Vector3, hi: Vector3, rng: RandomNumberGenerator) -> void:
	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_mat.albedo_color = Color(DUST, Num.f(_cfg["cloud_alpha"]))
	_cloud_mat.roughness = 1.0
	var span := hi - lo
	var radius := clampf(maxf(span.x, span.z) * 0.3, 0.6, Num.f(_cfg["cloud_max"]))
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 1.6
	sphere.radial_segments = 10
	sphere.rings = 6
	sphere.material = _cloud_mat
	for n: int in Num.i(_cfg["clouds"]):
		var c := MeshInstance3D.new()
		c.mesh = sphere
		c.top_level = true
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.position = Vector3(
			rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y), rng.randf_range(lo.z, hi.z)
		)
		c.scale = Vector3.ONE * 0.8
		add_child(c)
		_clouds.append(c)


static func _outward(pos: Vector3, middle: Vector2) -> Vector3:
	return Vector3(pos.x - middle.x, 0.0, pos.z - middle.y).normalized()
