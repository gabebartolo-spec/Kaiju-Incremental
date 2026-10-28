class_name StreetDraw
extends RefCounted
## StreetLife's people on screen with render_opt.people_buffers and the native extension (render
## plan item 7): every civilian is placed in one native call a frame (KaijuBuckets.add_people,
## the same math as StreetLife._draw_people, bit for bit) and each outfit-and-pose MultiMesh gets
## one buffer with a fixed culling box; the few officers (Police sets their pose) follow one at a
## time. Officers only ever wear the COP outfit and civilians never do, so each MultiMesh still
## holds its people in array order. Without the extension StreetLife draws everyone itself.
## Presentation only.

const SLOT_STEP := 256  # the fewest people a buffered MultiMesh holds

var buckets: MultiMeshBuckets
## The most people one MultiMesh shows (StreetLife's capacity).
var capacity: int
var _s: StreetLife


## One MultiMesh per outfit and pose, VoxelPerson's order, each under `holder` showing nobody.
static func pools(holder: Node3D, voxel: float, count: int) -> Array[MultiMesh]:
	var out: Array[MultiMesh] = []
	for dress: int in VoxelPerson.OUTFITS.size():
		for pose: int in VoxelPerson.POSES:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = VoxelPerson.mesh(dress, pose, voxel)
			mm.instance_count = count
			mm.visible_instance_count = 0
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			holder.add_child(mmi)
			out.append(mm)
	return out


## Whether this build can draw the street natively (the extension is loaded).
static func available() -> bool:
	return ClassDB.class_exists("KaijuBuckets")


## mms: StreetLife's pools(); bounds: the pavement corners every person walks between.
func _init(street: StreetLife, mms: Array[MultiMesh], bounds: PackedVector2Array, cap: int) -> void:
	_s = street
	capacity = cap
	buckets = MultiMeshBuckets.new(mms, true, SLOT_STEP)
	MultiMeshBuckets.bound(mms, bounds)  # culled by the pavements, not a box rebuilt every frame
	buckets.native.call(
		"set_poses",
		VoxelPerson.POSES,
		VoxelPerson.Pose.WALK_A,
		VoxelPerson.Pose.RUN_A,
		StreetLife.WALK_HZ,
		StreetLife.RUN_HZ
	)


## This frame's people; clock: StreetLife's clock, which their strides follow.
func frame(clock: float) -> void:
	var s := _s
	buckets.begin()
	buckets.counts = buckets.native.call(
		"add_people",
		s.pos,
		s.heading,
		s.side,
		s.outfit,
		s.phase,
		s.pinned_until,
		s.fleeing,
		s.cop,
		clock,
		capacity
	)
	var cop := s.cop
	var i := cop.find(1)
	while i >= 0:
		var bucket := s.outfit[i] * VoxelPerson.POSES + s.pose(i)
		if buckets.counts[bucket] < capacity:
			var look := s.heading[i]
			var at := s.pos[i] + Vector2(-look.y, look.x) * s.side[i]
			var basis := Basis(Vector3.UP, atan2(-look.x, -look.y))
			buckets.add(bucket, Transform3D(basis, Vector3(at.x, 0, at.y)))
		i = cop.find(1, i + 1)
	buckets.commit()
