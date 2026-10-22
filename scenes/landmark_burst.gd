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
## Cheap on its break frame (lead, 2026-10-19: a burst cost 12-14 ms windowed): every burst
## shares one chunk mesh and one smoke quad with their materials, built once; each frame writes
## its spray and cloud as one MultiMesh buffer, not an instance at a time; and CityView hands it
## the section's chunk list, never a lifted copy of the landmark's meshes.

const SECONDS := 0.15  # a landed landmark section's shrink (retire)
const GRAVITY := 20.0
const DUST := Color(0.62, 0.61, 0.58)
const SMOKE := preload("res://scenes/smoke.gdshader")  # Fx's soft step puff (#62), not a sphere

## Shared by every burst (_shared).
static var _box: BoxMesh
static var _quad: QuadMesh

var chunks := 0
var _cfg: Dictionary
var _t := 0.0
var _from := PackedVector3Array()
var _vel := PackedVector3Array()
var _size := PackedFloat32Array()
var _spray: MultiMeshInstance3D
var _clouds: MultiMeshInstance3D
var _cloud_at := PackedVector3Array()
var _cloud_size := 0.0
var _colors := PackedColorArray()


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


## parts: the section's voxels as debris sources (BuildingView.hide_chunks). view: for its
## debris and dust. event: the sim's fall_start (its building's middle: the spray flies away
## from it; its pivot is where this node stands).
func _init(parts: Array, view: CityView, event: Dictionary) -> void:
	_cfg = Content.section("landmark_burst")
	var b := view.sim.buildings[Num.i(event["building"])]
	var pivot: Vector3 = event["pivot"]
	position = pivot
	_shared()
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
	if _clouds != null:
		var k := _t / Num.f(_cfg["cloud_life"])
		if k >= 1.0:
			_clouds.queue_free()
			_clouds = null
		else:
			_draw_clouds(k)


## The chunk mesh (unshaded, in each chunk's own colour) and the smoke quad, built once.
static func _shared() -> void:
	if _box != null:
		return
	_box = BoxMesh.new()
	_box.size = Vector3.ONE * BuildingVoxels.VOXEL
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # its own albedo, not the night lighting
	_box.material = mat
	_quad = QuadMesh.new()
	var smoke := ShaderMaterial.new()
	smoke.shader = SMOKE
	smoke.set_shader_parameter("centre_keep", 1.0)  # the hole is by the kaiju, mid-screen
	_quad.material = smoke


## The spray: every so many of the section's voxels, as a chunk two or three voxels across in
## its own colour, darkened like broken concrete (a share darker still), thrown outward and up.
func _throw(parts: Array, middle: Vector2, rng: RandomNumberGenerator) -> void:
	var every := maxi(1, parts.size() / Num.i(_cfg["chunks"]))
	var size: Array = _cfg["chunk_voxels"]
	var speed: Array = _cfg["chunk_speed"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _box
	mm.instance_count = ceili(float(parts.size()) / every)
	for n: int in range(0, parts.size(), every):
		var part: Dictionary = parts[n]
		var pos: Vector3 = part["pos"]
		var color: Color = part["color"]
		_from.append(pos)
		var out := _outward(pos, middle).rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))
		var fling := out * rng.randf_range(Num.f(speed[0]), Num.f(speed[1]))
		_vel.append(fling + Vector3.UP * rng.randf_range(2.0, 6.0))
		var dark := rng.randf() < Num.f(_cfg["chunk_dark_share"])
		var shade := Num.f(_cfg["chunk_dark" if dark else "chunk_shade"])
		_colors.append(Color(color * shade, 1.0))
		_size.append(rng.randf_range(Num.f(size[0]), Num.f(size[1])))
	chunks = _from.size()
	_spray = MultiMeshInstance3D.new()
	_spray.multimesh = mm
	_spray.top_level = true
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spray)
	_draw_spray(1.0)


func _draw_spray(shrink: float) -> void:
	var buf := PackedFloat32Array()
	buf.resize(_from.size() * 16)
	var axis := Vector3(1, 1, 0).normalized()
	for i: int in _from.size():
		var at := _from[i] + _vel[i] * _t + Vector3.DOWN * (0.5 * GRAVITY * _t * _t)
		at.y = maxf(at.y, 0.1)
		var turn := Basis(axis, _t * 8.0 + i).scaled(Vector3.ONE * _size[i] * shrink)
		_write(buf, i, turn, at, _colors[i])
	_spray.multimesh.buffer = buf


## One instance into a MultiMesh buffer (3D transform rows, then its colour: 16 floats).
static func _write(buf: PackedFloat32Array, i: int, basis: Basis, at: Vector3, c: Color) -> void:
	var k := i * 16
	buf[k] = basis.x.x
	buf[k + 1] = basis.y.x
	buf[k + 2] = basis.z.x
	buf[k + 3] = at.x
	buf[k + 4] = basis.x.y
	buf[k + 5] = basis.y.y
	buf[k + 6] = basis.z.y
	buf[k + 7] = at.y
	buf[k + 8] = basis.x.z
	buf[k + 9] = basis.y.z
	buf[k + 10] = basis.z.z
	buf[k + 11] = at.z
	buf[k + 12] = c.r
	buf[k + 13] = c.g
	buf[k + 14] = c.b
	buf[k + 15] = c.a


## The cloud on the break frame itself: soft camera-facing puffs over the opening, thick at
## first, swelling and thinning out.
func _cover(lo: Vector3, hi: Vector3, rng: RandomNumberGenerator) -> void:
	var span := hi - lo
	_cloud_size = clampf(maxf(span.x, span.z) * 0.3, 0.6, Num.f(_cfg["cloud_max"])) * 2.4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quad
	mm.instance_count = Num.i(_cfg["clouds"])
	for n: int in mm.instance_count:
		_cloud_at.append(
			Vector3(
				rng.randf_range(lo.x, hi.x),
				rng.randf_range(lo.y, hi.y),
				rng.randf_range(lo.z, hi.z)
			)
		)
	_clouds = MultiMeshInstance3D.new()
	_clouds.multimesh = mm
	_clouds.top_level = true
	_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_clouds)
	_draw_clouds(0.0)


func _draw_clouds(k: float) -> void:
	var buf := PackedFloat32Array()
	buf.resize(_cloud_at.size() * 16)
	var dust := Color(DUST, Num.f(_cfg["cloud_alpha"]) * (1.0 - k * k))
	var grow := Basis.from_scale(Vector3.ONE * _cloud_size * (0.8 + 0.7 * k))
	for n: int in _cloud_at.size():
		_write(buf, n, grow, _cloud_at[n], dust)
	_clouds.multimesh.buffer = buf


static func _outward(pos: Vector3, middle: Vector2) -> Vector3:
	return Vector3(pos.x - middle.x, 0.0, pos.z - middle.y).normalized()
