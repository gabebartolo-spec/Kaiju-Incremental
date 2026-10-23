class_name SerpentReadChecks
extends RefCounted
## The serpent suite's read checks (motion critic round 4, in screen terms), on the clip's own
## route (tools/capture/capture_serpent.gd: slithering east, a 90 deg turn north, a U-turn south,
## let go): through the turns no stretch of the body longer than STRAIGHT_BAR m runs straight
## (its heading inside a STRAIGHT_DEG band), and every whole lobe of the S still swings at least
## SWING_SHARE of the ruled wave_amp about the sim's centreline (round 4: "a dead-straight leg of
## about 25 m ... the rope-on-rail look"); then, every frame of the stop and the coil, the tube
## never passes through itself (round 4: "the head and neck pass through the forming loop and the
## body crosses itself"); round 5 critic: through the turn the whole body stays in frame (every
## joint above FRAME_BAR of the way down and inside it across, the camera kept on the body), and
## once coiled no tail stub trails out (each of the last TAIL joints lies beside another ring).
## Each measure is first shown failing on a known-bad body.

const DT := 1.0 / 60.0
const STRAIGHT_BAR := 8.0
const STRAIGHT_DEG := 10.0
const SWING_SHARE := 0.6
## Joints this close along the chain are neighbours, not a crossing.
const NEIGHBOURS := 4
## The deepest down (or furthest across) the frame a joint may sit through the turn.
const FRAME_BAR := 0.93
## The turn's span on the clip (s).
const TURN_FROM := 3.0
const TURN_TO := 5.0
## The tail joints that must each lie within RING_GAP m of a non-neighbour (another ring) once
## coiled.
const TAIL := 10
const RING_GAP := 2.6
const Capture := preload("res://tools/capture/capture_serpent.gd")

var check: Callable
var _cfg: Dictionary = Content.section("serpent")


func _init(p_check: Callable) -> void:
	check = p_check


func run() -> void:
	var drawn := SerpentStandIn.new(_cfg)
	var body := SerpentBody.new(_cfg, Vector2.ZERO, Vector2(1, 0))
	for _i: int in int(Capture.PREROLL_S / DT):
		body.step(DT, Vector2(1, 0))
		drawn.update(body, DT)
	var spine := PackedVector2Array()  # known-bad: a straight spine behind the head
	for j: int in drawn.joints.size():
		spine.append(body.pos - body.heading * j)
	check.call(_longest_straight(spine) > STRAIGHT_BAR, "the straight-run measure catches a rod")
	var straight := 0.0
	var weakest := INF
	var crossings := 0
	var closest := INF
	var moving := Vector3(body.heading.x, 0.0, body.heading.y) * body.speed
	var cam := SerpentCamera.new(_cfg, SerpentCamera.target(_cfg, body), moving)
	var plain := SerpentCamera.new(_cfg, SerpentCamera.target(_cfg, body), moving)  # known-bad
	var edge := Vector2.ZERO  # deepest into the frame's edges: kept on the body, and not
	var frames := int(Num.f(_cfg["coil_s"]) / DT) + int(Capture.LET_GO_AT / DT) + 150
	for f: int in frames:
		body.step(DT, Capture.stick_at(f * DT))
		drawn.update(body, DT)
		var kept := cam.follow(body, DT, drawn.joints)
		var loose := plain.follow(body, DT)
		if f * DT >= TURN_FROM and f * DT <= TURN_TO:
			edge = edge.max(Vector2(_edge(kept, drawn), _edge(loose, drawn)))
		if body.speed > 0.0 and f % 6 == 0:
			straight = maxf(straight, _longest_straight(drawn.joints))
			weakest = minf(weakest, _weakest_lobe(drawn.joints, body))
		elif body.speed <= 0.0:
			var near := _closest_pass(drawn)
			closest = minf(closest, near)
			crossings += 1 if near < 1.0 else 0
	var stub := _tail_apart(drawn.joints, drawn.lifts)
	var stub_bad := _tail_apart(_stub_out(drawn.joints), drawn.lifts)
	drawn.free()
	var bad := _bad_coil()
	var amp := Num.f(_cfg["wave_amp"])
	var line := "serpent: through the turns the longest straight run %.1f m (bar %.0f), weakest lobe "
	line += "%.0f%% of the ruled swing (bar %.0f%%); coil: %d frames self-intersecting, closest "
	line += "pass %.2f of touching (a coil under a girth apart: %.2f)"
	print(
		(
			line
			% [
				straight,
				STRAIGHT_BAR,
				weakest / amp * 100.0,
				SWING_SHARE * 100.0,
				crossings,
				closest,
				bad
			]
		)
	)
	check.call(straight <= STRAIGHT_BAR, "no straight run over 8 m through the turns")
	check.call(weakest >= SWING_SHARE * amp, "every lobe keeps 60% of the swing through the turns")
	check.call(bad < 1.0, "the crossing measure catches rings laid under a girth apart")
	check.call(crossings == 0, "the body never passes through itself in the stop and the coil")
	var more := "serpent: through the turn the body reaches %.0f%% of the way to the frame's edge "
	more += "(bar %.0f%%; the head-led camera alone: %.0f%%); coiled, the tail's last %d joints lie "
	more += "%.1f m at most from another ring (bar %.1f; a 6 m stub: %.1f)"
	print(
		more % [edge.x * 100.0, FRAME_BAR * 100.0, edge.y * 100.0, TAIL, stub, RING_GAP, stub_bad]
	)
	check.call(edge.y > FRAME_BAR, "the frame measure catches a camera that loses the body")
	check.call(edge.x <= FRAME_BAR, "through the turn the whole body stays in frame")
	check.call(stub_bad > RING_GAP, "the stub measure catches a tail left out of the coil")
	check.call(stub <= RING_GAP, "coiled, no tail stub trails out of the coil")


## How far toward the frame's edges the drawn body reaches from the camera at `xform` (0.5: the
## centre, 1: on an edge): the most of its joints' place down and across, either way.
static func _edge(xform: Transform3D, drawn: SerpentStandIn) -> float:
	var fov := CameraTuning.fov()
	var most := 0.0
	for j: int in drawn.joints.size():
		var p := Vector3(drawn.joints[j].x, drawn.lifts[j], drawn.joints[j].y)
		var down := SerpentCamera.screen_down(xform, fov, p)
		var across := SerpentCamera.screen_across(xform, fov, p)
		most = maxf(most, maxf(maxf(down, 1.0 - down), maxf(across, 1.0 - across)))
	return most


## The farthest any of the last TAIL joints lies from a joint that is not its neighbour (m, in 3D):
## a tail coiled in lies beside the next ring.
static func _tail_apart(joints: PackedVector2Array, lifts: PackedFloat32Array) -> float:
	var worst := 0.0
	var n := joints.size()
	for k: int in range(n - TAIL, n):
		var near := INF
		var a := Vector3(joints[k].x, lifts[k], joints[k].y)
		for i: int in n:
			if absi(i - k) > 6:
				near = minf(near, a.distance_to(Vector3(joints[i].x, lifts[i], joints[i].y)))
		worst = maxf(worst, near)
	return worst


## Known-bad: the coiled body with its last 6 joints run straight out from the tail.
static func _stub_out(joints: PackedVector2Array) -> PackedVector2Array:
	var out := joints.duplicate()
	var n := out.size()
	var at := out[n - 7]
	var way := (out[n - 7] - out[n - 8]).normalized()
	for k: int in range(n - 6, n):
		at += way
		out[k] = at
	return out


## The longest stretch (m) of `joints`, the thin tail included (round 6: the whole body counts),
## whose heading stays inside STRAIGHT_DEG.
func _longest_straight(joints: PackedVector2Array) -> float:
	var seg := Num.f(_cfg["length"]) / Num.i(_cfg["segments"])
	var ways := PackedFloat32Array()
	var last := 0.0
	for j: int in joints.size() - 1:
		var a := (joints[j + 1] - joints[j]).angle()
		if j > 0:
			a = last + wrapf(a - last, -PI, PI)
		ways.append(a)
		last = a
	var n := ways.size()
	var best := 0
	for a: int in n:
		var lo := ways[a]
		var hi := ways[a]
		var b := a
		while b + 1 < n:
			lo = minf(lo, ways[b + 1])
			hi = maxf(hi, ways[b + 1])
			if rad_to_deg(hi - lo) > STRAIGHT_DEG:
				break
			b += 1
		best = maxi(best, b - a + 1)
	return best * seg


## The smallest swing (m) of any whole lobe of `joints` about the sim's centreline (the head's and
## the tail's part-lobes left out).
static func _weakest_lobe(joints: PackedVector2Array, body: SerpentBody) -> float:
	var line := PackedVector2Array()
	for k: int in int(body.length() * 1.2):
		line.append(body.centre_at(k))
	var peaks := PackedFloat32Array()
	var peak := 0.0
	var side := 0.0
	for p: Vector2 in joints:
		var off := _signed_off(p, line)
		if side != 0.0 and signf(off) != side:
			peaks.append(peak)
			peak = 0.0
		side = signf(off)
		peak = maxf(peak, absf(off))
	var weakest := INF
	for k: int in range(1, peaks.size()):
		weakest = minf(weakest, peaks[k])
	return weakest


## How far `p` is off the polyline `line`, signed by the side it lies on.
static func _signed_off(p: Vector2, line: PackedVector2Array) -> float:
	var best := INF
	var signed := 0.0
	for i: int in range(1, line.size()):
		var q := Geometry2D.get_closest_point_to_segment(p, line[i - 1], line[i])
		var d := p.distance_to(q)
		if d < best:
			best = d
			signed = d * signf((line[i] - line[i - 1]).cross(p - q))
	return signed


## The closest any two non-neighbouring joints of the drawn tube pass, as a share of touching (1:
## surfaces meet; under 1: the tube passes through itself), across width and height.
static func _closest_pass(drawn: SerpentStandIn) -> float:
	var j := drawn.joints
	var seg := Num.f(drawn._cfg["length"]) / Num.i(drawn._cfg["segments"])
	var widths := PackedFloat32Array()
	var heights := PackedFloat32Array()
	for k: int in j.size():
		widths.append(drawn.width_at(k * seg))
		heights.append(drawn.height_at(k * seg))
	return _closest(j, drawn.lifts, widths, heights)


static func _closest(
	j: PackedVector2Array,
	lifts: PackedFloat32Array,
	widths: PackedFloat32Array,
	heights: PackedFloat32Array
) -> float:
	var closest := INF
	for a: int in j.size():
		for b: int in range(a + NEIGHBOURS, j.size()):
			var across := j[a].distance_to(j[b]) / ((widths[a] + widths[b]) * 0.5)
			var up := lifts[a] - lifts[b] + (heights[a] - heights[b]) * 0.5
			closest = minf(
				closest, Vector2(across, up / ((heights[a] + heights[b]) * 0.5)).length()
			)
	return closest


## Known-bad: a flat spiral whose turns lie half a girth apart passes through itself.
func _bad_coil() -> float:
	var girth := Num.f(_cfg["girth"])
	var j := PackedVector2Array()
	var lifts := PackedFloat32Array()
	var widths := PackedFloat32Array()
	var heights := PackedFloat32Array()
	var theta := 0.0
	for _k: int in 40:
		var r := 4.0 - girth * 0.5 * theta / TAU
		j.append(Vector2.from_angle(theta) * r)
		lifts.append(0.0)
		widths.append(girth)
		heights.append(girth * 0.8)
		theta += 1.0 / r
	return _closest(j, lifts, widths, heights)
