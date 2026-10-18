class_name RooftopAim
extends RefCounted
## Where rooftop rifle rounds strike the kaiju (D-063, D-076), presentation only, for
## RooftopView. A round strikes one of the trunk and head bones (TARGETS) nearest its shooter,
## picked at random from the NEAREST few, on one of that bone's own shown voxels facing the
## shooter: a squad on the left hits the left flank, hits spread over the flank's width instead of
## stacking on one column, and a spark always sits on the hide (drawn over everything), never on
## the street. The tracer (depth-tested) vanishes into the hide where it meets it.

## The bones a round may strike: the trunk, neck and head only. Never a limb (an arm hangs in the
## body's shadow, off the silhouette from above) or the tail.
const TARGETS: Array[String] = ["spine0", "spine1", "spine2", "head0", "head1"]
const NEAREST := 3  # a round picks among this many of the TARGETS nearest its shooter
## A voxel faces the shooter when its bearing from the bone (flat) is within this cosine of the
## shooter's.
const FACING := 0.2
const TRIES := 24  # random voxels drawn to find one facing the shooter (bounded cost per round)
const BODY_MIDDLE := 3.0  # an unrigged body is struck this high (per body scale)


## The drawn kaiju's rig under `body`, or null.
static func rig_of(body: Node3D) -> KaijuRig:
	var rig: KaijuRig = null
	if body != null:
		for node: Node in body.find_children("*", "KaijuRig", true, false):
			rig = node as KaijuRig
	return rig


## A strike for at(): a voxel of a bone of `rig` near `muzzle`, on its side facing `muzzle`,
## or {"at": middle} without a rig, where `middle` is the unrigged body's centre.
static func strike(
	rig: KaijuRig, middle: Vector3, muzzle: Vector3, rng: RandomNumberGenerator
) -> Dictionary:
	if rig == null:
		return {"at": middle}
	var near: Array[Array] = []  # [distance squared, bone name]
	for bone_name: String in TARGETS:
		if rig.has_bone(bone_name) and rig.voxels_of(bone_name) != null:
			var centre := rig.bone(bone_name).global_transform * (rig.dir_of(bone_name) * 0.5)
			near.append([centre.distance_squared_to(muzzle), bone_name])
	if near.is_empty():
		return {"at": middle}
	near.sort_custom(func(a: Array, b: Array) -> bool: return Num.f(a[0]) < Num.f(b[0]))
	var pick: String = near[rng.randi_range(0, mini(NEAREST, near.size()) - 1)][1]
	return {"bone": rig.bone(pick), "local": _facing(rig, pick, muzzle, rng)}


## A shown voxel of `bone_name` (its bone-local centre) on the bone's side facing `muzzle`, seen
## flat: up to TRIES drawn at random, else the one of them that faces it most.
static func _facing(
	rig: KaijuRig, bone_name: String, muzzle: Vector3, rng: RandomNumberGenerator
) -> Vector3:
	var cells := rig.voxels_of(bone_name).built_cells
	var size := rig.voxel_size()
	var origin := Vector3(0, size * 0.5, 0) - rig.head_of(bone_name)
	var xform := rig.bone(bone_name).global_transform
	var axis := xform * (rig.dir_of(bone_name) * 0.5)
	var toward := Vector2(muzzle.x - axis.x, muzzle.z - axis.z).normalized()
	var best := rig.dir_of(bone_name) * 0.5
	var best_dot := -INF
	for i: int in mini(TRIES, cells.size()):
		var local := origin + Vector3(cells[rng.randi_range(0, cells.size() - 1)]) * size
		var world := xform * local
		var dot := Vector2(world.x - axis.x, world.z - axis.z).normalized().dot(toward)
		if dot >= FACING:
			return local
		if dot > best_dot:
			best_dot = dot
			best = local
	return best


## Where a strike is now: on its bone as the body moves, or the fixed point it was given
## (Vector3.INF once the bone is gone).
static func at(hit: Dictionary) -> Vector3:
	if hit.has("at"):
		var fixed: Vector3 = hit["at"]
		return fixed
	var node: Variant = hit["bone"]
	if not is_instance_valid(node):
		return Vector3.INF
	var bone: Node3D = node
	var local: Vector3 = hit["local"]
	return bone.global_transform * local
