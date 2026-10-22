extends RefCounted
## The lightning, the beam and the dash streaks laid into an icon render (render_icon.gd --fx=):
## our own light effects, never part of the model. Lightning is forked, jagged ribbons (a white-hot
## core in a blue-white glow, facing the camera) leaving the mouth; the dash is straight speed
## streaks trailing the foot; the beam is one thick ribbon the way the jaws point with lightning
## arcs crackling round it. Seeded: the same icon every run.

const BOLT_SHADER := preload("res://tools/capture/icon_bolt.gdshader")
const GLOW := Color(0.45, 0.7, 1.0, 0.75)
const CORE := Color(1.0, 1.0, 1.0)
const SEGMENTS := 9
const FORKS := 3
## How far a bolt zigzags across its way, as a share of its length.
const BOLT_JITTER := 0.1
## The glow ribbon's width over the core's, and each one's brightness (HDR, so the glow blooms).
const GLOW_WIDTH := 2.4
const GLOW_STRENGTH := 1.6
const CORE_STRENGTH := 3.0
## Dash streaks: how many, their spread up and down (model sizes) and core width.
## Core widths (model sizes) of the main bolt and of the beam.
const BOLT_WIDTH := 0.08
const BEAM_WIDTH := 0.24
## How much a ribbon narrows from its start to its far end (1 = to a point).
const TAPER := 0.95
## The beam stays thick to its end: a sustained beam, not a spike.
const BEAM_TAPER := 0.25
## Lightning arcs round the beam.
const BEAM_ARCS := 3
const STREAKS := 4
const STREAK_SPAN := 0.16
const STREAK_WIDTH := 0.035


## The effect `kind` ("lightning" or "beam") leaving `mouth` along `face`, for a model about
## `scale` across (widths and spreads), reaching `reach` model sizes, seen along `view` (the
## camera's looking direction, for the ribbons' width).
static func build(
	kind: String, mouth: Vector3, face: Vector3, scale: float, reach: float, view: Vector3
) -> Node3D:
	var root := Node3D.new()
	var ahead := face.normalized()
	if kind == "beam":
		root.add_child(_beam(mouth, ahead, scale, reach, view))
	elif kind == "dash":
		root.add_child(_streaks(mouth, ahead, scale, reach, view))
	else:
		root.add_child(_lightning(mouth, ahead, scale, reach, view))
	return root


## The box round every mesh of an effect `build` made, in the subject's space.
static func bounds(fx: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child: Node in fx.get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var part := mi.transform * mi.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## Speed streaks for the dash: straight ribbons trailing behind `anchor` (against `ahead`),
## spread up the leg, white cores in the glow, thinning to their far ends.
static func _streaks(
	anchor: Vector3, ahead: Vector3, scale: float, reach: float, view: Vector3
) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2209
	var side := ahead.cross(Vector3.UP).normalized()
	var paths: Array = []
	for k: int in STREAKS:
		var height := lerpf(-STREAK_SPAN, STREAK_SPAN, float(k) / (STREAKS - 1))
		var start := (
			anchor
			+ Vector3.UP * (height + rng.randf_range(-0.03, 0.03)) * scale
			+ side * rng.randf_range(-0.05, 0.05) * scale
			- ahead * rng.randf_range(0.0, 0.12) * scale
		)
		var end := start - ahead * rng.randf_range(0.4, 1.0) * scale * reach
		paths.append([[start, start.lerp(end, 0.5), end], scale * STREAK_WIDTH])
	return _glow_mesh(paths, view)


## The Thunder Beam: one thick straight ribbon from the mouth with lightning crackling round it.
static func _beam(
	mouth: Vector3, ahead: Vector3, scale: float, reach: float, view: Vector3
) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3301
	var side := ahead.cross(view).normalized()
	var end := mouth + ahead * scale * reach
	var paths: Array = [[[mouth, mouth.lerp(end, 0.5), end], scale * BEAM_WIDTH, BEAM_TAPER]]
	for k: int in BEAM_ARCS:
		var from := mouth.lerp(end, rng.randf_range(0.05, 0.45))
		var to := mouth.lerp(end, rng.randf_range(0.6, 1.0))
		var lift := side * (1.0 if k % 2 == 0 else -1.0) * scale * BEAM_WIDTH * 0.5
		paths.append(
			[_jag(from + lift, to + lift, side, scale * 0.05, rng), scale * BOLT_WIDTH * 0.6]
		)
	return _glow_mesh(paths, view)


static func _lightning(
	mouth: Vector3, ahead: Vector3, scale: float, reach: float, view: Vector3
) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1127
	var side := ahead.cross(view).normalized()
	if side.length() < 0.1:
		side = Vector3.UP
	var length := scale * reach
	var paths: Array = []
	var main := _jag(mouth, mouth + ahead * length, side, length * BOLT_JITTER, rng)
	paths.append([main, scale * BOLT_WIDTH])
	for k: int in FORKS:
		var from: Vector3 = main[rng.randi_range(1, main.size() / 2)]
		var bend := side * (1.0 if k % 2 == 0 else -1.0) * rng.randf_range(0.3, 0.55)
		var lift := Vector3.UP * rng.randf_range(-0.15, 0.15)
		var to := from + (ahead * rng.randf_range(0.45, 0.7) + bend + lift) * length
		paths.append(
			[_jag(from, to, side, length * BOLT_JITTER * 0.7, rng), scale * BOLT_WIDTH * 0.6]
		)
	return _glow_mesh(paths, view)


## Ribbons along `paths` ([points, width] or [points, width, taper] each) facing `view`: a wide
## glow, the white core over it.
static func _glow_mesh(paths: Array, view: Vector3) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for pass_index: int in 2:  # the wide glow first, the white core over it
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for path: Array in paths:
			var points: Array = path[0]
			var width: float = path[1] * (GLOW_WIDTH if pass_index == 0 else 1.0)
			var taper: float = path[2] if path.size() > 2 else TAPER
			_ribbon(st, points, width, taper, view)
		var mat := ShaderMaterial.new()
		mat.shader = BOLT_SHADER
		mat.set_shader_parameter("tint", GLOW if pass_index == 0 else CORE)
		mat.set_shader_parameter("strength", GLOW_STRENGTH if pass_index == 0 else CORE_STRENGTH)
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


## A ribbon along `points`, `width` across, turned to face `view`, narrowing to its far end by
## `taper` (a share of its width).
static func _ribbon(
	st: SurfaceTool, points: Array, width: float, taper: float, view: Vector3
) -> void:
	var count := points.size()
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i: int in count:
		var p: Vector3 = points[i]
		var ahead: Vector3 = points[mini(i + 1, count - 1)]
		var behind: Vector3 = points[maxi(i - 1, 0)]
		var along := ahead - behind
		var across := (
			along.cross(view).normalized() * width * 0.5 * (1.0 - taper * float(i) / (count - 1))
		)
		left.append(p - across)
		right.append(p + across)
	for i: int in count - 1:
		var quad: Array[Vector3] = [left[i], right[i], right[i + 1], left[i + 1]]
		var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[k])
			st.add_vertex(quad[k])
