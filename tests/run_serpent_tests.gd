extends "res://tests/lib/runner.gd"
## Serpent suite: the slither prototype's trail body (D-198; SerpentTrail, SerpentBody,
## SerpentWeave) against the research's bars (research_serpent_slither 5.9), each printed:
## sideways slip under 2% of speed, the wave running down the body within 1% of the forward
## speed, under one voxel of corner-cut through a 90 deg turn, no motion 0.3 s after a stop, and
## a 90 deg turn in about 1.5 s ("About 1.5 s"). Each measure is first shown failing on a
## known-bad body (a wave in the body's own frame, a straight spine, an S that follows the
## current speed). Seeded by design: the trail sampler's walk uses a pinned seed; the rest is
## scripted input on a fixed 60 Hz step.
##   godot --headless --path . --script tests/run_serpent_tests.gd

const DT := 1.0 / 60.0
const NORTH := Vector2(0, -1)
const EAST := Vector2(1, 0)
const WEST := Vector2(-1, 0)
const SLIP_BAR := 0.02
const WAVE_BAR := 0.01
const STILL_AFTER := 0.3
const TURN_S := 1.5
const TURN_TOLERANCE := 0.1

var _cfg: Dictionary = Content.section("serpent")
## Each test body's drawn S (SerpentWeave), by the body's instance id.
var _weaves: Dictionary = {}
## The tightest bend radius the drawn body made in the slip run (m).
var _tightest := INF


func suite_name() -> String:
	return "Serpent"


func run_checks() -> void:
	await _t("_check_trail_sampler")
	await _t("_check_trail_replays")
	await _t("_check_turn_time")
	await _t("_check_no_slip")
	await _t("_check_wave_speed")
	await _t("_check_corner_cut")
	await _t("_check_stop_freezes")


## The sampler on a seeded wander: samples sit exactly `spacing` apart along the head's path, a
## point any distance behind lies on that path, and standing still records nothing.
func _check_trail_sampler() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5E7
	var trail := SerpentTrail.new(0.05, 30.0, Vector2.ZERO, NORTH)
	var path := PackedVector2Array([Vector2.ZERO])
	var arcs: Array[float] = [0.0]
	var heading := NORTH
	for _i: int in 900:
		heading = heading.rotated(rng.randf_range(-0.04, 0.04))
		var to := trail.head + heading * rng.randf_range(0.0, 0.2)
		trail.advance(to, heading, 5.0, 0.0)
		if to != path[path.size() - 1]:
			arcs.append(arcs[arcs.size() - 1] + to.distance_to(path[path.size() - 1]))
			path.append(to)
	var worst_gap := 0.0
	for n: int in range(maxi(trail.first(), 1), trail.last()):
		var want := _on_path(path, arcs, n * trail.spacing)
		worst_gap = maxf(worst_gap, trail.point(n).distance_to(want))
	var worst_at := 0.0
	for _k: int in 200:
		var behind := rng.randf_range(0.0, 29.0)
		var want := _on_path(path, arcs, trail.head_s - behind)
		worst_at = maxf(worst_at, trail.at(behind).distance_to(want))
	print(
		"serpent: sampler error %.6f m (samples), %.6f m (any point behind)" % [worst_gap, worst_at]
	)
	# Between two samples the body takes the straight chord: off a curving path by at most the
	# sampling sag (spacing^2 x curvature / 8), well under a millimetre here.
	check(worst_gap < 1e-4 and worst_at < 1e-3, "trail samples lie on the head's own path")
	var last := trail.last()
	var tail := trail.at(20.0)
	for _j: int in 30:
		trail.advance(trail.head, heading, 0.0, 0.0)
	check(
		trail.last() == last and trail.at(20.0) == tail,
		"standing still records nothing and the body does not move"
	)


## The same scripted run twice gives the same body, joint for joint.
func _check_trail_replays() -> void:
	var a := _route_joints()
	var b := _route_joints()
	check(
		a == b and a.size() == Num.i(_cfg["segments"]) + 1, "a replayed slither lays the same body"
	)


## From a full-speed straight, a 90 deg turn of the stick is made in about 1.5 s.
func _check_turn_time() -> void:
	var body := _cruising(NORTH, 8.0)
	var frames := 0
	while absf(body.heading.angle_to(EAST)) > 0.0001 and frames < 600:
		_step(body, EAST)
		frames += 1
	var took := frames * DT
	print("serpent: 90 deg turn %.3f s (bar %.2f +/- %.2f)" % [took, TURN_S, TURN_TOLERANCE])
	check(absf(took - TURN_S) <= TURN_TOLERANCE, "a 90 deg turn takes about 1.5 s (%.3f s)" % took)
	var radius := Num.f(_cfg["speed"]) / Num.f(_cfg["turn_rate"])
	var widths := radius / Num.f(_cfg["head_width"])
	print("serpent: tightest turn radius %.2f m, %.1f body widths" % [radius, widths])
	check(widths >= 1.5, "no turn tighter than 1.5 body widths")


## Straight, a 90 deg turn and a U-turn: no body point slides across its own track; a wave drawn
## in the body's own frame (the swimming look) does, and fails the same measure.
func _check_no_slip() -> void:
	var good := _worst_slip(false)
	var bad := _worst_slip(true)
	var widths := _tightest / Num.f(_cfg["head_width"])
	print("serpent: tightest drawn bend %.2f m, %.1f body widths" % [_tightest, widths])
	check(widths >= 1.5, "no drawn bend tighter than 1.5 body widths (%.2f)" % widths)
	var line := "serpent: worst sideways slip %.3f%% of speed (body-frame wave: %.1f%%)"
	print(line % [good * 100.0, bad * 100.0])
	check(bad > SLIP_BAR, "the slip measure catches a body-frame wave (%.1f%%)" % (bad * 100.0))
	check(good < SLIP_BAR, "sideways slip under 2%% of speed (%.3f%%)" % (good * 100.0))


## On a steady straight the bends run down the body at the head's speed along its path.
func _check_wave_speed() -> void:
	for bad: bool in [true, false]:
		var body := _cruising(NORTH, 12.0)
		var seg := body.length() / Num.i(_cfg["segments"])
		var before := _inflections(_joints(body, DT if bad else 0.0), seg)
		var travelled := 0.0
		var head := _joints(body, 0.0)[0]
		for i: int in 60:
			_step(body, NORTH)
			var now := _joints(body, (i + 2.0) * DT if bad else 0.0)[0]
			travelled += now.distance_to(head)
			head = now
		var after := _inflections(_joints(body, 61.0 * DT if bad else 0.0), seg)
		var err := _wave_error(before, after, travelled)
		var label := "body-frame wave" if bad else "trail wave"
		print("serpent: %s speed off the forward speed by %.3f%%" % [label, err * 100.0])
		if bad:
			check(err > WAVE_BAR, "the wave-speed measure catches a wave that outruns the body")
		else:
			check(err < WAVE_BAR, "the wave runs at the forward speed (%.3f%% off)" % (err * 100.0))


## Through a 90 deg turn every body point stays on the head's path: under one voxel off it, the
## centreline and the drawn S both; a straight spine behind the head cuts the corner.
func _check_corner_cut() -> void:
	var body := _cruising(NORTH, 8.0)
	var centre := PackedVector2Array([body.pos])
	var drawn := PackedVector2Array([_joints(body, 0.0)[0]])
	var worst_centre := 0.0
	var worst_drawn := 0.0
	var worst_spine := 0.0
	for frame: int in 300:
		_step(body, EAST)
		centre.append(body.pos)
		var joints := _joints(body, 0.0)
		drawn.append(joints[0])
		if frame % 30 != 29:
			continue
		for k: int in range(1, 48):
			var behind := k * body.length() / 48.0
			if behind < body.speed * (frame + 1) * DT:  # only the part laid since the turn began
				worst_centre = maxf(worst_centre, _off_path(body.centre_at(behind), centre))
				worst_drawn = maxf(worst_drawn, _off_path(joints[k], drawn))
				var spine := body.pos - body.heading * behind
				worst_spine = maxf(worst_spine, _off_path(spine, centre))
	var voxel := KaijuModel.VOXEL
	print(
		(
			"serpent: corner-cut %.4f m centreline, %.4f m drawn S (voxel %.2f m; straight spine %.1f m)"
			% [worst_centre, worst_drawn, voxel, worst_spine]
		)
	)
	check(worst_spine > voxel, "the corner-cut measure catches a straight spine")
	check(worst_centre < voxel and worst_drawn < voxel, "the body cuts no corner (under one voxel)")


## Let go of the stick: the head slows to a stop and 0.3 s later nothing moves, the head's look
## included; an S that follows the current speed would still be straightening.
func _check_stop_freezes() -> void:
	for bad: bool in [true, false]:
		var body := _cruising(NORTH, 8.0)
		for _i: int in 40:
			_step(body, EAST)  # stop mid-turn: the head is leading
		var drawn := SerpentStandIn.new(_cfg)
		drawn.update(body, DT)
		var frames := 0
		while body.speed > 0.0 and frames < 600:
			_step(body, Vector2.ZERO)
			drawn.update(body, DT)
			frames += 1
		var stop_s := frames * DT
		for _j: int in int(STILL_AFTER / DT):
			_step(body, Vector2.ZERO)
			drawn.update(body, DT)
		var moved := 0.0
		var lead := drawn.lead
		var last := _joints_with(drawn, body, bad, 0)
		for k: int in 30:
			_step(body, Vector2.ZERO)
			drawn.update(body, DT)
			var now := _joints_with(drawn, body, bad, k + 1)
			for j: int in now.size():
				moved = maxf(moved, now[j].distance_to(last[j]))
			moved = maxf(moved, absf(drawn.lead - lead))
			last = now
			lead = drawn.lead
		drawn.free()
		if bad:
			check(
				moved > 0.0001, "the stillness measure catches a body that straightens after a stop"
			)
			continue
		print("serpent: stops in %.2f s; most motion 0.3 s later %.6f m a frame" % [stop_s, moved])
		check(moved < 0.0001, "0.3 s after the stop nothing moves (%.6f m a frame)" % moved)


# --- helpers ------------------------------------------------------------------------------------


## A body that has slithered `seconds` along `dir` with the stick full on.
func _cruising(dir: Vector2, seconds: float) -> SerpentBody:
	var body := SerpentBody.new(_cfg, Vector2.ZERO, dir)
	_weaves[body.get_instance_id()] = SerpentWeave.new(body)
	for _i: int in int(seconds / DT):
		_step(body, dir)
	return body


## One 60 Hz step of the body, its drawn S kept up with it (as the stand-in does every frame).
func _step(body: SerpentBody, stick: Vector2) -> void:
	body.step(DT, stick)
	_weave(body).step(body, DT)


func _weave(body: SerpentBody) -> SerpentWeave:
	var weave: SerpentWeave = _weaves[body.get_instance_id()]
	return weave


## The drawn joints; `clock` > 0 adds a known-bad wave that also travels with time in the
## body's own frame (it outruns the body and slides it sideways).
func _joints(body: SerpentBody, clock: float) -> PackedVector2Array:
	var count := Num.i(_cfg["segments"])
	var seg := body.length() / count
	var out := SerpentWeave.joints(_weave(body).path(body.length() + seg), seg, count)
	if clock <= 0.0:
		return out
	var amp := SerpentWeave.amplitude(_cfg, body.speed)
	for j: int in out.size():
		var behind := j * seg
		var s := body.trail.head_s - behind + Num.f(_cfg["speed"]) * clock
		out[j] = (
			body.centre_at(behind) + body.heading.orthogonal() * SerpentWeave.lateral(_cfg, s, amp)
		)
	return out


## The stand-in's joints, or (bad) a body whose S fades out after the stop (`k` frames on), as an
## S scaled by the current speed would.
func _joints_with(
	drawn: SerpentStandIn, body: SerpentBody, bad: bool, k: int
) -> PackedVector2Array:
	if not bad:
		return drawn.joints.duplicate()
	var out := drawn.joints.duplicate()
	var count := out.size() - 1
	var seg := body.length() / count
	for j: int in out.size():
		var centre := body.centre_at(j * seg)
		out[j] = centre + (out[j] - centre) * pow(0.97, k)
	return out


## The worst slip (share of speed) over straight, a 90 deg turn and a U-turn.
func _worst_slip(bad: bool) -> float:
	var body := _cruising(NORTH, 8.0)
	var worst := 0.0
	var last := _joints(body, DT if bad else 0.0)
	for frame: int in 360:
		var stick := NORTH if frame < 60 else (EAST if frame < 180 else WEST)
		_step(body, stick)
		var now := _joints(body, (frame + 2.0) * DT if bad else 0.0)
		if body.speed > 1.0:
			for j: int in range(1, now.size() - 1):
				var tangent := (last[j - 1] - last[j + 1]) + (now[j - 1] - now[j + 1])
				var moved := now[j] - last[j]  # the point's own speed: the drawn S runs faster
				var across := moved.dot(tangent.normalized().orthogonal())
				worst = maxf(worst, absf(across) / maxf(moved.length(), body.speed * DT))
		if not bad:
			for j: int in range(1, now.size() - 1):
				_tightest = minf(_tightest, _bend_radius(now[j - 1], now[j], now[j + 1]))
		last = now
	return worst


## The body of the scripted route (straight, 90 deg turn, U-turn, stop).
func _route_joints() -> PackedVector2Array:
	var body := _cruising(NORTH, 4.0)
	for frame: int in 400:
		var stick := EAST if frame < 120 else (WEST if frame < 300 else Vector2.ZERO)
		_step(body, stick)
	return _joints(body, 0.0)


## Where the bends change side along the body (arc from the head), from the joints' turning.
func _inflections(joints: PackedVector2Array, seg: float) -> PackedFloat32Array:
	var bends := PackedFloat32Array()
	for j: int in range(1, joints.size() - 1):
		bends.append((joints[j - 1] - joints[j]).angle_to(joints[j] - joints[j + 1]))
	var out := PackedFloat32Array()
	for k: int in bends.size() - 1:
		if signf(bends[k]) != signf(bends[k + 1]) and bends[k] != 0.0:
			out.append((k + 1 + bends[k] / (bends[k] - bends[k + 1])) * seg)
	return out


## How far the wave's travel down the body is off the head's travel along its path (share).
func _wave_error(before: PackedFloat32Array, after: PackedFloat32Array, travelled: float) -> float:
	var worst := 0.0
	var found := false
	for z: float in before:
		if z < 2.0 or z + travelled > Num.f(_cfg["length"]) - 2.0:
			continue
		var nearest := INF
		for w: float in after:
			if absf(w - z - travelled) < absf(nearest - z - travelled):
				nearest = w
		worst = maxf(worst, absf(nearest - z - travelled) / travelled)
		found = true
	return worst if found else INF


## The point `s` along a polyline whose vertices sit at `arcs`.
func _on_path(path: PackedVector2Array, arcs: Array[float], s: float) -> Vector2:
	for i: int in range(1, path.size()):
		if arcs[i] >= s:
			var t := (s - arcs[i - 1]) / maxf(arcs[i] - arcs[i - 1], 1e-9)
			return path[i - 1].lerp(path[i], t)
	return path[path.size() - 1]


## The radius of the circle through three joints (INF when they lie in a line).
func _bend_radius(a: Vector2, b: Vector2, c: Vector2) -> float:
	var cross := absf((b - a).cross(c - b))
	if cross < 1e-9:
		return INF
	return a.distance_to(b) * b.distance_to(c) * c.distance_to(a) / (2.0 * cross)


## Distance from `p` to the nearest point of a polyline.
func _off_path(p: Vector2, path: PackedVector2Array) -> float:
	var best := INF
	for i: int in range(1, path.size()):
		best = minf(
			best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, path[i - 1], path[i]))
		)
	return best
