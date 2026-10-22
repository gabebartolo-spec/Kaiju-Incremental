class_name BoltShape
extends RefCounted
## The geometry of a lightning bolt, pure maths (no nodes), so it replays from its seed and a test
## can check it: a jagged channel by midpoint displacement (recursively split each segment and push
## the new point sideways, halving the push each round), placed between two world points, and the
## fan of ground points a breath's branches strike across the sim's cone. Presentation only.

## Points nearer the cone's apex than this are left alone (their angle from the axis is noise).
const APEX_FREE := 1.5
## Branch ends stay this share of the half angle inside the cone's edge.
const EDGE_MARGIN := 0.97
## Where along its slot a fan end may land: the nearest and farthest share of the cone's reach.
const FAN_NEAR := 0.5
const FAN_FAR := 0.97
## How far (share of the slot width) a fan end may wander from its slot's middle.
const SLOT_WANDER := 0.8
## How far a split point may slide along the segment (share of it), so spacing is ragged.
const SLIDE := 0.2


## A channel from (0,0) to (1,0) as Vector3(right, up, t): the sideways offsets are in lengths of
## the line, so one shape fits any span. `depth` rounds of splitting give 2^depth + 1 points;
## `amp` is the first round's push (lengths).
static func channel(rng: RandomNumberGenerator, depth: int, amp: float) -> PackedVector3Array:
	var pts := PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, 1)])
	var push := amp
	for _round: int in depth:
		var next := PackedVector3Array()
		for i: int in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			next.append(a)
			var t := lerpf(a.z, b.z, 0.5 + rng.randf_range(-SLIDE, SLIDE) * 0.5)
			var kick := Vector2.from_angle(rng.randf() * TAU) * push * rng.randf()
			next.append(Vector3((a.x + b.x) * 0.5 + kick.x, (a.y + b.y) * 0.5 + kick.y, t))
		next.append(pts[pts.size() - 1])
		pts = next
		push *= 0.55
	return pts


## The channel `shape` laid from `a` to `b` in the world: along the line by t, sideways by
## right/up scaled by the line's length. Up is the world's up unless the line runs vertical.
static func place(shape: PackedVector3Array, a: Vector3, b: Vector3) -> PackedVector3Array:
	var axis := b - a
	var length := axis.length()
	var out := PackedVector3Array()
	if length < 0.001:
		out.append(a)
		return out
	var dir := axis / length
	var right := dir.cross(Vector3.UP)
	if right.length() < 0.05:
		right = dir.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(dir).normalized()
	for p: Vector3 in shape:
		out.append(a + axis * p.z + (right * p.x + up * p.y) * length)
	return out


## The point of `line` (a placed channel) at t along it (t in 0..1 of its points' own spacing).
static func at_t(line: PackedVector3Array, t: float) -> Vector3:
	if line.size() < 2:
		return line[0] if line.size() == 1 else Vector3.ZERO
	var f := clampf(t, 0.0, 1.0) * (line.size() - 1)
	var i := mini(floori(f), line.size() - 2)
	return line[i].lerp(line[i + 1], f - i)


## {"origin": Vector3 (xz used), "dir": flat unit Vector3, "reach": float, "half": radians,
## "y": float}. `p` pulled inside that cone (only the ground position moves; height stays).
static func clamp_to_cone(p: Vector3, cone: Dictionary) -> Vector3:
	var origin: Vector3 = cone["origin"]
	var dir: Vector3 = cone["dir"]
	var rel := Vector2(p.x - origin.x, p.z - origin.z)
	var length := rel.length()
	if length < APEX_FREE:
		return p
	var half := Num.f(cone["half"]) * EDGE_MARGIN
	var ang := clampf(
		atan2(dir.x * rel.y - dir.z * rel.x, dir.x * rel.x + dir.z * rel.y), -half, half
	)
	var out := Vector2(dir.x * cos(ang) - dir.z * sin(ang), dir.x * sin(ang) + dir.z * cos(ang))
	out *= minf(length, Num.f(cone["reach"]))
	return Vector3(origin.x + out.x, p.y, origin.z + out.y)


## Whether `p` lies inside the cone (a hair of slack for rounding).
static func inside(p: Vector3, cone: Dictionary) -> bool:
	var pulled := clamp_to_cone(p, cone)
	return Vector2(pulled.x - p.x, pulled.z - p.z).length() < 0.01


## `count` ground points spread across the cone, one per equal slice of its width, each somewhere
## in its slice and between FAN_NEAR and FAN_FAR of the reach; the order is shuffled.
static func fan_ends(rng: RandomNumberGenerator, cone: Dictionary, count: int) -> Array[Vector3]:
	var origin: Vector3 = cone["origin"]
	var dir: Vector3 = cone["dir"]
	var half := Num.f(cone["half"]) * EDGE_MARGIN * Num.f(cone.get("spread", 1.0))
	var near := Num.f(cone.get("near", FAN_NEAR))
	var out: Array[Vector3] = []
	for i: int in count:
		var slot := (i + 0.5) / count * 2.0 - 1.0
		var wander := rng.randf_range(-1.0, 1.0) * SLOT_WANDER / count
		var ang := clampf((slot + wander) * half, -half, half)
		var d := Num.f(cone["reach"]) * rng.randf_range(near, FAN_FAR)
		var flat := Vector2(
			dir.x * cos(ang) - dir.z * sin(ang), dir.x * sin(ang) + dir.z * cos(ang)
		)
		out.append(Vector3(origin.x + flat.x * d, Num.f(cone["y"]), origin.z + flat.y * d))
	for i: int in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := out[i]
		out[i] = out[j]
		out[j] = swap
	return out
