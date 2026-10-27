extends RefCounted
## Render plan item 14 (render_opt.kaiju_three_faces): the croc titan's cubes are drawn as three
## faces, not six, each pass mirroring them per cube onto the sides that face its camera
## (ThreeFaceCube, scenes/voxel_three_faces.gdshaderinc). Checks:
##  - the flag is ON by default;
##  - the mesh is the box's +X, +Y and +Z faces: 12 corners, 6 triangles, each one of the engine's
##    own BoxMesh triangles (same corners in the same order, so the same front side);
##  - the skin draws its cubes with it, on the box's cube, and turns the shader's three_faces on;
##    flag off, the box and three_faces off;
##  - the shader's mirror, redone on the CPU for 4000 seeded cube turns and eye places (half seen
##    in perspective, half orthographic as a sun's shadow sees them), draws every face the eye can
##    see, on the box's own square, front side out; without its in-plane flip it would turn faces
##    inside out (the check bites).
## Seeded by design: a fixed seed, no clock.

const SEED := 14
const CASES := 4000
const SIZE := 0.5
## Corners and normals match to this (the mesh's normals come back octahedral-packed).
const EPS := 1.0e-3
const SIDES: Array[Vector3] = [
	Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD
]

var _check: Callable
var _root: Node
var _box_aabb := AABB()


## check: the runner's check; root: where to put the kaiju.
func _init(p_check: Callable, p_root: Node) -> void:
	_check = p_check
	_root = p_root


func run() -> void:
	var on := Num.i(Content.section("render_opt").get("kaiju_three_faces", false)) != 0
	_check.call(on, "render_opt.kaiju_three_faces is ON by default")
	var mesh := ThreeFaceCube.mesh(Vector3.ONE * SIZE)
	var box := BoxMesh.new()
	box.size = Vector3.ONE * SIZE
	var tris := _triangles(mesh.surface_get_arrays(0))
	var box_tris := _triangles(box.get_mesh_arrays())
	_check_mesh(mesh, tris, box_tris)
	_check_mirror(tris, box_tris)
	await _skin(false)
	await _skin(true)


## Each triangle as [a, b, c, the normal at a].
static func _triangles(arrays: Array) -> Array[PackedVector3Array]:
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out: Array[PackedVector3Array] = []
	for t: int in range(0, idx.size(), 3):
		out.append(PackedVector3Array([pos[idx[t]], pos[idx[t + 1]], pos[idx[t + 2]], nor[idx[t]]]))
	return out


func _check_mesh(
	mesh: ArrayMesh, tris: Array[PackedVector3Array], box_tris: Array[PackedVector3Array]
) -> void:
	var corners := mesh.surface_get_array_len(0)
	_check.call(
		corners == 12 and tris.size() == 6,
		(
			"the cube mesh has 12 corners and 6 triangles (%d and %d; the box 24 and 12)"
			% [corners, tris.size()]
		)
	)
	var per_axis := Vector3.ZERO
	var own := 0
	for t: PackedVector3Array in tris:
		per_axis += t[3].round()
		for b: PackedVector3Array in box_tris:
			if _same(t, b):
				own += 1
				break
	_check.call(
		per_axis == Vector3(2, 2, 2), "two triangles on each of the +X, +Y and +Z faces, no other"
	)
	_check.call(
		own == tris.size(),
		(
			"each triangle is one of the box's own, same corners in the same order (%d of %d)"
			% [own, tris.size()]
		)
	)


## The same corners in the same turning order.
static func _same(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	for r: int in 3:
		var ok := true
		for k: int in 3:
			ok = ok and a[k].distance_to(b[(k + r) % 3]) < EPS
		if ok:
			return true
	return false


func _check_mirror(tris: Array[PackedVector3Array], box_tris: Array[PackedVector3Array]) -> void:
	var front := _winding(box_tris[0])
	var one_winding := front != 0.0
	for b: PackedVector3Array in box_tris:
		one_winding = one_winding and _winding(b) == front
	_check.call(one_winding, "the box's 12 triangles share one winding")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var missed := 0
	var off_box := 0
	var unflipped := 0
	for i: int in CASES:
		var q := Quaternion(rng.randfn(), rng.randfn(), rng.randfn(), rng.randfn())
		var axes := Basis(q.normalized())
		var centre := Vector3(
			rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0), rng.randf_range(-20.0, -0.3)
		)
		var ortho := i % 2 == 1
		var to_eye := Vector3.BACK if ortho else -centre
		var drawn: Array[Vector3] = []
		for t: PackedVector3Array in tris:
			var m := mirror(t, axes, to_eye, true)
			drawn.append(m[3].round())
			off_box += 0 if _on_box(m, front) else 1
			unflipped += 0 if _on_box(mirror(t, axes, to_eye, false), front) else 1
		for n: Vector3 in SIDES:
			var eye := Vector3.BACK if ortho else -(centre + axes * (n * SIZE * 0.5))
			if (axes * n).dot(eye) > 0.0 and not drawn.has(n):
				missed += 1
	_check.call(
		missed == 0,
		(
			"every face the eye sees is drawn, %d cube turns and eye places (%d missed)"
			% [CASES, missed]
		)
	)
	_check.call(
		off_box == 0, "every drawn triangle is a box face's, front side out (%d not)" % off_box
	)
	_check.call(
		unflipped > 0,
		"the check bites: without the in-plane flip %d triangles turn inside out" % unflipped
	)


## The shader's mirror (three_faces_mirror() in voxel_three_faces.gdshaderinc) of one
## triangle; axes: the cube's axes as the eye sees them; flip: the in-plane flip that keeps the
## winding.
static func mirror(
	t: PackedVector3Array, axes: Basis, to_eye: Vector3, flip: bool
) -> PackedVector3Array:
	var s := Vector3(_side(axes.x, to_eye), _side(axes.y, to_eye), _side(axes.z, to_eye))
	var n := t[3] * s
	var out := PackedVector3Array()
	for k: int in 3:
		var p := t[k] * s
		if flip and s.x * s.y * s.z < 0.0:
			if absf(n.x) > 0.5:
				p.y = -p.y
			elif absf(n.y) > 0.5:
				p.z = -p.z
			else:
				p.x = -p.x
		out.append(p)
	out.append(n)
	return out


static func _side(axis: Vector3, to_eye: Vector3) -> float:
	return -1.0 if axis.dot(to_eye) < 0.0 else 1.0


## Which way a triangle turns about its normal (0: no area).
static func _winding(t: PackedVector3Array) -> float:
	return signf(t[3].dot((t[1] - t[0]).cross(t[2] - t[0])))


## Each corner is a corner of the cube on the face the normal names, turning as the box's do.
static func _on_box(t: PackedVector3Array, front: float) -> bool:
	var half := SIZE * 0.5
	for k: int in 3:
		var p := t[k]
		if absf(p.dot(t[3]) - half) > EPS:
			return false
		if not p.abs().is_equal_approx(Vector3.ONE * half):
			return false
	return _winding(t) == front


## The skin's cube node with the flag set to `on` (baby stage).
func _skin(on: bool) -> void:
	var opt := Content.section("render_opt")
	var was: Variant = opt.get("kaiju_three_faces", null)
	opt["kaiju_three_faces"] = on
	var def: Dictionary = Content.species_def("reptilian")
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, "baby")
	_root.add_child(kaiju)
	var skin: VoxelSkin = kaiju.find_children("VoxelSkin", "VoxelSkin", true, false)[0]
	var cubes: MultiMeshInstance3D = null
	for n: Node in skin.get_children():
		if n is MultiMeshInstance3D:
			cubes = n
	var mesh := cubes.multimesh.mesh
	var drawn: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var corners := drawn.size()
	var lit: Variant = (cubes.material_override as ShaderMaterial).get_shader_parameter(
		"three_faces"
	)
	if on:
		_check.call(
			corners == 12 and lit == true,
			(
				"flag on: the skin draws three-face cubes (%d corners) and tells the shader (%s)"
				% [corners, lit]
			)
		)
		_check.call(
			mesh.get_aabb().is_equal_approx(_box_aabb),
			(
				"flag on: the three faces span the box's cube (%s, the box %s)"
				% [mesh.get_aabb(), _box_aabb]
			)
		)
	else:
		_box_aabb = mesh.get_aabb()
		_check.call(
			corners == 24 and lit != true,
			"flag off: the skin draws the box (%d corners), three_faces off" % corners
		)
	if was == null:
		opt.erase("kaiju_three_faces")
	else:
		opt["kaiju_three_faces"] = was
	kaiju.queue_free()
	await _root.get_tree().process_frame
