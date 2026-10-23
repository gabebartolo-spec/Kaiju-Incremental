extends "res://tests/lib/runner.gd"
## Serpent suite: the slither prototype's trail body (D-198; SerpentTrail, SerpentBody,
## SerpentWeave) against the research's bars (research_serpent_slither 5.9), each printed:
## sideways slip under 2% of speed, the wave running down the body within 1% of the forward
## speed, under one voxel of corner-cut through a 90 deg turn, no motion 0.3 s after a stop, and
## a 90 deg turn in about 1.5 s ("About 1.5 s"); round 2: a stop settles (no travel, then still)
## and the serpent's camera never swings. Each measure is first shown failing on a
## known-bad body (a wave in the body's own frame, a straight spine, an S that follows the
## current speed). Seeded by design: the trail sampler's walk uses a pinned seed; the rest is
## scripted input on a fixed 60 Hz step.
##   godot --headless --path . --script tests/run_serpent_tests.gd

const DT := 1.0 / 60.0
const NORTH := Vector2(0, -1)
const EAST := Vector2(1, 0)
const WEST := Vector2(-1, 0)
const SOUTH_EAST := Vector2(0.08, 1.0)
const SLIP_BAR := 0.02
const WAVE_BAR := 0.01
const STILL_AFTER := 0.3
const TURN_S := 1.5
const TURN_TOLERANCE := 0.1

const Geo := preload("res://tests/lib/serpent_geometry.gd")

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
	await _t("_check_stop_settles")
	await _t("_check_camera_steady")


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
		var want := Geo.on_path(path, arcs, n * trail.spacing)
		worst_gap = maxf(worst_gap, trail.point(n).distance_to(want))
	var worst_at := 0.0
	for _k: int in 200:
		var behind := rng.randf_range(0.0, 29.0)
		var want := Geo.on_path(path, arcs, trail.head_s - behind)
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


## Straight, a 90 deg turn and a U-turn: no body point slides off the track it lay on a frame
## before (the drawn path; sideways distance over the point's own travel); a wave drawn
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
		var before := Geo.inflections(_joints(body, DT if bad else 0.0), seg)
		var travelled := 0.0
		var head := _joints(body, 0.0)[0]
		for i: int in 60:
			_step(body, NORTH)
			var now := _joints(body, (i + 2.0) * DT if bad else 0.0)[0]
			travelled += now.distance_to(head)
			head = now
		var after := Geo.inflections(_joints(body, 61.0 * DT if bad else 0.0), seg)
		var err := Geo.wave_error(before, after, travelled, Num.f(_cfg["length"]))
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
	var drawn_from := _weave(body).drawn.head_s
	for frame: int in 300:
		_step(body, EAST)
		centre.append(body.pos)
		var joints := _joints(body, 0.0)
		drawn.append(joints[0])
		if frame % 30 != 29:
			continue
		for k: int in range(1, 48):
			var behind := k * body.length() / 48.0
			if behind < _weave(body).drawn.head_s - drawn_from:  # drawn since the turn began
				worst_drawn = maxf(worst_drawn, Geo.off_path(joints[k], drawn))
			if behind < body.speed * (frame + 1) * DT:  # only the part laid since the turn began
				worst_centre = maxf(worst_centre, Geo.off_path(body.centre_at(behind), centre))
				var spine := body.pos - body.heading * behind
				worst_spine = maxf(worst_spine, Geo.off_path(spine, centre))
	var voxel := KaijuModel.VOXEL
	print(
		(
			"serpent: corner-cut %.4f m centreline, %.4f m drawn S (voxel %.2f m; straight spine %.1f m)"
			% [worst_centre, worst_drawn, voxel, worst_spine]
		)
	)
	check(worst_spine > voxel, "the corner-cut measure catches a straight spine")
	check(worst_centre < voxel and worst_drawn < voxel, "the body cuts no corner (under one voxel)")


## Let go of the stick: the head eases to a halt and never travels again (the sim head, its
## centreline and the drawn head stay put). The body settles visibly (the tail draws about a girth
## nearer the head), then idles: it keeps moving (sway, breath) but stays about its settled shape
## and does not drift. A body that keeps straightening after the stop drifts and fails.
func _check_stop_settles() -> void:
	var settle_s := Num.f(_cfg["settle_s"])
	var girth := Num.f(_cfg["head_width"])
	for bad: bool in [true, false]:
		var body := SerpentBody.new(_cfg, Vector2.ZERO, NORTH)
		_weaves[body.get_instance_id()] = SerpentWeave.new(body)
		var drawn := SerpentStandIn.new(_cfg)
		for frame: int in int(14.0 / DT) + 40:
			_step(body, NORTH if frame < int(14.0 / DT) else EAST)  # stop mid-turn: head leading
			drawn.update(body, DT)
		var frames := 0
		while body.speed > 0.0 and frames < 600:
			_step(body, Vector2.ZERO)
			drawn.update(body, DT)
			frames += 1
		var head := body.pos
		var centre := body.centre_at(20.0)
		var stopped := drawn.joints.duplicate()
		for _j: int in int(settle_s / DT) + 2:
			_step(body, Vector2.ZERO)
			drawn.update(body, DT)
		var settled := drawn.joints.duplicate()
		var last := settled.size() - 1
		var pull := settled[0].distance_to(stopped[last]) - settled[0].distance_to(settled[last])
		var idle := _idle(drawn, body, bad, settled)
		var travel := body.pos.distance_to(head) + body.centre_at(20.0).distance_to(centre)
		drawn.free()
		if bad:
			check(idle.z > 0.05, "the drift measure catches a body still straightening")
			continue
		print(
			(
				"serpent: stops %.2f s after let-go; tail drawn in %.2f m (%.2f girths) by the settle"
				% [frames * DT, pull, pull / girth]
			)
		)
		print(
			(
				"serpent: idle moves up to %.4f m a frame, %.2f m off its settled shape, drifts %.4f m"
				% [idle.x, idle.y, idle.z]
			)
		)
		check(travel == 0.0, "nothing travels once the head has stopped")
		check(absf(pull / girth - 1.0) < 0.3, "the settle draws the tail in about a girth")
		var sway := Num.f(_cfg["idle_sway"])
		check(idle.x > 0.001 and idle.y <= sway * 1.2, "the idle lives, about its settled shape")
		check(idle.z < 0.05, "the idle does not drift")


## Two sway periods of idle after the settle: (most motion a frame, most distance from the
## settled shape, how far the body's mean over a whole period is from the settled mean).
func _idle(
	drawn: SerpentStandIn, body: SerpentBody, bad: bool, settled: PackedVector2Array
) -> Vector3:
	var frames := int(2.0 * Num.f(_cfg["idle_sway_s"]) / DT)
	var moved := 0.0
	var off := 0.0
	var mean := Vector2.ZERO
	var settled_mean := Vector2.ZERO
	for p: Vector2 in settled:
		settled_mean += p / settled.size()
	var last := settled
	for k: int in frames:
		_step(body, Vector2.ZERO)
		drawn.update(body, DT)
		var now := _joints_with(drawn, body, bad, k + 1)
		for j: int in now.size():
			moved = maxf(moved, now[j].distance_to(last[j]))
			off = maxf(off, now[j].distance_to(settled[j]))
			mean += now[j] / (now.size() * frames)
		last = now
	return Vector3(moved, off, mean.distance_to(settled_mean))


## The serpent's camera: on a long leg north the head rides 35-40% down the frame; through a turn,
## a U-turn and a stop its yaw and pitch never change, and it settles at the end.
func _check_camera_steady() -> void:
	var body := _cruising(NORTH, 6.0)
	var fov := CameraTuning.fov()
	var moving := Vector3(body.heading.x, 0.0, body.heading.y) * body.speed
	var cam := SerpentCamera.new(_cfg, SerpentCamera.target(_cfg, body), moving)
	var first := cam.step(SerpentCamera.target(_cfg, body), 0.0).basis
	var turned := 0.0
	var high := 0.0
	var low := 1.0
	var eyes := PackedVector3Array()
	for frame: int in 660:
		var stick := NORTH if frame < 180 else (EAST if frame < 270 else SOUTH_EAST)
		_step(body, Vector2.ZERO if frame >= 450 else stick)
		var t := cam.step(SerpentCamera.target(_cfg, body), DT)
		turned = maxf(turned, (t.basis.z - first.z).length())
		eyes.append(t.origin)
		if frame >= 60 and frame < 180:
			var down := SerpentCamera.screen_down(t, fov, Vector3(body.pos.x, 0.0, body.pos.y))
			high = maxf(high, down)
			low = minf(low, down)
	var n := eyes.size()
	var end_speed := eyes[n - 1].distance_to(eyes[n - 2]) / DT
	var line := "serpent: head %.0f-%.0f%% down the frame going north; camera turned %.6f; "
	print(line % [low * 100.0, high * 100.0, turned] + "%.4f m/s at the end" % end_speed)
	check(low >= 0.35 and high <= 0.40, "on a long leg the head rides 35-40% down the frame")
	check(turned == 0.0, "the serpent's camera never swings with a turn")
	check(end_speed < 0.05, "the camera has settled at the end of the shot")


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
	var reach := body.length() * 1.1
	var last := _joints(body, DT if bad else 0.0)
	var track := last if bad else _weave(body).path(reach)
	for frame: int in 360:
		var stick := NORTH if frame < 60 else (EAST if frame < 180 else WEST)
		_step(body, stick)
		var now := _joints(body, (frame + 2.0) * DT if bad else 0.0)
		if body.speed > 1.0:
			var from := 0
			for j: int in range(1, now.size()):
				# Sideways: how far the point has left the track it lay on a frame ago.
				var near := Geo.off_path_near(now[j], track, from)
				from = int(near.y)
				var moved := now[j].distance_to(last[j])  # its own speed: the drawn S runs faster
				worst = maxf(worst, near.x / maxf(moved, body.speed * DT))
		if not bad:
			for j: int in range(1, now.size() - 1):
				_tightest = minf(_tightest, Geo.bend_radius(now[j - 1], now[j], now[j + 1]))
		last = now
		track = now if bad else _weave(body).path(reach)
	return worst


## The body of the scripted route (straight, 90 deg turn, U-turn, stop).
func _route_joints() -> PackedVector2Array:
	var body := _cruising(NORTH, 4.0)
	for frame: int in 400:
		var stick := EAST if frame < 120 else (WEST if frame < 300 else Vector2.ZERO)
		_step(body, stick)
	return _joints(body, 0.0)
