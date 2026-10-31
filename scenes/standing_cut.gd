class_name StandingCut
extends RefCounted
## Cuts the drawn bolt's lines at the first chunk the sim left standing (BoltRig.wall_cut), so the
## breath shows only where the city broke. Presentation only.


## `lines`, each up to the last sample (every `step`) before one inside a chunk still standing
## (none where it starts inside one): the breath draws only where the sim broke the city
## (director 2026-10-31; tools/capture/capture_breath.gd --audit=1 checks it frame by frame). The
## buildings near (`near_line(lo, hi)`) are found once, over the box round every line.
static func cut(
	lines: Array[PackedVector3Array], near_line: Callable, step: float
) -> Array[PackedVector3Array]:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for line: PackedVector3Array in lines:
		for p: Vector3 in line:
			lo = lo.min(p)
			hi = hi.max(p)
	var near: Array[RampageSim.Building] = near_line.call(lo, hi)
	if near.is_empty():
		return lines
	var grid := {}  # Vector2i ground cell -> the near buildings over it
	for b: RampageSim.Building in near:
		var x0 := b.x - b.w * 0.5
		var z0 := b.z - b.d * 0.5
		for gx: int in range(floori(x0), ceili(x0 + b.w)):
			for gz: int in range(floori(z0), ceili(z0 + b.d)):
				var key := Vector2i(gx, gz)
				if not grid.has(key):
					grid[key] = []
				var over: Array = grid[key]
				over.append(b)
	var out: Array[PackedVector3Array] = []
	for line: PackedVector3Array in lines:
		out.append(_cut_line(grid, line, step))
	return out


static func _cut_line(
	grid: Dictionary, line: PackedVector3Array, step: float
) -> PackedVector3Array:
	if line.size() < 2:
		return line
	if _standing(grid, line[0]):  # a chain hop off a cut line's end, inside the wall
		return PackedVector3Array()
	var out := PackedVector3Array([line[0]])
	for k: int in range(1, line.size()):
		var a := line[k - 1]
		var seg := line[k] - a
		var n := maxi(1, ceili(seg.length() / step))
		for j: int in range(1, n + 1):
			if _standing(grid, a + seg * (float(j) / n)):
				out.append(a + seg * (float(j - 1) / n))
				return out
		out.append(line[k])
	return out


## Whether `p` lies inside a chunk still standing of a building `grid` has over its ground cell.
static func _standing(grid: Dictionary, p: Vector3) -> bool:
	var key := Vector2i(floori(p.x), floori(p.z))
	if not grid.has(key):
		return false
	var over: Array = grid[key]
	for b: RampageSim.Building in over:
		var lx := p.x - (b.x - b.w * 0.5)
		var lz := p.z - (b.z - b.d * 0.5)
		var ly := p.y - b.base
		if lx < 0.0 or lz < 0.0 or ly < 0.0 or lx >= b.w or lz >= b.d or ly >= b.height:
			continue
		if b.frame.alive(Vector3i(floori(lx), floori(ly), floori(lz))):
			return true
	return false
