extends RefCounted
## Phase B look test (b2-20), never merged: the same voxel models as one smooth surface (naive
## surface nets: one vertex per mixed 2x2x2 block of cells at the middle of its crossing edges, a
## quad per crossing edge, then a few relaxation passes that never move a vertex more than
## MAX_MOVE of a cell). Flat walls stay flat and at the voxel faces; stair-steps and corners round
## off. No new art: only the cells the game already draws.
##
## Load with preload (no class_name: a look test, not a game class).

const MAX_MOVE := 0.4
const AXES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]

var positions := PackedVector3Array()  ## vertex positions in cell units (a cell centre is its integer coordinate)
var normals := PackedVector3Array()
var indices := PackedInt32Array()
## Per vertex, the filled cells of its 2x2x2 block (for colours and skin weights).
var owners: Array = []


## cells: Vector3i -> anything (a key present means filled). relax: smoothing passes.
func build(cells: Dictionary, relax: int) -> void:
	var sum := {}
	var count := {}
	# Pass 1: every (filled, empty) neighbour pair is a crossing edge; its midpoint pulls on the
	# four dual vertices around it.
	var pairs: Array = []
	for cell: Vector3i in cells:
		for axis: int in 3:
			for sign_i: int in [-1, 1]:
				var other: Vector3i = cell + AXES[axis] * sign_i
				if cells.has(other):
					continue
				pairs.append([cell, axis, sign_i])
				var mid := (Vector3(cell) + Vector3(other)) * 0.5
				for d: Vector3i in _duals(cell, other, axis):
					var so: Vector3 = sum.get(d, Vector3.ZERO)
					sum[d] = so + mid
					count[d] = Num.i(count.get(d, 0)) + 1
	var slot := {}
	var own_sets: Array = []
	for d: Vector3i in sum:
		slot[d] = positions.size()
		var total: Vector3 = sum[d]
		positions.append(total / float(Num.i(count[d])))
		var filled: Array[Vector3i] = []
		for dx: int in 2:
			for dy: int in 2:
				for dz: int in 2:
					var c := d + Vector3i(dx, dy, dz)
					if cells.has(c):
						filled.append(c)
		own_sets.append(filled)
	owners = own_sets
	var rest := positions.duplicate()
	# Pass 2: a quad per crossing edge, wound to face away from the filled cell.
	for p: Array in pairs:
		var cell: Vector3i = p[0]
		var axis: int = p[1]
		var sign_i: int = p[2]
		var other: Vector3i = cell + AXES[axis] * sign_i
		var ring := _duals(cell, other, axis)
		var q := PackedInt32Array([slot[ring[0]], slot[ring[1]], slot[ring[2]], slot[ring[3]]])
		var a := rest[q[0]]
		var b := rest[q[1]]
		var c := rest[q[2]]
		var facing := -(b - a).cross(c - a)  # Godot's front face is clockwise
		var out := Vector3(AXES[axis] * sign_i)
		if facing.dot(out) < 0.0:
			q = PackedInt32Array([q[3], q[2], q[1], q[0]])
		indices.append_array(PackedInt32Array([q[0], q[1], q[2], q[0], q[2], q[3]]))
	_relax(rest, relax)
	_normals()


## The four dual cells around the edge between voxel a and its neighbour b along `axis`, in ring order.
func _duals(a: Vector3i, b: Vector3i, axis: int) -> Array[Vector3i]:
	var base := a
	base[axis] = mini(a[axis], b[axis])
	var u := (axis + 1) % 3
	var v := (axis + 2) % 3
	var out: Array[Vector3i] = []
	for corner: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(-1, 0)]:
		var d := base
		d[u] += corner.x
		d[v] += corner.y
		out.append(d)
	return out


func _relax(rest: PackedVector3Array, passes: int) -> void:
	if passes <= 0:
		return
	var nbrs: Array[PackedInt32Array] = []
	nbrs.resize(positions.size())
	for t: int in range(0, indices.size(), 3):
		for k: int in 3:
			var a := indices[t + k]
			var b := indices[t + (k + 1) % 3]
			nbrs[a].append(b)
			nbrs[b].append(a)
	for _pass: int in passes:
		var next := positions.duplicate()
		for i: int in positions.size():
			var list: PackedInt32Array = nbrs[i]
			if list.is_empty():
				continue
			var avg := Vector3.ZERO
			for j: int in list:
				avg += positions[j]
			avg /= float(list.size())
			var moved := positions[i].lerp(avg, 0.6)
			var off := moved - rest[i]
			if off.length() > MAX_MOVE:
				moved = rest[i] + off.normalized() * MAX_MOVE
			next[i] = moved
		positions = next


func _normals() -> void:
	normals = PackedVector3Array()
	normals.resize(positions.size())
	for t: int in range(0, indices.size(), 3):
		var a := positions[indices[t]]
		var b := positions[indices[t + 1]]
		var c := positions[indices[t + 2]]
		var n := -(b - a).cross(c - a)  # area-weighted, outward for clockwise faces
		for k: int in 3:
			normals[indices[t + k]] += n
	for i: int in normals.size():
		normals[i] = normals[i].normalized()
