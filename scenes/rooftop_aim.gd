class_name RooftopAim
extends RefCounted
## Where rooftop rifle rounds strike the kaiju (D-063, D-076), presentation only, for
## RooftopView. A round strikes one of the upper-body bones (TARGETS) nearest its shooter, picked
## at random from the NEAREST few, at a random point along that bone, so a squad's hits spread
## over the flank and back instead of stacking on one pixel. The body always surrounds a point
## along a bone, so the spark there (drawn over everything) never sits on the street, and the
## tracer (depth-tested) vanishes into the hide where it meets it.

## The bones a round may strike: the upper body only (trunk, neck, head, upper arms), never a leg
## or the tail.
const TARGETS: Array[String] = ["spine0", "spine1", "spine2", "head0", "head1", "arm_l0", "arm_r0"]
const NEAREST := 3  # a round picks among this many of the TARGETS nearest its shooter
const ALONG := Vector2(0.2, 0.8)  # and strikes this far along the bone (shares of its length)
const BODY_MIDDLE := 3.0  # an unrigged body is struck this high (per body scale)


## The drawn kaiju's rig under `body`, or null.
static func rig_of(body: Node3D) -> KaijuRig:
	var rig: KaijuRig = null
	if body != null:
		for node: Node in body.find_children("*", "KaijuRig", true, false):
			rig = node as KaijuRig
	return rig


## A strike for at(): a point held to a bone of `rig` near `muzzle`, or {"at": middle} without a
## rig, where `middle` is the unrigged body's centre.
static func strike(
	rig: KaijuRig, middle: Vector3, muzzle: Vector3, rng: RandomNumberGenerator
) -> Dictionary:
	if rig == null:
		return {"at": middle}
	var near: Array[Array] = []  # [distance squared, bone name]
	for bone_name: String in TARGETS:
		if rig.has_bone(bone_name):
			var centre := rig.bone(bone_name).global_transform * (rig.dir_of(bone_name) * 0.5)
			near.append([centre.distance_squared_to(muzzle), bone_name])
	if near.is_empty():
		return {"at": middle}
	near.sort_custom(func(a: Array, b: Array) -> bool: return Num.f(a[0]) < Num.f(b[0]))
	var pick: String = near[rng.randi_range(0, mini(NEAREST, near.size()) - 1)][1]
	var along := rng.randf_range(ALONG.x, ALONG.y)
	return {"bone": rig.bone(pick), "local": rig.dir_of(pick) * along}


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
