class_name StreetLod
extends RefCounted
## How much work StreetLife spends on each person a frame (D-254: the 1.5x city has twice the
## people, and every one walked and was redrawn every frame). A person farther than "far_radius"
## m from both the kaiju and the camera steps once every "far_every" frames by that many frames'
## time (StreetLife._walk), so the crowd keeps its pace; nobody that far can be startled (the
## panic radius is smaller). A person wholly outside the camera's frustum, widened by
## "view_margin" m (shake and a quick turn), is not drawn this frame; one inside it always is,
## so nothing pops in. Presentation only.

## The camera's side planes in Camera3D.get_frustum() order (near, far, left, top, right,
## bottom): the four sides bound a one-sided cone, so they alone decide what is in view.
const SIDES: Array[int] = [2, 3, 4, 5]
## A person is tested as a column from the ground to this height (m), this wide.
const BODY := Vector2(1.8, 0.5)

var far_every := 1
var far2 := INF
var tick := 0
var cam := Vector2.ZERO
var _margin := 0.0
## Each side plane as a ground test: a person at (x, z) is out of view when
## a*x + c*z + e > 0 for any plane (packed a, c, e; empty: no camera, draw everyone).
var _sides := PackedFloat64Array()


func _init(cfg: Dictionary) -> void:
	far_every = maxi(1, Num.i(cfg["far_every"]))
	far2 = Num.f(cfg["far_radius"]) * Num.f(cfg["far_radius"])
	_margin = Num.f(cfg["view_margin"])


## Once a frame, before the walk: where the camera is and what it sees.
func update(camera: Camera3D) -> void:
	tick += 1
	_sides.clear()
	if camera == null or not camera.is_inside_tree():
		return
	var at := camera.global_position
	cam = Vector2(at.x, at.z)
	var ahead := at - camera.global_basis.z * 10.0
	var frustum := camera.get_frustum()
	for n: int in SIDES:
		var plane: Plane = frustum[n]
		if plane.distance_to(ahead) > 0.0:
			plane = -plane  # facing out of the view
		# The column's nearest point to the plane is at its foot or its head.
		var lift := minf(0.0, plane.normal.y * BODY.x)
		_sides.append(plane.normal.x)
		_sides.append(plane.normal.z)
		_sides.append(lift - plane.d - BODY.y - _margin)


## Draws every person in view into `mms` (one MultiMesh per outfit and pose), at most
## `capacity` each; `counts` is scratch, one per MultiMesh.
func draw(life: StreetLife, mms: Array[MultiMesh], counts: PackedInt32Array, capacity: int) -> void:
	counts.fill(0)
	var pos := life.pos
	var heading := life.heading
	var side := life.side
	var outfit := life.outfit
	var s := _sides
	var culled := not s.is_empty()
	for i: int in pos.size():
		var p := pos[i]
		if (
			culled
			and (
				s[0] * p.x + s[1] * p.y + s[2] > 0.0
				or s[3] * p.x + s[4] * p.y + s[5] > 0.0
				or s[6] * p.x + s[7] * p.y + s[8] > 0.0
				or s[9] * p.x + s[10] * p.y + s[11] > 0.0
			)
		):
			continue
		var bucket := outfit[i] * VoxelPerson.POSES + life.pose(i)
		if counts[bucket] >= capacity:
			continue
		var look := heading[i]
		var at := p + Vector2(-look.y, look.x) * side[i]
		var basis := Basis(Vector3.UP, atan2(-look.x, -look.y))
		var place := Transform3D(basis, Vector3(at.x, 0, at.y))
		mms[bucket].set_instance_transform(counts[bucket], place)
		counts[bucket] += 1
	for i: int in mms.size():
		mms[i].visible_instance_count = counts[i]
