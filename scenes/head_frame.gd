class_name HeadFrame
extends RefCounted
## Camera A's head room (D-121 review): the kaiju's highest drawn point (a reared head, a snout
## swung toward the camera: the reptilian's head is ~5 body units ahead of its hips) stays at
## least camera.safe_top of the frame below its top edge. When it would ride higher, the aim tilts
## up just enough, critically damped (Damped) over camera.head_rise_s going up and
## camera.head_settle_s coming back, so the aim never jumps (motion critic round 2). The camera
## never moves or zooms for it, so the kaiju's size holds.
## Presentation only.

## How far up the aim is tilted now (radians).
var tilt := 0.0
var _damped := Damped.new()
var _cfg: Dictionary = Content.section("camera")
var _rig: KaijuRig
var _boxes := {}  # bone -> its voxels' box, in the bone's own space


func _init(kaiju: Node3D) -> void:
	var found := kaiju.find_children("*", "KaijuRig", true, false)
	if not found.is_empty():
		_rig = found[0]
		_boxes = boxes_of(_rig)


## Each bone's voxels as a box in the bone's own space (where KaijuRig.attach_voxels puts them):
## rigid per bone, so their corners bound the drawn body tightly (the skinned mesh's bounds are
## deliberately loose).
static func boxes_of(rig: KaijuRig) -> Dictionary:
	var voxels: Dictionary = rig.get("_voxels")
	var heads: Dictionary = rig.get("_head")
	var size: float = rig.get("_voxel")
	var out := {}
	for bone: String in voxels:
		var part: VoxelBuilder = voxels[bone]
		var head: Vector3 = heads[bone]
		var box := AABB()
		var first := true
		for cell: Vector3i in part.cells:
			var c := AABB(Vector3(cell) * size - head, Vector3.ONE * size)
			box = c if first else box.merge(c)
			first = false
		if not first:
			out[bone] = box
	return out


## The corners of every bone's box in the world now (empty for an unrigged body).
func points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for bone: String in _boxes:
		var box: AABB = _boxes[bone]
		var at := _rig.bone(bone).global_transform
		for i: int in 8:
			out.append(at * box.get_endpoint(i))
	return out


## The drawn head's box in the world now: its skull and jaw bones' voxels (an empty AABB for an
## unrigged body). The run intro frames it (RunIntro.shot).
func head_box() -> AABB:
	var points := PackedVector3Array()
	for bone: String in _boxes:
		if bone == "head1" or bone == "jaw":  # the skull and jaw, not the neck (head0)
			var box: AABB = _boxes[bone]
			var at := _rig.bone(bone).global_transform
			for i: int in 8:
				points.append(at * box.get_endpoint(i))
	var out := AABB(points[0], Vector3.ZERO) if not points.is_empty() else AABB()
	for p: Vector3 in points:
		out = out.expand(p)
	return out


## Where a camera at `eye` looking at `look` should look instead, so the highest drawn point sits
## at least safe_top below the frame's top. `view` is (vertical fov in degrees, the camera shake's
## pitch in radians, up positive): the shake is applied after the aim, so it counts, and a shake
## nodding the view down does not push the head into the margin.
func aim(eye: Vector3, look: Vector3, view: Vector2, delta: float) -> Vector3:
	var forward := (look - eye).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward)
	var limit := atan((1.0 - 2.0 * Num.f(_cfg["safe_top"])) * tan(deg_to_rad(view.x) * 0.5))
	var need := 0.0
	for p: Vector3 in points():
		var d := p - eye
		var ahead := d.dot(forward)
		if ahead > 0.0:
			need = maxf(need, atan2(d.dot(up), ahead) - limit - view.y)
	var smooth := Num.f(_cfg["head_rise_s"] if need > tilt else _cfg["head_settle_s"])
	tilt = _damped.step(Vector3(need, 0.0, 0.0), smooth, 0.0, delta).x
	return eye + forward.rotated(right, tilt) * eye.distance_to(look)
