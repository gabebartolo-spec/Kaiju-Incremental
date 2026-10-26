class_name VoxelSkinReach
extends RefCounted
## Render plan item 2: a kaiju skin's bounding box from its pose (VoxelSkin owns one). The cube
## shader moves every vertex (voxel_skin.gdshader), so the engine's box for it must be conservative;
## a fixed 24 m box makes the engine draw the whole body, 4 M triangles, into every shadow slice
## that touches it. This keeps a tight one instead, and it is exact, not an estimate:
##  - per bone, measured once from the rest pose: the farthest any cube (corner included) or filler
##    vertex that follows the bone, with a weight above 0, lies from the bone's rest origin;
##  - posed, that sphere sits inside the box of half-sizes radius x length of each row of the bone's
##    matrix, round the posed origin;
##  - a blended point is a mix of such points (weights sum to 1), so it lies in the box round all of
##    them; a cube's corners add at most the corner reach, which is in the radius.
## Presentation only.

## Each bone's rest origin in the skin's space.
var origins := PackedVector3Array()
## Per bone: the reach above, -1 for a bone nothing follows.
var radii := PackedFloat32Array()
var _low := Vector3.INF
var _high := -Vector3.INF


func _init(p_origins: PackedVector3Array) -> void:
	origins = p_origins
	radii.resize(origins.size())
	radii.fill(-1.0)


## From the .vskin's cube block: cells cubes of voxel size, each reaching corner past its centre.
func measure_cubes(raw: PackedByteArray, cells: int, voxel: float, corner: float) -> void:
	var far2 := PackedFloat32Array()
	far2.resize(origins.size())
	far2.fill(-1.0)
	var at := VoxelSkin.HEADER_BYTES
	for i: int in cells:
		var cell := Vector3(raw.decode_s16(at), raw.decode_s16(at + 2), raw.decode_s16(at + 4))
		var centre := (cell + VoxelSkin.HALF_UP) * voxel
		var w0 := raw[at + 13] / 255.0
		var w1 := raw[at + 14] / 255.0
		var b0 := raw[at + 10]
		var b1 := raw[at + 11]
		var b2 := raw[at + 12]
		if w0 > 0.0:
			far2[b0] = maxf(far2[b0], centre.distance_squared_to(origins[b0]))
		if w1 > 0.0:
			far2[b1] = maxf(far2[b1], centre.distance_squared_to(origins[b1]))
		if 1.0 - w0 - w1 > 0.0:
			far2[b2] = maxf(far2[b2], centre.distance_squared_to(origins[b2]))
		at += 15
	for b: int in far2.size():
		if far2[b] >= 0.0:
			radii[b] = maxf(radii[b], sqrt(far2[b]) + corner)


## From the filler's vertices (a point has no corner): positions, CUSTOM0 (bones 0-2, weight 0)
## and CUSTOM1 (weights 1-2), as VoxelSkin builds them.
func measure_fill(
	pos: PackedVector3Array, custom0: PackedFloat32Array, custom1: PackedFloat32Array
) -> void:
	for i: int in pos.size():
		var w0 := custom0[i * 4 + 3]
		var w1 := custom1[i * 4]
		var w2 := custom1[i * 4 + 1]
		var b0 := int(custom0[i * 4] + 0.5)
		var b1 := int(custom0[i * 4 + 1] + 0.5)
		var b2 := int(custom0[i * 4 + 2] + 0.5)
		if w0 > 0.0:
			radii[b0] = maxf(radii[b0], pos[i].distance_to(origins[b0]))
		if w1 > 0.0:
			radii[b1] = maxf(radii[b1], pos[i].distance_to(origins[b1]))
		if w2 > 0.0:
			radii[b2] = maxf(radii[b2], pos[i].distance_to(origins[b2]))


## Starts a frame's box.
func begin() -> void:
	_low = Vector3.INF
	_high = -Vector3.INF


## Adds bone i, posed by t (the matrix the shaders get: rest space to the skin's space).
func add(i: int, t: Transform3D) -> void:
	if radii[i] < 0.0:
		return
	var b := t.basis
	var rows := Vector3(
		Vector3(b.x.x, b.y.x, b.z.x).length(),
		Vector3(b.x.y, b.y.y, b.z.y).length(),
		Vector3(b.x.z, b.y.z, b.z.z).length()
	)
	var reach := rows * radii[i]
	var origin := t * origins[i]
	_low = _low.min(origin - reach)
	_high = _high.max(origin + reach)


## True once a bone has been added this frame.
func has_box() -> bool:
	return _low.x <= _high.x


## The frame's box, grown about its centre by slack (1 = exact).
func box(slack: float) -> AABB:
	var half := (_high - _low) * 0.5 * slack
	return AABB((_low + _high) * 0.5 - half, half * 2.0)
