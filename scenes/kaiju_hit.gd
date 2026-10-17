class_name KaijuHit
extends RefCounted
## Where a round fired at a rigged voxel kaiju strikes (D-063 rooftop rifles): the first of its
## voxels that the ray from the shooter meets, so a tracer ends and its spark burns on the body's
## visible surface, never on the street beside it. The rig keeps each bone's own voxels as
## MultiMeshes under the bone that follow it (a split head or a joint band adds more); the drawn
## VoxelSkin is built from the same voxels. Presentation only.

const SAMPLE := 2  # every this-many'th voxel of a bone is tested: plenty at game scale
const REACH := 0.8  # a voxel counts as hit when the ray passes within this many voxel sizes of it

static var _centres: Dictionary = {}  # MultiMesh -> PackedVector3Array (local, sampled)


## The first voxel on the ray from `from` toward `toward`, as {"node": its bone's MultiMesh
## node, "local": its centre there}, so a tracer and its spark follow the body as it moves (the
## centre, not the near face: from the game camera the face toward a shooter can lie just off the
## body's outline). A ray that slips between the tested voxels strikes the voxel nearest
## `toward` instead, so a round always lands on the body; {} only for a rig with no voxels.
static func strike(rig: KaijuRig, from: Vector3, toward: Vector3) -> Dictionary:
	var dir := (toward - from).normalized()
	var size := rig.voxel_size()
	var best_t := INF
	var best := {}
	var nodes := parts(rig)
	for mmi: MultiMeshInstance3D in nodes:
		var xf := mmi.global_transform
		var inv := xf.affine_inverse()
		var o := inv * from
		var d := inv.basis * dir
		var per_unit := d.length()  # local units per world unit
		d /= per_unit
		if mmi.multimesh.get_aabb().grow(size).intersects_ray(o, d) == null:
			continue
		for c: Vector3 in centres(mmi.multimesh):
			var t := (c - o).dot(d)
			if t <= 0.0 or t / per_unit >= best_t:
				continue
			if (o + d * t).distance_to(c) <= size * REACH:
				best_t = t / per_unit
				best = {"node": mmi, "local": c}
	return best if not best.is_empty() else _nearest(nodes, toward, size)


## Where a strike is now in the world (Vector3.INF once its bone's voxels are gone).
static func where(hit: Dictionary) -> Vector3:
	var node: Variant = hit.get("node")
	if not is_instance_valid(node):
		return Vector3.INF
	var mmi: MultiMeshInstance3D = node
	var local: Vector3 = hit["local"]
	return mmi.global_transform * local


## The voxel nearest `at`, among the parts whose bounds come within a voxel of it (all of them
## if none do).
static func _nearest(nodes: Array[MultiMeshInstance3D], at: Vector3, size: float) -> Dictionary:
	var close: Array[MultiMeshInstance3D] = []
	for mmi: MultiMeshInstance3D in nodes:
		if mmi.multimesh.get_aabb().grow(size * 4.0).has_point(
			mmi.global_transform.affine_inverse() * at
		):
			close.append(mmi)
	var best_d := INF
	var best := {}
	for mmi: MultiMeshInstance3D in close if not close.is_empty() else nodes:
		var aim := mmi.global_transform.affine_inverse() * at
		for c: Vector3 in centres(mmi.multimesh):
			var off := c.distance_squared_to(aim)
			if off < best_d:
				best_d = off
				best = {"node": mmi, "local": c}
	return best


## Every voxel MultiMesh of the rig's bones (not the VoxelSkin's, which the shader moves).
static func parts(rig: KaijuRig) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for node: Node in rig.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.instance_count == 0:
			continue
		if not mmi.get_parent() is VoxelSkin:
			out.append(mmi)
	return out


## A bone's voxel centres in its own space (every SAMPLE'th), cached per MultiMesh.
static func centres(mm: MultiMesh) -> PackedVector3Array:
	if not _centres.has(mm):
		var out := PackedVector3Array()
		for i: int in range(0, mm.instance_count, SAMPLE):
			out.append(mm.get_instance_transform(i).origin)
		_centres[mm] = out
	var cached: PackedVector3Array = _centres[mm]
	return cached
