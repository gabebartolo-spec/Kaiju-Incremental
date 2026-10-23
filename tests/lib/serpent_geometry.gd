extends RefCounted
## Geometry the serpent suite measures with (tests/run_serpent_tests.gd): where the body's bends
## change side, how far the wave's travel is off the head's, points on and off a path.


## Where the bends change side along the body (arc from the head), from the joints' turning.
static func inflections(joints: PackedVector2Array, seg: float) -> PackedFloat32Array:
	var bends := PackedFloat32Array()
	for j: int in range(1, joints.size() - 1):
		bends.append((joints[j - 1] - joints[j]).angle_to(joints[j] - joints[j + 1]))
	var out := PackedFloat32Array()
	for k: int in bends.size() - 1:
		if signf(bends[k]) != signf(bends[k + 1]) and bends[k] != 0.0:
			out.append((k + 1 + bends[k] / (bends[k] - bends[k + 1])) * seg)
	return out


## How far the wave's travel down the body is off the head's travel along its path (share).
static func wave_error(
	before: PackedFloat32Array, after: PackedFloat32Array, travelled: float, length: float
) -> float:
	var worst := 0.0
	var found := false
	for z: float in before:
		if z < 2.0 or z + travelled > length - 2.0:
			continue
		var nearest := INF
		for w: float in after:
			if absf(w - z - travelled) < absf(nearest - z - travelled):
				nearest = w
		worst = maxf(worst, absf(nearest - z - travelled) / travelled)
		found = true
	return worst if found else INF


## The point `s` along a polyline whose vertices sit at `arcs`.
static func on_path(path: PackedVector2Array, arcs: Array[float], s: float) -> Vector2:
	for i: int in range(1, path.size()):
		if arcs[i] >= s:
			var t := (s - arcs[i - 1]) / maxf(arcs[i] - arcs[i - 1], 1e-9)
			return path[i - 1].lerp(path[i], t)
	return path[path.size() - 1]


## The radius of the circle through three joints (INF when they lie in a line).
static func bend_radius(a: Vector2, b: Vector2, c: Vector2) -> float:
	var cross := absf((b - a).cross(c - b))
	if cross < 1e-9:
		return INF
	return a.distance_to(b) * b.distance_to(c) * c.distance_to(a) / (2.0 * cross)


## Distance from `p` to the nearest point of a polyline.
static func off_path(p: Vector2, path: PackedVector2Array) -> float:
	var best := INF
	for i: int in range(1, path.size()):
		best = minf(
			best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, path[i - 1], path[i]))
		)
	return best


## Distance from `p` to a polyline searched from vertex `from` onward (a body walked head to tail
## along a path laid the same way): Vector2(distance, the nearest segment's first vertex).
static func off_path_near(p: Vector2, path: PackedVector2Array, from: int) -> Vector2:
	var best := INF
	var at := from
	for i: int in range(maxi(1, from), path.size()):
		var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, path[i - 1], path[i]))
		if d < best:
			best = d
			at = i - 1
		elif d > best + 2.0:  # walked well past the nearest stretch
			break
	return Vector2(best, at)


## How long the body is drawn along its joints (m, in the ground plane).
static func drawn_length(joints: PackedVector2Array) -> float:
	var total := 0.0
	for j: int in range(1, joints.size()):
		total += joints[j].distance_to(joints[j - 1])
	return total
