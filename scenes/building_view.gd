class_name BuildingView
extends Node3D
## One building's fine voxels, grouped by the sim's structural chunks (one sim unit, one
## floor). Broken chunks are hidden; a falling part is lifted out into its own piece, which
## topples over its edge (accelerating like a real fall) or drops straight down.

const HIDDEN := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

var b: RampageSim.Building
var voxels: BuildingVoxels
var _mm: MultiMesh
var _by_chunk: Dictionary = {}


func _init(p_building: RampageSim.Building, base: Color) -> void:
	b = p_building
	voxels = BuildingVoxels.new(b, base)
	voxels.vox.salt = b.style
	var mmi := voxels.vox.build(
		voxels.palette, BuildingVoxels.VOXEL, Look.value("window_glow"), voxels.origin()
	)
	_mm = mmi.multimesh
	add_child(mmi)
	var res := BuildingVoxels.RES
	for i: int in voxels.vox.built_cells.size():
		var cell := voxels.vox.built_cells[i]
		var chunk := Vector3i(
			clampi(floori(float(cell.x) / res), 0, b.w - 1),
			clampi(floori(float(cell.y) / res), 0, b.height - 1),
			clampi(floori(float(cell.z) / res), 0, b.d - 1)
		)
		if not _by_chunk.has(chunk):
			_by_chunk[chunk] = PackedInt32Array()
		var list: PackedInt32Array = _by_chunk[chunk]
		list.append(i)
		_by_chunk[chunk] = list


## Hides the voxels of these chunks; returns their world positions and colours (for debris).
func hide_chunks(cells: Array[Vector3i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for chunk: Vector3i in cells:
		var list: PackedInt32Array = _by_chunk.get(chunk, PackedInt32Array())
		for i: int in list:
			var t := _mm.get_instance_transform(i)
			if t.basis == HIDDEN:
				continue
			out.append({"pos": t.origin, "color": _mm.get_instance_color(i)})
			_mm.set_instance_transform(i, Transform3D(HIDDEN, t.origin))
	return out


## Bites ragged edges into the chunks around a hole, so walls look chewed rather than cut
## along the chunk grid: voxels of standing neighbours within a voxel or two of the broken
## chunks vanish at random. Cosmetic only; the sim's chunks are unchanged.
func chip(broken: Array[Vector3i], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var res := BuildingVoxels.RES
	var gone := {}
	for c: Vector3i in broken:
		gone[c] = true
	var out: Array[Dictionary] = []
	var seen := {}
	for c: Vector3i in broken:
		var lo := c * res
		var hi := lo + Vector3i(res - 1, res - 1, res - 1)
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				for dz: int in range(-1, 2):
					var n := c + Vector3i(dx, dy, dz)
					if gone.has(n) or seen.has(n) or not _by_chunk.has(n):
						continue
					seen[n] = true
					var list: PackedInt32Array = _by_chunk[n]
					for i: int in list:
						var cell := voxels.vox.built_cells[i]
						var far := maxi(
							maxi(
								maxi(lo.x - cell.x, cell.x - hi.x),
								maxi(lo.y - cell.y, cell.y - hi.y)
							),
							maxi(lo.z - cell.z, cell.z - hi.z)
						)
						var chance := 0.4 if far <= 1 else (0.08 if far == 2 else 0.0)
						if rng.randf() < chance:
							var t := _mm.get_instance_transform(i)
							if t.basis != HIDDEN:
								out.append({"pos": t.origin, "color": _mm.get_instance_color(i)})
								_mm.set_instance_transform(i, Transform3D(HIDDEN, t.origin))
	return out


## Lifts these chunks out into a separate piece pivoting at `pivot` (world); hides them here.
func lift_piece(cells: Array[Vector3i], pivot: Vector3) -> Node3D:
	var parts := hide_chunks(cells)
	var piece := Node3D.new()
	piece.position = pivot
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mm.mesh
	mm.instance_count = parts.size()
	for i: int in parts.size():
		var at: Vector3 = parts[i]["pos"]
		mm.set_instance_transform(i, Transform3D(Basis(), at - pivot))
		var color: Color = parts[i]["color"]
		mm.set_instance_color(i, color)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	piece.add_child(mmi)
	piece.set_meta("parts", parts)
	piece.set_meta("pivot", pivot)
	return piece
