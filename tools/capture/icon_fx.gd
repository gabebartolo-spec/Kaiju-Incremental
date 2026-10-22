extends RefCounted
## The lightning and the beam laid into an icon render (render_icon.gd --fx=): our own light
## effects, never part of the model. Lightning is forked, jagged ribbons (a white-hot core in a
## blue-white glow, additive, facing the camera) leaving the mouth; the beam is the game's own
## Atomic Breath core (beam.gdshader) as a thick cylinder along the way the jaws point.

const BOLT_SHADER := preload("res://tools/capture/icon_bolt.gdshader")
const BEAM_SHADER := preload("res://scenes/beam.gdshader")
const GLOW := Color(0.45, 0.7, 1.0)
const CORE := Color(1.0, 1.0, 1.0)
const SEGMENTS := 9
const FORKS := 4


## The effect `kind` ("lightning" or "beam") leaving `mouth` along `face`, for a model about
## `scale` across, seen along `view` (the camera's looking direction, for the ribbons' width).
static func build(
	kind: String, mouth: Vector3, face: Vector3, scale: float, view: Vector3
) -> Node3D:
	var root := Node3D.new()
	var ahead := face.normalized()
	if kind == "beam":
		root.add_child(_beam(mouth, ahead, scale))
	else:
		root.add_child(_lightning(mouth, ahead, scale, view))
	return root


static func _beam(mouth: Vector3, ahead: Vector3, scale: float) -> MeshInstance3D:
	var length := scale * 1.1
	var cyl := CylinderMesh.new()
	cyl.top_radius = scale * 0.07
	cyl.bottom_radius = scale * 0.13
	cyl.height = length
	cyl.radial_segments = 24
	var mat := ShaderMaterial.new()
	mat.shader = BEAM_SHADER
	mat.set_shader_parameter("progress", 0.3)
	mat.set_shader_parameter("power", 1.4)
	mat.set_shader_parameter("tint", Color(0.55, 0.75, 1.0))
	cyl.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	var y := ahead
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), mouth + ahead * length * 0.5)
	return mi


static func _lightning(
	mouth: Vector3, ahead: Vector3, scale: float, view: Vector3
) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1127
	var side := ahead.cross(view).normalized()
	if side.length() < 0.1:
		side = Vector3.UP
	var paths: Array = []
	var main := _jag(
		mouth, mouth + ahead * scale * 1.0 + Vector3.UP * scale * 0.05, side, scale * 0.09, rng
	)
	paths.append([main, scale * 0.012])
	for k: int in FORKS:
		var from: Vector3 = main[rng.randi_range(2, main.size() - 3)]
		var bend := side * (1.0 if k % 2 == 0 else -1.0) * rng.randf_range(0.25, 0.5)
		var to := (
			from
			+ (
				(
					ahead * rng.randf_range(0.25, 0.4)
					+ bend
					+ Vector3.UP * rng.randf_range(-0.1, 0.2)
				)
				* scale
			)
		)
		paths.append([_jag(from, to, side, scale * 0.06, rng), scale * 0.007])
	var mesh := ArrayMesh.new()
	for pass_index: int in 2:  # the wide glow first, the white core over it
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for path: Array in paths:
			var points: Array = path[0]
			var width: float = path[1] * (3.2 if pass_index == 0 else 1.0)
			_ribbon(st, points, width, view)
		var mat := ShaderMaterial.new()
		mat.shader = BOLT_SHADER
		mat.set_shader_parameter("tint", GLOW if pass_index == 0 else CORE)
		mat.set_shader_parameter("strength", 1.6 if pass_index == 0 else 3.0)
		mesh = st.commit(mesh)
		mesh.surface_set_material(pass_index, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


## A jagged line from `a` to `b`: midpoint displacement across `side`.
static func _jag(
	a: Vector3, b: Vector3, side: Vector3, jitter: float, rng: RandomNumberGenerator
) -> Array:
	var points: Array = [a]
	for i: int in range(1, SEGMENTS):
		var t := float(i) / SEGMENTS
		var kick := rng.randf_range(-1.0, 1.0) * jitter * sin(t * PI)
		points.append(
			(
				a.lerp(b, t)
				+ side * kick
				+ Vector3.UP * rng.randf_range(-0.3, 0.3) * jitter * sin(t * PI)
			)
		)
	points.append(b)
	return points


## A ribbon along `points`, `width` across, turned to face `view`, narrowing to its far end.
static func _ribbon(st: SurfaceTool, points: Array, width: float, view: Vector3) -> void:
	var count := points.size()
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i: int in count:
		var p: Vector3 = points[i]
		var ahead: Vector3 = points[mini(i + 1, count - 1)]
		var behind: Vector3 = points[maxi(i - 1, 0)]
		var along := ahead - behind
		var across := (
			along.cross(view).normalized() * width * 0.5 * (1.0 - 0.8 * float(i) / (count - 1))
		)
		left.append(p - across)
		right.append(p + across)
	for i: int in count - 1:
		var quad: Array[Vector3] = [left[i], right[i], right[i + 1], left[i + 1]]
		var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[k])
			st.add_vertex(quad[k])
