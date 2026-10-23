class_name SerpentCoil
extends RefCounted
## The path the serpent slides along when it stops (director D-210: "snake curls up into a
## defensive position"; D-206: a spitting cobra). Round 4 moved every joint straight to its place in
## the coil, so the head and neck passed through the forming loop and the body crossed itself; now
## the coil is one precomputed path the body follows head first (follow-the-leader): from where the
## head stopped it curls straight into the outer ring (radius coil_radius, tangent to the head's
## way), spirals inward coil_pitch m a turn while each turn sits coil_rise m higher than the one
## outside it (a staggered pile), down to coil_inner m from the centre; then the neck rises out of
## the centre to coil_head_rise m and the head levels off over the coil, facing the way it went,
## tipped coil_head_tilt rad nose-down so its top reads from the high camera. A spiral never meets
## itself, so the body never crosses itself. Pure geometry (data/tuning.json "serpent");
## presentation only.

## Spacing of the path's points (m).
const STEP := 0.25
## The straight run (m) the head may take before it curls into the ring.
const ENTRY := 2.0
## How many straight runs (0, ENTRY, 2 x ENTRY ...) the placement tries.
const ENTRIES := 5
## About how much of the arch's span it rises (its chord's slope, for where the helix must end).
const ARCH_RISE := 0.4
## The neck's helix closes in to this share of the inner ring's radius as it rises.
const NECK_TIGHTEN := 1.0
## The raised head may turn toward the coil this far a step (rad), up to LOOK_TURNS steps a way.
const LOOK_STEP := 0.2
const LOOK_TURNS := 4
## Joints next to the head that may lie in the ring's disc (they lead into it).
const SKIP := 4


## The coil path for a body stopped as `body` (joints, head first) going `way`, beside the sim's
## centreline `line` (head first): points (x, height, z) from the stopped head to the snout tip, STEP
## apart or closer. `face`: the way the raised head looks.
static func path(
	body: PackedVector2Array, way: Vector2, line: PackedVector2Array, face: Vector2, cfg: Dictionary
) -> PackedVector3Array:
	var f := way.normalized()
	var place := centre(body, way, line, face, cfg)
	var mid: Vector2 = place[0]
	var entry: float = place[1]
	var look: Vector2 = place[2]
	var out := PackedVector3Array()
	for i: int in ceili(entry / STEP):  # straight on to where the ring begins
		var at := body[0] + f * (i * STEP)
		out.append(Vector3(at.x, 0.0, at.y))
	var radius := Num.f(cfg["coil_radius"])
	var from := body[0] + f * entry - mid
	var start := from.angle()
	var turning := signf(from.cross(f))  # the way round the centre the head is already going
	var pitch := Num.f(cfg["coil_pitch"])
	var inner := Num.f(cfg["coil_inner"])
	var rise := Num.f(cfg["coil_rise"])
	var theta := 0.0
	var turns := (radius - inner) / pitch
	while theta <= TAU * turns:
		var r := radius - pitch * theta / TAU
		var at := mid + Vector2.from_angle(start + turning * theta) * r
		out.append(Vector3(at.x, rise * theta / TAU, at.y))
		theta += STEP / r
	_neck(out, mid, look.normalized(), cfg)
	return out


## Where the ring goes for a body stopped as `body` going `way`: [its centre, the straight run
## (m) before the ring begins, the way the raised head looks]. The ring is tangent to the head's
## way, coil_radius to one side, after a straight run of 0 to (ENTRIES - 1) x ENTRY m. Of those it
## takes the one whose disc the rest of the body (still lying where it stopped) stays clear of, so
## the head never meets the body, and that stays over the S's footprint (within the swing and the
## girth of the sim's centreline `line`, head first); the first that does both, else the one that
## comes nearest. The head looks along `face`, or turned up to LOOK_TURNS steps toward the coil if
## it would reach past the footprint.
static func centre(
	body: PackedVector2Array, way: Vector2, line: PackedVector2Array, face: Vector2, cfg: Dictionary
) -> Array:
	var radius := Num.f(cfg["coil_radius"])
	var girth := Num.f(cfg["girth"])
	var room := Num.f(cfg["wave_amp"]) * (1.0 + Num.f(cfg["wave_wobble_amp"])) + girth
	var f := way.normalized()
	var best := [body[0], 0.0, face]
	var least := INF
	for step: int in ENTRIES:
		var entry := step * ENTRY
		for side: float in [1.0, -1.0]:
			var mid := body[0] + f * entry + f.orthogonal() * (radius * side)
			var cost := 0.0
			for j: int in range(SKIP, body.size()):
				cost += maxf(radius + girth - body[j].distance_to(mid), 0.0) * 10.0
			for k: int in 16:
				var rim := mid + Vector2.from_angle(TAU * k / 16.0) * (radius + girth * 0.5)
				cost += maxf(_off(rim, line) - room, 0.0)
			var look := _look(mid, side, face, line, room, cfg)
			cost += look.z * 20.0
			if cost < least - 0.001:
				least = cost
				best = [mid, entry, Vector2(look.x, look.y)]
	return best


## The way the raised head looks over a ring at `mid` (on `side` of the head's way): `face`, or
## turned toward the centreline a LOOK_STEP at a time until its snout is over the footprint.
## (x, y): that way; z: how far the snout still reaches past the footprint (m).
static func _look(
	mid: Vector2, side: float, face: Vector2, line: PackedVector2Array, room: float, cfg: Dictionary
) -> Vector3:
	var reach := Num.f(cfg["coil_neck_arch"]) * 0.9 + Num.f(cfg["head_len"])
	var best := Vector3(face.x, face.y, INF)
	for k: int in LOOK_TURNS * 2 + 1:
		var turn := LOOK_STEP * ceili(k / 2.0) * (1.0 if k % 2 == 1 else -1.0)
		var way := face.normalized().rotated(turn)
		var neck := mid + Vector2.from_angle(way.angle() + side * PI * 0.5) * Num.f(cfg["coil_inner"])
		var over := maxf(_off(neck + way * reach, line) - room, 0.0)
		if over < best.z - 0.001:
			best = Vector3(way.x, way.y, over)
		if over == 0.0:
			break
	return best


## How far `p` is from the polyline `line` (m).
static func _off(p: Vector2, line: PackedVector2Array) -> float:
	var best := INF
	for i: int in range(1, line.size()):
		var q := Geometry2D.get_closest_point_to_segment(p, line[i - 1], line[i])
		best = minf(best, p.distance_to(q))
	return best


## The neck and head appended to the spiral in `out`: the neck carries on round the centre inside
## the last ring, rising ever more steeply (a helix), until it runs the way the head will look;
## then it arches over (a bend coil_neck_arch m across) into the head, held out tipped
## coil_head_tilt rad nose-down, about coil_head_rise m up. No corner anywhere, every bend wider than a body width.
static func _neck(out: PackedVector3Array, ring: Vector2, face: Vector2, cfg: Dictionary) -> void:
	var n := out.size()
	var end := out[n - 1]
	var along := Vector2(end.x - out[n - 2].x, end.z - out[n - 2].z)
	var plan := Vector2(end.x, end.z) - ring
	var r0 := plan.length()
	var start := plan.angle()
	var turning := signf(plan.cross(along))
	# How far round the centre until the neck runs along `face` (a quarter turn at least).
	var aim := face.angle() - turning * PI * 0.5
	var sweep := fposmod(turning * (aim - start), TAU)
	if sweep < PI * 0.5:
		sweep += TAU
	var tilt := Num.f(cfg["coil_head_tilt"])
	var look := Vector3(face.x * cos(tilt), -sin(tilt), face.y * cos(tilt))
	var arch := Num.f(cfg["coil_neck_arch"])
	var top := Num.f(cfg["coil_head_rise"]) - arch * ARCH_RISE  # where the helix ends
	var r1 := r0 * NECK_TIGHTEN
	var steps := maxi(8, ceili(sweep * r0 * 1.5 / STEP))
	for i: int in range(1, steps + 1):
		var u := float(i) / steps
		var at := ring + Vector2.from_angle(start + turning * sweep * u) * lerpf(r0, r1, u)
		out.append(Vector3(at.x, end.y + (top - end.y) * u * u, at.y))
	var m := out.size()
	var helix_end := out[m - 1]
	var way := (helix_end - out[m - 2]).normalized()
	# The arch: a near-circular bend from the neck's way into the head's, its chord halfway between.
	var base := helix_end + (way + look).normalized() * arch
	_hermite(out, helix_end, way, base, look)
	var head_len := Num.f(cfg["head_len"])
	var head_steps := ceili(head_len / STEP)
	for i: int in range(1, head_steps + 1):
		out.append(base + look * (head_len * i / head_steps))


## Appends a Hermite curve from `a` (leaving along `ta`) to `b` (arriving along `tb`), STEP apart,
## its tangents as long as the chord.
static func _hermite(out: PackedVector3Array, a: Vector3, ta: Vector3, b: Vector3, tb: Vector3) -> void:
	var span := a.distance_to(b)
	var steps := maxi(4, ceili(span * 1.3 / STEP))
	for i: int in range(1, steps + 1):
		var t := float(i) / steps
		var t2 := t * t
		var t3 := t2 * t
		out.append(
			(2.0 * t3 - 3.0 * t2 + 1.0) * a
			+ (t3 - 2.0 * t2 + t) * span * ta
			+ (-2.0 * t3 + 3.0 * t2) * b
			+ (t3 - t2) * span * tb
		)


## The most any point of `joints` is from `at` (m): the coil's reach.
static func reach(joints: PackedVector2Array, at: Vector2) -> float:
	var most := 0.0
	for p: Vector2 in joints:
		most = maxf(most, p.distance_to(at))
	return most
