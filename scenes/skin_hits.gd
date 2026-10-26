class_name SkinHits
extends RefCounted
## Where a shot meets a skinned kaiju, and the faint wounds it leaves (director 2026-10-25: shot
## impacts must hit the hide, wounds stay as battle wear). The skin's cubes live on a regular grid
## in each bone's rest space (VoxelSkin); a ray is carried into every bone's rest space by that
## bone's current pose and walked through the grid (a 3D DDA), so the hit is on the cube actually
## drawn, at its true face normal, however the body is bent. A wound is a point in rest space, so it
## rides the bone and stays on the same scales through the walk. Presentation only; no sim state.

## Wound points the skin shader reads at most (tuning "fx" "hide_hit" "max_wounds" must not exceed).
const SHADER_CAP := 48
## Longest DDA walk through one bone's grid.
const MAX_STEPS := 600
## A wound weaker than this is not drawn.
const WOUND_FLOOR := 0.02

var voxel := 0.12
## Per bone: cell -> its base colour; and the cells' bounds (min corner, max corner + 1).
var _cells: Array[Dictionary] = []
var _lo: Array[Vector3i] = []
var _hi: Array[Vector3i] = []
## Wounds: x y z in rest space, w strength 0..1 (a ring buffer; the oldest is replaced first).
var _wounds := PackedVector4Array()
var _next := 0
var _max := SHADER_CAP


func setup(bone_count: int, p_voxel: float, max_wounds: int) -> void:
	voxel = p_voxel
	_max = mini(max_wounds, SHADER_CAP)
	_cells.clear()
	_lo.clear()
	_hi.clear()
	for _i: int in bone_count:
		_cells.append({})
		_lo.append(Vector3i(1 << 20, 1 << 20, 1 << 20))
		_hi.append(Vector3i(-(1 << 20), -(1 << 20), -(1 << 20)))
	_wounds.resize(SHADER_CAP)


func add_cell(bone: int, cell: Vector3i, color: Color) -> void:
	if bone >= _cells.size():
		return
	_cells[bone][cell] = color
	_lo[bone] = Vector3i(
		mini(_lo[bone].x, cell.x), mini(_lo[bone].y, cell.y), mini(_lo[bone].z, cell.z)
	)
	_hi[bone] = Vector3i(
		maxi(_hi[bone].x, cell.x + 1), maxi(_hi[bone].y, cell.y + 1), maxi(_hi[bone].z, cell.z + 1)
	)


## The first cube a segment from -> to (world) meets: {} for none, else {t (0..1 along the
## segment), point and normal (world), rest (rest-space point), color (the cube's base colour)}.
## `pose` is VoxelSkin.pose (rest -> rig), `rig_to_world` the rig's global transform.
func cast(
	pose: Array[Projection], rig_to_world: Transform3D, from: Vector3, to: Vector3
) -> Dictionary:
	var best := {}
	var best_t := INF
	for b: int in _cells.size():
		if _cells[b].is_empty() or b >= pose.size():
			continue
		var p := pose[b]
		var full := (
			rig_to_world
			* Transform3D(
				Basis(
					Vector3(p.x.x, p.x.y, p.x.z),
					Vector3(p.y.x, p.y.y, p.y.z),
					Vector3(p.z.x, p.z.y, p.z.z)
				),
				Vector3(p.w.x, p.w.y, p.w.z)
			)
		)
		var inv := full.affine_inverse()
		var hit := _walk(b, inv * from, inv.basis * (to - from))
		if hit.is_empty():
			continue
		var hit_t: float = hit["t"]
		if hit_t >= best_t:
			continue
		best_t = hit_t
		var hit_n: Vector3 = hit["n"]
		var n := (full.basis.orthonormalized() * hit_n).normalized()
		best = {
			"t": best_t,
			"point": from.lerp(to, best_t),
			"normal": n,
			"rest": hit["rest"],
			"color": hit["color"],
			"bone": b,
			"cell": hit["cell"],
		}
	return best


## Clips the segment to one bone's grid box. Returns [t0, t1, entry_axis], or [] when it misses.
func _clip_box(b: int, go: Vector3, gd: Vector3) -> Array:
	var lo := Vector3(_lo[b])
	var hi := Vector3(_hi[b])
	var t0 := 0.0
	var t1 := 1.0
	var entry_axis := -1
	for axis: int in 3:
		if absf(gd[axis]) < 1e-9:
			if go[axis] < lo[axis] or go[axis] > hi[axis]:
				return []
			continue
		var ta := (lo[axis] - go[axis]) / gd[axis]
		var tb := (hi[axis] - go[axis]) / gd[axis]
		if minf(ta, tb) > t0:
			t0 = minf(ta, tb)
			entry_axis = axis
		t1 = minf(t1, maxf(ta, tb))
	if t0 > t1:
		return []
	return [t0, t1, entry_axis]


## The t at which the ray first crosses a cell edge on each axis (INF where it does not move).
func _next_edges(go: Vector3, gd: Vector3, cell: Vector3i, step: Vector3i) -> Vector3:
	var next := Vector3(INF, INF, INF)
	for axis: int in 3:
		if step[axis] != 0:
			var edge: float = cell[axis] + (1 if step[axis] > 0 else 0)
			next[axis] = (edge - go[axis]) / gd[axis]
	return next


## One hit of _walk: `at_g` is the point in grid units, back in the bone's rest space as "rest".
func _hit_record(at_g: Vector3, t: float, normal: Vector3, cell: Vector3i) -> Dictionary:
	return {
		"t": t,
		"n": normal,
		"rest": Vector3((at_g.x - 0.5) * voxel, at_g.y * voxel, (at_g.z - 0.5) * voxel),
		"cell": cell,
	}


## The face normal of the box side the segment came in through (zero when it started inside).
static func _entry_normal(entry_axis: int, gd: Vector3) -> Vector3:
	var normal := Vector3.ZERO
	if entry_axis >= 0:
		normal[entry_axis] = -signf(gd[entry_axis])
	return normal


## Walks one bone's grid. o, d in the bone's rest space (d spans the whole segment, t 0..1).
func _walk(b: int, o: Vector3, d: Vector3) -> Dictionary:
	# Grid units: a cube spans x,z in [c - 0.5, c + 0.5] voxels and y in [c, c + 1].
	var go := Vector3(o.x / voxel + 0.5, o.y / voxel, o.z / voxel + 0.5)
	var gd := d / voxel
	var clip := _clip_box(b, go, gd)
	if clip.is_empty():
		return {}
	var t0: float = clip[0]
	var t1: float = clip[1]
	var entry_axis: int = clip[2]
	var cell := Vector3i((go + gd * (t0 + 1e-5)).floor())
	var step := Vector3i(int(signf(gd.x)), int(signf(gd.y)), int(signf(gd.z)))
	var next := _next_edges(go, gd, cell, step)
	var delta := Vector3(INF, INF, INF)
	for axis: int in 3:
		if step[axis] != 0:
			delta[axis] = 1.0 / absf(gd[axis])
	var t := t0
	var normal := _entry_normal(entry_axis, gd)
	for _i: int in MAX_STEPS:
		if _cells[b].has(cell):
			if normal == Vector3.ZERO:
				normal = -d.normalized()
			var hit := _hit_record(go + gd * t, t, normal, cell)
			hit["color"] = _cells[b][cell]
			return hit
		var axis := 0
		if next.y < next.x:
			axis = 1
		if next.z < next[axis]:
			axis = 2
		t = next[axis]
		if t > t1:
			return {}
		next[axis] += delta[axis]
		cell[axis] += step[axis]
		normal = Vector3.ZERO
		normal[axis] = -float(step[axis])
	return {}


## True if any cube within `reach` cells of `cell` on that bone satisfies `test(colour)`.
func any_near(bone: int, cell: Vector3i, reach: int, test: Callable) -> bool:
	var cells := _cells[bone]
	for x: int in range(-reach, reach + 1):
		for y: int in range(-reach, reach + 1):
			for z: int in range(-reach, reach + 1):
				var c := cell + Vector3i(x, y, z)
				if cells.has(c) and test.call(cells[c]):
					return true
	return false


# --- wounds ---


## Records a wound at a rest-space point, replacing the oldest when the buffer is full.
func add_wound(rest: Vector3, strength: float) -> void:
	_wounds[_next] = Vector4(rest.x, rest.y, rest.z, strength)
	_next = (_next + 1) % _max


## Fades every wound by `delta` seconds of a `lifetime`-second wound.
func age(delta: float, lifetime: float) -> void:
	var fade := delta / maxf(lifetime, 0.001)
	for i: int in _max:
		var w := _wounds[i]
		if w.w > 0.0:
			w.w = maxf(0.0, w.w - fade)
			_wounds[i] = w


## How many wounds still show.
func live() -> int:
	var n := 0
	for i: int in _max:
		if _wounds[i].w > WOUND_FLOOR:
			n += 1
	return n


func wounds() -> PackedVector4Array:
	return _wounds
