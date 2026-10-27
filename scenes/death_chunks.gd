class_name DeathChunks
extends Node3D
## A set of jagged stone chunks in flight as he shatters (DeathView; director 2026-10-27, D-323:
## "Jagged stone chunks"): his voxels' small chunks or the sim's big shards. Each piece is one of
## the baked chunk meshes (assets/death/chunk_*.obj, longest side 1) at its own size, drawn
## through one MultiMesh per mesh with his stone (death_stone.gdshader); it tumbles while it flies
## and comes to lie on its lowest corner, never a box sitting flat. Presentation only.

## Per piece: its mesh (kind), its slot in that mesh's MultiMesh, its size (longest side, world
## units) and how it lies now (a turn, no scale).
var kind := PackedInt32Array()
var slot := PackedInt32Array()
var size := PackedFloat32Array()
var lie: Array[Basis] = []
var _meshes: Array[Mesh]
var _corners: Array[PackedVector3Array]
var _mat: ShaderMaterial
var _multi: Array[MultiMesh] = []
## Pieces that fall on their own (fall): where each is, its velocity (zero once down), its tumble.
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _axis := PackedVector3Array()
var _rate := PackedFloat32Array()


func _init(
	label: String, meshes: Array[Mesh], corners: Array[PackedVector3Array], mat: ShaderMaterial
) -> void:
	name = label
	_meshes = meshes
	_corners = corners
	_mat = mat


## The pieces: each one's mesh, size and starting turn; one MultiMesh per mesh holds them.
func fill(kinds: PackedInt32Array, sizes: PackedFloat32Array, turns: Array[Basis]) -> void:
	kind = kinds
	size = sizes
	lie = turns
	_pos.resize(kind.size())  # packed arrays are values: each resized by name
	_vel.resize(kind.size())
	_axis.resize(kind.size())
	_rate.resize(kind.size())
	var counts := PackedInt32Array()
	counts.resize(_meshes.size())
	for k: int in kind:
		slot.append(counts[k])
		counts[k] += 1
	for m: int in _meshes.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[m]
		mm.instance_count = counts[m]
		var node := MultiMeshInstance3D.new()
		node.name = "Chunk%d" % m
		node.multimesh = mm
		node.material_override = _mat
		add_child(node)
		_multi.append(mm)


## Piece `i`'s instance colour (its own shade in rgb, its hash in alpha: death_stone.gdshader).
func paint(i: int, color: Color) -> void:
	_multi[kind[i]].set_instance_color(slot[i], color)


## Piece `i` drawn at `turn` (no scale) with its middle at `at`.
func place(i: int, turn: Basis, at: Vector3) -> void:
	var scaled := turn.scaled(Vector3.ONE * size[i])
	_multi[kind[i]].set_instance_transform(slot[i], Transform3D(scaled, at))


## How high piece `i`'s middle sits when it lies on the street at `turn`: its lowest corner's depth.
func lift(i: int, turn: Basis) -> float:
	var low := INF
	var up := turn.transposed().y  # the world's up in the chunk's own space
	for c: Vector3 in _corners[kind[i]]:
		low = minf(low, c.dot(up))
	return -low * size[i]


## Piece `i` sets off from `at` at `vel`, tumbling about `spin` (its length the rate, rad/s).
func launch(i: int, at: Vector3, vel: Vector3, spin: Vector3) -> void:
	_pos[i] = at
	_vel[i] = vel
	_axis[i] = spin.normalized()
	_rate[i] = spin.length()
	place(i, lie[i], at)


## One step for the launched pieces: they fly under `gravity`, tumbling, and stop where their
## lowest corner meets the street (they stay: rubble).
func fall(delta: float, gravity: float) -> void:
	for i: int in _pos.size():
		var v := _vel[i]
		if v == Vector3.ZERO:
			continue
		v.y -= gravity * delta
		var p := _pos[i] + v * delta
		var turn := Basis(_axis[i], _rate[i] * delta) * lie[i]
		if p.y <= size[i]:  # near the street: is its lowest corner down?
			var h := lift(i, turn)
			if p.y <= h:
				turn = turn.orthonormalized()
				p.y = h
				v = Vector3.ZERO
		lie[i] = turn
		_pos[i] = p
		_vel[i] = v
		place(i, turn, p)
