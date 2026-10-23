class_name SerpentStopChecks
extends RefCounted
## The serpent suite's proportion, turn, stop and camera checks (tests/run_serpent_tests.gd runs
## them as one helper; split out to keep each file under the project's length limit): the body's
## proportions and gait against the reference, the S kept through a U-turn and the head's
## wind-up, the defensive coil after a stop (D-210) and the camera's framing, steadiness and
## settle, in screen terms.

const DT := 1.0 / 60.0
const NORTH := Vector2(0, -1)
const EAST := Vector2(1, 0)
const WEST := Vector2(-1, 0)
const SOUTH_EAST := Vector2(0.08, 1.0)
const STILL_SPEED := 0.15
const CAMERA_SETTLE_S := 0.5

const Geo := preload("res://tests/lib/serpent_geometry.gd")

var check: Callable
var _cfg: Dictionary = Content.section("serpent")
## Each test body's drawn S (SerpentWeave), by the body's instance id.
var _weaves: Dictionary = {}
## Tongue, jab and look seen over the last idle run.
var _jab_seen := 0.0
var _look_seen := 0.0


func _init(p_check: Callable) -> void:
	check = p_check


func run() -> void:
	_proportions()
	_turn_reads()
	_stop_settles()
	_camera_steady(true)
	_camera_steady(false)


## Let go of the stick: the head eases to a halt and never travels again (the sim head, its
## centreline and the drawn head stay put). The body draws itself into a defensive coil (D-210):
## stacked loops a few metres high with the head raised above the pile, the chain still whole,
## and inside the footprint the S had (within the swing and the girth of the sim's centreline).
## Then it idles on the coil: the tongue flicks, the head jabs and looks about, and the body
## stays about its coiled shape and does not drift. A body that keeps straightening after the
## stop drifts and fails.
func _stop_settles() -> void:
	var coil_s := Num.f(_cfg["coil_s"])
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
		var line := PackedVector2Array()
		for k: int in 70:
			line.append(body.centre_at(k * 1.0))
		for _j: int in int((coil_s + 0.2) / DT):
			_step(body, Vector2.ZERO)
			drawn.update(body, DT)
		var coiled := drawn.joints.duplicate()
		var heights := drawn.lifts.duplicate()
		var idle := _idle(drawn, body, bad, coiled)
		var travel := body.pos.distance_to(head) + body.centre_at(20.0).distance_to(centre)
		var tallest := 0.0
		var outside := 0.0
		var broken := 0.0
		var seg := body.length() / Num.i(_cfg["segments"])
		for j: int in coiled.size():
			tallest = maxf(tallest, heights[j])
			outside = maxf(outside, Geo.off_path(coiled[j], line))
			if j > 0:  # in 3D: the neck rises steeply out of the coil
				var a := Vector3(coiled[j].x, heights[j], coiled[j].y)
				var b := Vector3(coiled[j - 1].x, heights[j - 1], coiled[j - 1].y)
				broken = maxf(broken, absf(a.distance_to(b) - seg) / seg)
		var reach := SerpentCoil.reach(coiled, coiled[0])
		drawn.free()
		if bad:
			check.call(idle.z > 0.05, "the drift measure catches a body still straightening")
			continue
		var girth := Num.f(_cfg["girth"])
		var swing := Num.f(_cfg["wave_amp"]) * (1.0 + Num.f(_cfg["wave_wobble_amp"]))
		print("serpent: stops %.2f s after let-go; coiled in %.1f s" % [frames * DT, coil_s])
		var shape := "serpent: coil %.1f m from the head at most, %.1f m off the S's centreline "
		shape += "(bar %.1f), %.1f m high, head %.1f m up"
		print(shape % [reach, outside, swing + girth, tallest, heights[0]])
		var live := "serpent: idle moves up to %.4f m a frame, %.2f m off its coil, drifts %.4f m; "
		live += "tongue out %.2f, jab %.2f m, look %.2f rad"
		print(live % [idle.x, idle.y, idle.z, idle.w, _jab_seen, _look_seen])
		check.call(travel == 0.0, "nothing travels once the head has stopped")
		check.call(
			outside <= swing + girth, "the coil stays inside the S's footprint (%.1f m)" % outside
		)
		var head_top := 0.0  # the head tips nose-down toward the camera: its highest joint
		for j: int in int(Num.f(_cfg["head_len"])) + 1:
			head_top = maxf(head_top, heights[j])
		check.call(
			tallest >= 3.0 and head_top > tallest - 0.01, "stacked loops, the head raised above them"
		)
		check.call(
			broken < 0.02, "the coil keeps the chain whole (%.3f off a joint spacing)" % broken
		)
		check.call(
			idle.w > 0.9 and _jab_seen > 0.3 and _look_seen > 0.1,
			"the tongue flicks, the head jabs and looks about"
		)
		check.call(idle.x < 0.3 and idle.y < 2.0, "the idle moves about its coil")
		check.call(idle.z < 0.05, "the idle does not drift")


## Ten seconds of idle after the coil: (most motion a frame, most distance from the coiled shape,
## how far the body's mean over the run is from the coiled mean, most the tongue was out).
func _idle(
	drawn: SerpentStandIn, body: SerpentBody, bad: bool, coiled: PackedVector2Array
) -> Vector4:
	var frames := int(10.0 / DT)
	var moved := 0.0
	var off := 0.0
	var tongue := 0.0
	var mean := Vector2.ZERO
	var coiled_mean := Vector2.ZERO
	_jab_seen = 0.0
	_look_seen = 0.0
	for p: Vector2 in coiled:
		coiled_mean += p / coiled.size()
	var last := coiled
	for k: int in frames:
		_step(body, Vector2.ZERO)
		drawn.update(body, DT)
		var now := _joints_with(drawn, body, bad, k + 1)
		for j: int in now.size():
			moved = maxf(moved, now[j].distance_to(last[j]))
			off = maxf(off, now[j].distance_to(coiled[j]))
			mean += now[j] / (now.size() * frames)
		tongue = maxf(tongue, drawn.tongue)
		_jab_seen = maxf(_jab_seen, drawn.jab)
		_look_seen = maxf(_look_seen, absf(drawn.look))
		last = now
	return Vector4(moved, off, mean.distance_to(coiled_mean), tongue)


## The body's proportions and gait against the reference (Hu et al. PNAS 2009, PMC2700932: snakes
## about 30 body widths long, 0.4 body lengths a wave, 0.1 a side swing, 0.5 Hz, 0.11-0.2 body
## lengths a second; cobras 35-40 widths): 25-40 girths long, 1.5-2 waves along it, a swing near the
## ruled 6 m a side, a wave 0.4-1 Hz, 0.1-0.25 body lengths a second forward; the S not a clean
## sine (the crests differ), with a counter-curve each way; a head wider than the neck behind it,
## a tail that thins to a tip.
func _proportions() -> void:
	check.call(not _slender(40.0, 3.6), "the proportion measure catches round 3's short thick body")
	var length := Num.f(_cfg["length"])
	var girth := Num.f(_cfg["girth"])
	var waves := length / Num.f(_cfg["wave_length"])
	var body := _cruising(NORTH, 14.0)
	var joints := _joints(body, 0.0)
	var lo := INF
	var hi := -INF
	for p: Vector2 in joints:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	var swing := (hi - lo) * 0.5
	var hz := _weave(body).drawn.head_speed / Num.f(_cfg["wave_length"])
	var bl_s := body.speed / length
	var crests := _crests(joints)
	var inflect := Geo.inflections(joints, length / Num.i(_cfg["segments"]))
	var varied := 0.0
	var weakest := INF
	var strongest := 0.0
	for k: int in crests.size():
		weakest = minf(weakest, crests[k])
		strongest = maxf(strongest, crests[k])
	if weakest < INF:
		varied = strongest / maxf(weakest, 0.0001)
	var tube := SerpentTube.new(_cfg)
	var head := tube.width_at(2.0, 1.0)
	var neck := tube.width_at(3.2, 1.0)
	var tip := tube.width_at(length, 1.0)
	var mid := tube.width_at(length * 0.4, 1.0)
	tube.free()
	var line := "serpent: %.0f girths long (%.1f m by %.1f m), %.2f waves, swing %.1f m a side, "
	line += "wave %.2f Hz, %.2f body lengths a second; crests differ x%.2f, %d inflections; "
	line += "head %.2f m, neck %.2f m, body %.2f m, tail tip %.2f m wide"
	print(
		(
			line
			% [
				length / girth,
				length,
				girth,
				waves,
				swing,
				hz,
				bl_s,
				varied,
				inflect.size(),
				head,
				neck,
				mid,
				tip
			]
		)
	)
	check.call(_slender(length, girth), "the body is 25-40 girths long")
	check.call(waves >= 1.5 and waves <= 2.0, "1.5-2 waves along the body")
	check.call(
		absf(swing - Num.f(_cfg["wave_amp"])) < 1.5, "the swing is near the ruled 6 m a side"
	)
	check.call(hz >= 0.4 and hz <= 1.0, "the wave runs at 0.4-1 Hz")
	check.call(bl_s >= 0.1 and bl_s <= 0.25, "it covers 0.1-0.25 body lengths a second")
	check.call(varied >= 1.08, "no two crests alike (the S is not a clean sine)")
	check.call(inflect.size() >= 2, "a counter-curve each way along the body")
	check.call(
		head > neck * 1.3 and mid > neck * 1.5, "a head wider than its neck, a body wider again"
	)
	check.call(tip <= 0.12 and tip < mid * 0.1, "the tail thins to a tip")


## True when a body `length` long and `girth` wide is 25-40 girths long.
func _slender(length: float, girth: float) -> bool:
	return length / girth >= 25.0 and length / girth <= 40.0


## The strongest bend (rad per m) at each crest of a body's joints, in order down the body.
func _crests(joints: PackedVector2Array) -> PackedFloat32Array:
	var seg := joints[0].distance_to(joints[1])
	var out := PackedFloat32Array()
	var best := 0.0
	var side := 0.0
	for j: int in range(1, joints.size() - 1):
		var bend := (joints[j - 1] - joints[j]).angle_to(joints[j] - joints[j + 1]) / seg
		if signf(bend) != side and side != 0.0:
			out.append(best)
			best = 0.0
		side = signf(bend)
		best = maxf(best, absf(bend))
	return out


## Turning and winding up. A U-turn keeps a counter-curve along the body (varied curvature, not a
## uniform horseshoe: the S bends both ways through the turn), and a turn asked for from a straight
## run first cocks the head away and rears it (the wind-up) before it looks into the turn.
func _turn_reads() -> void:
	var body := SerpentBody.new(_cfg, Vector2.ZERO, NORTH)
	_weaves[body.get_instance_id()] = SerpentWeave.new(body)
	var drawn := SerpentStandIn.new(_cfg)
	for _i: int in int(14.0 / DT):
		_step(body, NORTH)
		drawn.update(body, DT)
	var most_bends := 0
	var cocked := 0.0
	var rear := 0.0
	var into := 0.0
	for frame: int in 240:
		_step(body, WEST)  # a U-turn: the heading swings through 180 deg
		drawn.update(body, DT)
		if frame < 20:  # the wind-up, then the lead
			cocked = maxf(cocked, drawn.lead)  # a left turn: cocked right (positive)
			rear = maxf(rear, drawn.raised)
		else:
			into = minf(into, drawn.lead)
		if frame > 40 and frame < 120 and frame % 10 == 0:
			most_bends = maxi(most_bends, Geo.inflections(drawn.joints, 1.0).size())
	var line := "serpent: U-turn keeps %d inflections along the body; head cocked %.2f rad away "
	line += "and reared %.2f m before it looks %.2f rad into the turn"
	print(line % [most_bends, cocked, rear, -into])
	drawn.free()
	check.call(most_bends >= 2, "a U-turn keeps a counter-curve (varied curvature)")
	check.call(cocked > 0.1 and rear > 0.3, "the head cocks away and rears before a turn")
	check.call(into < -0.15, "then it looks into the turn")


## The serpent's camera (in screen terms, 1080p, the game's field of view): on a long leg the head
## has room ahead of it along its heading (north: it rides 35-46% down the frame, so 35% or more
## lies ahead; east: 50-70% of the way across), through a turn, a U-turn and a stop its yaw and
## pitch never change, and after the head stops the camera is still within 0.5 s.
func _camera_steady(bad: bool) -> void:
	var cfg := _cfg.duplicate()
	if bad:  # a slow follow, as round 3 had
		cfg["camera_follow_s"] = 0.9
	var body := _cruising(NORTH, 6.0)
	var fov := CameraTuning.fov()
	var moving := Vector3(body.heading.x, 0.0, body.heading.y) * body.speed
	var cam := SerpentCamera.new(cfg, SerpentCamera.target(cfg, body), moving)
	var first := cam.step(SerpentCamera.target(cfg, body), 0.0).basis
	var turned := 0.0
	var high := 0.0
	var low := 1.0
	var across := Vector2(1.0, 0.0)
	var eyes := PackedVector3Array()
	var stopped := -1
	for frame: int in 700:
		var stick := NORTH if frame < 180 else (EAST if frame < 360 else SOUTH_EAST)
		_step(body, Vector2.ZERO if frame >= 450 else stick)
		var t := cam.follow(body, DT)
		turned = maxf(turned, (t.basis.z - first.z).length())
		eyes.append(t.origin)
		var head := Vector3(body.pos.x, 0.0, body.pos.y)
		if frame >= 60 and frame < 180:
			var down := SerpentCamera.screen_down(t, fov, head)
			high = maxf(high, down)
			low = minf(low, down)
		if frame >= 330 and frame < 360:
			var x := SerpentCamera.screen_across(t, fov, head)
			across = Vector2(minf(across.x, x), maxf(across.y, x))
		if stopped < 0 and frame >= 450 and body.speed <= 0.0:
			stopped = frame
	var n := eyes.size()
	var last_fast := 0
	for i: int in range(1, n):
		if eyes[i].distance_to(eyes[i - 1]) / DT > STILL_SPEED:
			last_fast = i
	var settle_s := (last_fast - stopped) * DT
	if bad:
		check.call(settle_s > CAMERA_SETTLE_S, "the settle measure catches a slow camera")
		return
	if bad:
		check.call(settle_s > CAMERA_SETTLE_S, "the settle measure catches a slow camera")
		return
	var line := "serpent: head %.0f-%.0f%% down the frame going north, %.0f-%.0f%% across going "
	line += "east; camera turned %.6f; still %.2f s after the head stopped (bar %.1f)"
	print(
		(
			line
			% [
				low * 100.0,
				high * 100.0,
				across.x * 100.0,
				across.y * 100.0,
				turned,
				settle_s,
				CAMERA_SETTLE_S
			]
		)
	)
	check.call(
		low >= 0.35 and high <= 0.46, "going north the head has 35% or more of the frame ahead"
	)
	check.call(across.x >= 0.50 and across.y <= 0.70, "going east the head has 30% or more ahead")
	check.call(turned == 0.0, "the serpent's camera never swings with a turn")
	check.call(
		stopped > 0 and settle_s <= CAMERA_SETTLE_S, "the camera is still within 0.5 s of the stop"
	)


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
	var weave: SerpentWeave = _weaves[body.get_instance_id()]
	weave.step(body, DT)


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


## The weave of `body` (the one `_cruising` and `_step` keep up with it).
func _weave(body: SerpentBody) -> SerpentWeave:
	var weave: SerpentWeave = _weaves[body.get_instance_id()]
	return weave


## The drawn joints of `body` along its weave's path.
func _joints(body: SerpentBody, _clock: float) -> PackedVector2Array:
	var count := Num.i(_cfg["segments"])
	var seg := body.length() / count
	return SerpentWeave.joints(_weave(body).path(body.length() + seg), seg, count)
