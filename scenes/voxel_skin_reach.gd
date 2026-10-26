class_name VoxelSkinReach
extends RefCounted
## Render plan item 2: a kaiju skin's bounding box from its pose (VoxelSkin owns one). The cube
## shader moves every vertex (voxel_skin.gdshader), so the engine's box for it must be conservative;
## a fixed 24 m box makes the engine draw the whole body, 4 M triangles, into every shadow slice
## that touches it. This keeps a tight one instead, and it is exact, not an estimate:
##  - per bone, measured once from the rest pose: the box round every cube (corner included) or
##    filler vertex that follows the bone, with a weight above 0;
##  - posed, that box sits inside the box of its transform (exact for any matrix);
##  - a blended point is a mix of such points (weights sum to 1), so it lies in the box round all
##    of them; a cube's corners add at most the corner reach, which is in the rest box.
## Presentation only.

## Per bone: the rest-space box round what follows it; low is INF for a bone nothing follows.
var lows := PackedVector3Array()
var highs := PackedVector3Array()
var _low := Vector3.INF
var _high := -Vector3.INF


func _init(bone_count: int) -> void:
	lows.resize(bone_count)
	highs.resize(bone_count)
	lows.fill(Vector3.INF)
	highs.fill(-Vector3.INF)


## From the .vskin's cube block: cells cubes of voxel size, each reaching corner past its centre.
func measure_cubes(raw: PackedByteArray, cells: int, voxel: float, corner: float) -> void:
	var at := VoxelSkin.HEADER_BYTES
	for i: int in cells:
		var cell := Vector3(raw.decode_s16(at), raw.decode_s16(at + 2), raw.decode_s16(at + 4))
		var centre := (cell + VoxelSkin.HALF_UP) * voxel
		var w0 := raw[at + 13]
		var w1 := raw[at + 14]
		if w0 > 0:
			_grow(raw[at + 10], centre, corner)
		if w1 > 0:
			_grow(raw[at + 11], centre, corner)
		if w0 + w1 < 255:
			_grow(raw[at + 12], centre, corner)
		at += 15


## From the filler's vertices (a point has no corner): positions, CUSTOM0 (bones 0-2, weight 0)
## and CUSTOM1 (weights 1-2), as VoxelSkin builds them.
func measure_fill(
	pos: PackedVector3Array, custom0: PackedFloat32Array, custom1: PackedFloat32Array
) -> void:
	for i: int in pos.size():
		if custom0[i * 4 + 3] > 0.0:
			_grow(int(custom0[i * 4] + 0.5), pos[i], 0.0)
		if custom1[i * 4] > 0.0:
			_grow(int(custom0[i * 4 + 1] + 0.5), pos[i], 0.0)
		if custom1[i * 4 + 1] > 0.0:
			_grow(int(custom0[i * 4 + 2] + 0.5), pos[i], 0.0)


## Starts a frame's box.
func begin() -> void:
	_low = Vector3.INF
	_high = -Vector3.INF


## Adds bone i, posed by t (the matrix the shaders get: rest space to the skin's space): the box
## of its rest box under t, exact for any matrix (half-sizes from the absolute basis).
func add(i: int, t: Transform3D) -> void:
	if lows[i].x > highs[i].x:
		return
	var half := (highs[i] - lows[i]) * 0.5
	var b := t.basis
	var reach := Vector3(
		absf(b.x.x) * half.x + absf(b.y.x) * half.y + absf(b.z.x) * half.z,
		absf(b.x.y) * half.x + absf(b.y.y) * half.y + absf(b.z.y) * half.z,
		absf(b.x.z) * half.x + absf(b.y.z) * half.y + absf(b.z.z) * half.z
	)
	var centre := t * ((highs[i] + lows[i]) * 0.5)
	_low = _low.min(centre - reach)
	_high = _high.max(centre + reach)


## True once a bone has been added this frame.
func has_box() -> bool:
	return _low.x <= _high.x


## The frame's box, grown about its centre by slack (1 = exact).
func box(slack: float) -> AABB:
	var half := (_high - _low) * 0.5 * slack
	return AABB((_low + _high) * 0.5 - half, half * 2.0)


func _grow(bone: int, point: Vector3, reach: float) -> void:
	lows[bone] = lows[bone].min(point - Vector3.ONE * reach)
	highs[bone] = highs[bone].max(point + Vector3.ONE * reach)
