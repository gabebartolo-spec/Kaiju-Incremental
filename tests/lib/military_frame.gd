extends "res://tests/lib/military_air.gd"
## The military suite's framing through the game camera (D-066 r4), kept apart so
## military_view.gd stays under its line cap: the test's own camera (rampage.gd's numbers,
## pinned to the real camera by the view check) and the per-stage tally of helicopters whole
## in the frame and clear of the HUD over the suite's whole rampages.

## Share of the screen kept clear at each edge.
const FRAME_MARGIN := 0.04
## The game camera as rampage.gd places it: CAMERA_OFFSET x (ZOOM.x + ZOOM.y x body scale),
## looking at LOOK x body scale over the kaiju, FOV degrees up the screen (pinned below).
const ZOOM := Vector2(0.75, 0.4)
const LOOK := 3.5
const FOV := 55.0
const SCREEN := Vector2(1920, 1080)

var _hud_px: Array[Rect2] = []  # the HUD's plates in the clip's scene (pixels)
var _tally := {}  # stage tier -> its columns (_tally_frame)


## Helicopters up from the start, as many as the stage allows.
static func _open_sky(sim: RampageSim) -> void:
	sim.air.cfg["after_chunks"] = 0
	sim.air.cfg["interval"] = 0.8
	sim.chunks_destroyed = Num.i(sim.air.cfg["max_per_chunks"]) * 3


## Tallies stage `tier`'s step through the test's own camera (_project): each helicopter whole
## in the frame and off the HUD or not, whether its bearing has room in the frame at all (where
## none has, it holds off-screen: LEAD 2026-10-19), each burst fired from out of sight, and the
## steps with one in sight. Columns: steps, steps with one seen, heli-steps, seen, with room,
## seen with room, bursts, bursts unseen.
func _tally_frame(sim: RampageSim, tier: int) -> void:
	var t: Array = _tally.get(tier, [0, 0, 0, 0, 0, 0, 0, 0])
	t[0] = Num.i(t[0]) + 1
	var any := 0
	var seen := {}
	for heli: AirWing.Heli in sim.air.helis:
		var cruise := maxf(heli.cruise, sim.air.attack_radius())
		var room := sim.air.space.reach(heli.angle, sim.air.attack_radius(), cruise) >= 0.0
		var whole := _whole(sim, heli)
		seen[heli.id] = whole
		any = 1 if whole else any
		t[2] = Num.i(t[2]) + 1
		t[3] = Num.i(t[3]) + (1 if whole else 0)
		t[4] = Num.i(t[4]) + (1 if room else 0)
		t[5] = Num.i(t[5]) + (1 if room and whole else 0)
	t[1] = Num.i(t[1]) + any
	for event: Dictionary in sim.events:
		if str(event["type"]) == "heli_fired":
			t[6] = Num.i(t[6]) + 1
			t[7] = Num.i(t[7]) + (0 if seen.get(Num.i(event["heli"]), false) else 1)
	_tally[tier] = t


## Is the airframe whole inside the frame's margin and clear of every HUD plate?
func _whole(sim: RampageSim, heli: AirWing.Heli) -> bool:
	var lo := SCREEN * FRAME_MARGIN
	for p: Vector3 in _airframe(heli):
		var s := _project(sim, p)
		var on := Vector2(s.x, s.y)
		if s.z <= 0.0 or on.x < lo.x or on.y < lo.y or on.x > SCREEN.x - lo.x:
			return false
		if on.y > SCREEN.y - lo.y:
			return false
		for plate: Rect2 in _hud_px:
			if plate.has_point(on):
				return false
	return true


## Per stage, through the test's own camera over the suite's rampages: no burst fired from out
## of sight, and whole in sight on 95% of the helicopter-steps whose bearing has room.
func _check_framing() -> void:
	var ok := not _hud_px.is_empty()
	var table := ""
	for tier: int in _tally:
		var t: Array = _tally[tier]
		if Num.i(t[2]) == 0:
			continue
		var with_room := Num.f(t[5]) / maxf(1.0, Num.f(t[4]))
		ok = ok and Num.i(t[4]) > 300 and with_room >= 0.95 and Num.i(t[7]) == 0
		table += (
			(
				"\nVIEW tier %d rampages: one or more helicopters in sight %.1f%% of %d steps;"
				+ " heli whole in sight %.1f%% of %d heli-steps, %.1f%% of the %d with room;"
				+ " bursts %d, from out of sight %d"
			)
			% [
				tier,
				100.0 * Num.f(t[1]) / maxf(1.0, Num.f(t[0])),
				t[0],
				100.0 * Num.f(t[3]) / maxf(1.0, Num.f(t[2])),
				t[2],
				with_room * 100.0,
				t[4],
				t[6],
				t[7]
			]
		)
	print(table)
	check(ok, "helicopters fire only in sight and stay in sight where there is room:%s" % table)


## Where the game camera stands for the kaiju as it is now (rampage.gd's own numbers).
static func _eye(sim: RampageSim) -> Vector3:
	var k := Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
	return k + Rampage.CAMERA_OFFSET * (ZOOM.x + ZOOM.y * sim.body_scale())


## World point p on the 1920 x 1080 screen through the game camera: (x, y, depth).
static func _project(sim: RampageSim, p: Vector3) -> Vector3:
	var eye := _eye(sim)
	var k := Vector3(sim.kaiju_pos.x, LOOK * sim.body_scale(), sim.kaiju_pos.y)
	var fwd := (k - eye).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd)
	var v := p - eye
	var depth := v.dot(fwd)
	if depth <= 0.01:
		return Vector3(0, 0, -1)
	var half := tan(deg_to_rad(FOV) * 0.5)
	var x := 0.5 + v.dot(right) / (depth * half * 2.0 * SCREEN.x / SCREEN.y)
	var y := 0.5 - v.dot(up) / (depth * half * 2.0)
	return Vector3(x * SCREEN.x, y * SCREEN.y, depth)


## The airframe's extremes: nose and tail, and round the main rotor's disc.
static func _airframe(heli: AirWing.Heli) -> Array[Vector3]:
	var nose := heli.front if heli.front != Vector2.ZERO else Vector2(0, -1)
	var c := Vector3(heli.pos.x, heli.alt, heli.pos.y)
	var along := Vector3(nose.x, 0, nose.y) * HELI_HALF
	var points: Array[Vector3] = [c + along, c - along]
	for k: int in 8:
		var d := Vector2.from_angle(k * TAU / 8.0) * 3.3  # the main rotor's radius
		points.append(c + Vector3(d.x, 2.2, d.y))
	return points
