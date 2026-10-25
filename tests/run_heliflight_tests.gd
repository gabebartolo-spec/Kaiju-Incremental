extends "res://tests/lib/sim_suite.gd"
## How the helicopters fly (AirFlight, D-183 "Stand-off gunships", motion first D-177): at every
## growth step (young, Behemoth, Colossus) three helicopters fire on a kaiju that walks the city
## for 120 s. Outside a strafing pass none comes within the claw band's reach; none jumps further
## in a step than its top speed; none turns faster than its turn limit; none crosses to the
## camera's side; and a strafing pass does happen (one helicopter at a time), bringing its
## helicopter into the claw band. Same seed, same flights. Player-effect fixture "heli.standoff":
## the same kaiju on the old orbit let helicopters dive to a fifth of a circle and turn right
## round at the ends of an arc. Headless.
## Seeded by design: every sim is Seeds.make("army", 0) on the seeded city 0 of its growth step.
##   godot --headless --path . --script tests/run_heliflight_tests.gd

const SECONDS := 120.0
const HELIS := 3
## The jitter bar: the highest turn rate (degrees a second, over 0.5 s) a helicopter holds in
## one direction and then the other (the old orbit measured 250-350); and the most it may go
## round the kaiju in 10 s outside a pass (his own turns carry them round too).
const TWITCH_DEG := 90.0
const SWEEP_DEG := 200.0
const LEVELS := [{}, {"evolve1": 1}, {"evolve1": 1, "evolve2": 1}]
const NAMES := ["young", "Behemoth", "Colossus"]


func suite_name() -> String:
	return "HeliFlight"


func run_checks() -> void:
	for step: int in LEVELS.size():
		await _t("_check_flight", [step])
	await _t("_check_replay")


## A rampage at growth step `step` (0 young, 1 Behemoth, 2 Colossus), the city grown to match.
func _step_sim(step: int) -> RampageSim:
	var tuning := CityGrowth.tuning_for(Content.tuning(), step + 1)
	var levels: Dictionary = LEVELS[step]
	var sim := _sim("reptilian", levels, 0, tuning)
	sim.time_left = 1.0e9
	return sim


## The scripted player: walks to the nearest standing building and smashes it, healed to full
## each step so the run goes on (the helicopters' fire is not what is measured).
func _walk(sim: RampageSim, n: int, target: Vector2) -> Vector2:
	var aim := sim.nearest_standing(sim.kaiju_pos) if n % 15 == 0 else target
	var near := aim.x < INF and sim.kaiju_pos.distance_to(aim) > sim.stomp_radius() * 0.5
	sim.step(DT, (aim - sim.kaiju_pos).normalized() if near else Vector2.ZERO, false)
	sim.hp = sim.max_hp
	return aim


## The numbers of `seconds` of `sim` with `HELIS` helicopters in the sky: the closest any got
## outside a pass, the closest in one, the fastest step, the sharpest turn, the nearest to the
## camera's side (radians off it), the passes begun and the most flying one at a time.
func _fly(sim: RampageSim, seconds: float) -> Dictionary:
	var air: Dictionary = Content.section("air")
	var bearing := deg_to_rad(Num.f(air["camera_bearing"]))
	var slow := Num.f(air["nose_share"]) * Num.f(air["heli_speed"])  # slower than this it hovers
	for _n: int in HELIS:
		sim.air.spawn()
	var out := {
		"hold": INF,
		"pass": INF,
		"speed": 0.0,
		"turn": 0.0,
		"side": PI,
		"lane": INF,
		"passes": 0,
		"most": 0,
		"twitch": 0.0,
		"marks": {},
		"swung": {},
		"bear": {},
		"sweep": 0.0
	}
	var last: Dictionary = {}  # id -> position last step
	var way: Dictionary = {}  # id -> direction of its move last step (absent: it was slow)
	var flying: Dictionary = {}  # id -> was on a pass last step
	var target := Vector2(INF, INF)
	for n: int in roundi(seconds / DT):
		target = _walk(sim, n, target)
		var passing := 0
		for heli: AirWing.Heli in sim.air.helis:
			var away := heli.pos - sim.kaiju_pos
			var key := "pass" if heli.passing else "hold"
			out[key] = minf(Num.f(out[key]), away.length())
			var toward := Vector2.from_angle(bearing)
			var seen := heli.pos - sim.air.flight.anchor()  # the camera follows his smoothed position
			if seen.dot(toward) > 0.0:  # a pass may cross the camera's side, never between it and him
				out["lane"] = minf(Num.f(out["lane"]), absf(seen.dot(toward.orthogonal())))
			out["side"] = minf(Num.f(out["side"]), absf(wrapf(heli.slot - bearing, -PI, PI)))
			passing += 1 if heli.passing else 0
			var was: bool = flying.get(heli.id, false)
			if heli.passing and not was:
				out["passes"] = Num.i(out["passes"]) + 1
			flying[heli.id] = heli.passing
			if last.has(heli.id):
				var moved: Vector2 = heli.pos - last[heli.id]
				out["speed"] = maxf(Num.f(out["speed"]), moved.length() / DT)
				if moved.length() / DT >= slow:  # a turn is judged between two steps of real flying
					if way.has(heli.id):
						var swing := absf(wrapf(moved.angle() - Num.f(way[heli.id]), -PI, PI))
						out["turn"] = maxf(Num.f(out["turn"]), swing)
					way[heli.id] = moved.angle()
				else:
					way.erase(heli.id)
			last[heli.id] = heli.pos
			_mark(out, heli, away, n % roundi(0.5 / DT) == 0)
		out["most"] = maxi(Num.i(out["most"]), passing)
	return out


## Every 0.5 s (a mark) a helicopter's course is compared with its last: `twitch` is the highest
## turn rate (degrees a second) it held for two marks running in opposite directions (a flutter,
## left then right), `sweep` the most it went round the kaiju in any 10 s outside a pass (radians).
func _mark(out: Dictionary, heli: AirWing.Heli, away: Vector2, on_mark: bool) -> void:
	var bear: Dictionary = out["bear"]
	var path: Array = bear.get(heli.id, [])
	if heli.passing:
		path.clear()  # a pass is not an orbit
	path.append(away.angle())
	bear[heli.id] = path
	if path.size() > roundi(10.0 / DT):
		path.pop_front()
		if not heli.passing:
			var total := 0.0
			for i: int in range(1, path.size()):
				total += wrapf(Num.f(path[i]) - Num.f(path[i - 1]), -PI, PI)
			out["sweep"] = maxf(Num.f(out["sweep"]), absf(total))
	if not on_mark:
		return
	var marks: Dictionary = out["marks"]
	var mark: Array = marks.get(heli.id, [])
	var then: Vector2 = heli.pos
	var before := Vector2.ZERO
	if not mark.is_empty():
		then = mark[0]
		before = mark[1]
	var now: Vector2 = heli.pos - then
	marks[heli.id] = [heli.pos, now]
	if mark.is_empty():
		return
	var air: Dictionary = Content.section("air")
	var least := Num.f(air["nose_share"]) * Num.f(air["heli_speed"]) * 0.5
	var swung: Dictionary = out["swung"]
	if now.length() < least or before.length() < least:
		swung.erase(heli.id)
		return
	var rate := rad_to_deg(wrapf(now.angle() - before.angle(), -PI, PI)) / 0.5
	var prev: float = swung.get(heli.id, 0.0)
	if prev * rate < 0.0:
		out["twitch"] = maxf(Num.f(out["twitch"]), minf(absf(prev), absf(rate)))
	swung[heli.id] = rate


func _check_flight(step: int) -> void:
	var sim := _step_sim(step)
	var air: Dictionary = Content.section("air")
	var bs := sim.body_scale()
	var far := Num.f(sim.powers_cfg["swipe_far"]) * bs
	var claw := Vector2(far, sim.stat("swipe_width") * bs).length() + Num.f(air["heli_radius"])
	var ring := Num.f(air["standoff"]) * bs
	var flew := _fly(sim, SECONDS)
	var label := str(NAMES[step])
	check(
		Num.f(flew["hold"]) > claw,
		(
			"%s: outside a pass none comes within the claw band (closest %.1f, claw %.1f, ring %.1f)"
			% [label, Num.f(flew["hold"]), claw, ring]
		)
	)
	var top := Num.f(air["heli_speed"])
	check(
		Num.f(flew["speed"]) <= top + 0.01,
		(
			"%s: no helicopter moves faster than %.0f units a second (%.2f)"
			% [label, top, Num.f(flew["speed"])]
		)
	)
	var swing := deg_to_rad(Num.f(air["heli_turn_deg"])) * DT
	check(
		Num.f(flew["turn"]) <= swing + 0.001,
		(
			"%s: no helicopter turns more than %.1f degrees a step (%.1f)"
			% [label, rad_to_deg(swing), rad_to_deg(Num.f(flew["turn"]))]
		)
	)
	check(
		Num.f(flew["twitch"]) <= TWITCH_DEG,
		(
			"%s: no flutter, left then right, faster than %.0f degrees a second (%.0f)"
			% [label, TWITCH_DEG, Num.f(flew["twitch"])]
		)
	)
	check(
		rad_to_deg(Num.f(flew["sweep"])) <= SWEEP_DEG,
		(
			"%s: no orbiting, at most %.0f degrees round him in 10 s (%.0f)"
			% [label, SWEEP_DEG, rad_to_deg(Num.f(flew["sweep"]))]
		)
	)
	var arc := deg_to_rad(Num.f(air["clear_arc"]))
	check(
		Num.f(flew["side"]) >= arc - 0.02,
		(
			"%s: their slots stay %.0f degrees off the camera's side (%.0f)"
			% [label, rad_to_deg(arc), rad_to_deg(Num.f(flew["side"]))]
		)
	)
	var lane := Num.f(air["pass_corridor"]) * bs
	check(
		Num.f(flew["lane"]) >= lane,
		(
			"%s: a pass never flies between the camera and him (%.1f from the camera's line, corridor %.1f)"
			% [label, Num.f(flew["lane"]), lane]
		)
	)
	check(
		Num.i(flew["passes"]) >= 1 and Num.i(flew["most"]) == 1,
		(
			"%s: strafing passes happen, one helicopter at a time (%d passes, %d at once)"
			% [label, Num.i(flew["passes"]), Num.i(flew["most"])]
		)
	)
	check(
		Num.f(flew["pass"]) <= far,
		(
			"%s: a pass brings its helicopter into the claw band (%.1f of %.1f)"
			% [label, Num.f(flew["pass"]), far]
		)
	)


## The same seed flies the same: two Behemoth runs end with every helicopter where it was.
func _check_replay() -> void:
	var ends: Array[Array] = []
	for _run_n: int in 2:
		var sim := _step_sim(1)
		_fly(sim, 40.0)
		var spots: Array[Vector2] = []
		for heli: AirWing.Heli in sim.air.helis:
			spots.append(heli.pos)
		ends.append(spots)
	var first: Array = ends[0]
	var second: Array = ends[1]
	check(
		not first.is_empty() and first == second,
		"two runs of the same seed leave the helicopters in the same places (%d)" % first.size()
	)
