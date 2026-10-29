extends RefCounted
## The big forms turn heavier and slower (D-187, director 2026-10-23: "Heavier, slower"; the VFX
## motion critic's bars): a U-turn while walking at full stick (the stick reversed) takes about
## 1.94 s as the Behemoth and 3 s as the Colossus, its yaw spread evenly over the steps (no snap on
## planted feet), the body not thrown about, the feet still stepping in real alternating steps. The
## young croc keeps its smooth turn (D-131): its turns are pinned to the numbers the base gave.
## Seeded by design: the sim is the gait suite's own, on the seeded city 0, at 60 Hz.

const DT := 1.0 / 60.0
const WALK_S := 3.0
const TURN_LIMIT_S := 8.0
const NORTH := Vector2(0, -1)
## The U-turn is made when the body is within this many degrees of the new way (the critic's).
const LAND_DEG := 5.0
## The U-turn takes this long (s), within U_TURN_TOL of it (D-187: the director's 2 s and 3 s; the
## Behemoth's is 1.94: the motion gate's centre_max 0.5 needs under ~1.97, lead 2026-10-27).
const U_TURN_S := {"Behemoth": 1.94, "Colossus": 3.0}
const U_TURN_TOL := 0.1
## The yaw rate never runs above this many times the turn's mean rate: spread evenly, not snapped.
const MAX_PEAK := 1.3
## The turn is started from four places in a step (the step clock's fraction at the reversal).
const SWINGS: Array[float] = [0.0, 0.25, 0.5, 0.75]
## Each foot lifts and comes down at least this many times through a U-turn.
const MIN_LIFTS := 2
## A real step moves its foot more than REAL_STEP of a foot length (the drawn foot bone, toe tip to
## foot joint, measured by the VFX lead 2026-10-23) from where it last stood; at least MIN_REAL
## real steps in a row, alternating feet, each turning the body at most MAX_STEP_YAW degrees.
const FOOT_LENGTH := {"Behemoth": 2.072, "Colossus": 3.706}
const REAL_STEP := 0.3
const MIN_REAL := 4
const MAX_STEP_YAW := 40.0
## No lunge: the body is not thrown about by the turn. The body's middle (a point under the feet,
## the torso) moves at most this many times the walk speed in any frame; the model's origin, which
## on the croc is the tail root and swings round the planted feet, at most ORIGIN_MAX times it.
## The origin's swing cannot fall below pi x its distance to the feet over the turn (D-177's
## pivot about the planted foot): 11.4 u/s at 1.94 s and 15 u/s at 3 s against a walk of 5.5 u/s.
const CENTRE_MAX := 1.9
const ORIGIN_MAX := 3.5
## The young croc's route: north, a U-turn south, a 90 deg turn west, a 60 deg turn back (stick, s).
const YOUNG_ROUTE := [
	[Vector2(0, -1), 3.0],
	[Vector2(0, 1), 3.0],
	[Vector2(-1, 0), 2.0],
	[Vector2(0.5, -0.866), 2.0],
]


## The U-turn at the reversal `swing` of a step into the walk: {t (s to within LAND_DEG), peak and
## mean yaw rate (rad/s), centre and origin (worst speed, units/s), walk (units/s), lifts (feet
## down: left, right), moves (units each foot moved on each footfall), yaws (degrees turned in
## each step)}.
static func u_turn(sim: RampageSim, swing: float) -> Dictionary:
	sim.kaiju_pos = Vector2(0.0, 30.0)
	for _n: int in roundi(WALK_S / DT):
		sim.step(DT, NORTH, false, 0)
	for _n: int in 120:  # on to the place in the step
		if fposmod(sim.body.phase, 1.0) >= swing:
			break
		sim.step(DT, NORTH, false, 0)
	var feet: Array[Vector2] = sim.body._feet
	var here := Num.i(floorf(sim.body.phase)) % 2
	var last: Array[Vector2] = [feet[1 - here], feet[1 - here]]
	last[here] = feet[0]
	var out := {
		"t": INF,
		"peak": 0.0,
		"mean": 0.0,
		"centre": 0.0,
		"origin": 0.0,
		"walk": sim.stat("speed") * sim.powers.speed_mult(),
		"lifts": [0, 0],
		"moves": [],
		"yaws": [],
		"last": last,  # where each foot last came down
		"footfall": floorf(sim.body.phase),
		"heading": sim.body.heading,
		"origin_at": sim.kaiju_pos,
		"middle_at": _middle(sim),
		"yaw": 0.0,  # turned since the last footfall
	}
	for n: int in roundi(TURN_LIMIT_S / DT):
		sim.step(DT, -NORTH, false, 0)
		_frame(sim, out)
		if absf(rad_to_deg(sim.body.heading.angle_to(-NORTH))) < LAND_DEG:
			out["t"] = (n + 1) * DT
			out["mean"] = (PI - deg_to_rad(LAND_DEG)) / Num.f(out["t"])
			break
	return out


## One frame of the turn: the yaw rate, how fast the body moved, and a footfall if there was one.
static func _frame(sim: RampageSim, out: Dictionary) -> void:
	var heading: Vector2 = out["heading"]
	var turned := absf(heading.angle_to(sim.body.heading))
	var middle := _middle(sim)
	var middle_at: Vector2 = out["middle_at"]
	var origin_at: Vector2 = out["origin_at"]
	out["peak"] = maxf(Num.f(out["peak"]), turned / DT)
	out["origin"] = maxf(Num.f(out["origin"]), sim.kaiju_pos.distance_to(origin_at) / DT)
	out["centre"] = maxf(Num.f(out["centre"]), middle.distance_to(middle_at) / DT)
	out["yaw"] = Num.f(out["yaw"]) + turned
	out["heading"] = sim.body.heading
	out["origin_at"] = sim.kaiju_pos
	out["middle_at"] = middle
	if floorf(sim.body.phase) == out["footfall"]:
		return
	out["footfall"] = floorf(sim.body.phase)
	var side := Num.i(out["footfall"]) % 2
	var now: Vector2 = sim.body._feet[0]  # the foot that has just come down
	var last: Array[Vector2] = out["last"]
	var lifts: Array = out["lifts"]
	var moves: Array = out["moves"]
	var yaws: Array = out["yaws"]
	lifts[side] = Num.i(lifts[side]) + 1
	moves.append(now.distance_to(last[side]))
	yaws.append(rad_to_deg(Num.f(out["yaw"])))
	last[side] = now
	out["yaw"] = 0.0


## A point on the body under its feet: where the feet come down on its middle line.
static func _middle(sim: RampageSim) -> Vector2:
	return sim.kaiju_pos + sim.body.heading * sim.body._pivot.x * sim.body_scale()


## The longest run of real steps in a row (each foot moved more than REAL_STEP of a foot length).
static func real_steps(stage: String, moves: Array) -> int:
	var run := 0
	var best := 0
	for move: float in moves:
		run = run + 1 if move > REAL_STEP * Num.f(FOOT_LENGTH[stage]) else 0
		best = maxi(best, run)
	return best


## The worst of each measure over the SWINGS, for one stage. make: levels -> RampageSim.
static func worst(make: Callable, stage: String, levels: Dictionary) -> Dictionary:
	var out := {"t_lo": INF, "t_hi": 0.0, "peak": 0.0, "centre": 0.0, "origin": 0.0, "yaw": 0.0}
	out["lifts"] = 99
	out["real"] = 99
	for swing: float in SWINGS:
		var sim: RampageSim = make.call(levels)
		var turn := u_turn(sim, swing)
		var t := Num.f(turn["t"])
		out["t_lo"] = minf(Num.f(out["t_lo"]), t)
		out["t_hi"] = maxf(Num.f(out["t_hi"]), t)
		out["peak"] = maxf(
			Num.f(out["peak"]), Num.f(turn["peak"]) / maxf(Num.f(turn["mean"]), 0.001)
		)
		out["centre"] = maxf(Num.f(out["centre"]), Num.f(turn["centre"]) / Num.f(turn["walk"]))
		out["origin"] = maxf(Num.f(out["origin"]), Num.f(turn["origin"]) / Num.f(turn["walk"]))
		var feet: Array = turn["lifts"]
		out["lifts"] = mini(Num.i(out["lifts"]), mini(Num.i(feet[0]), Num.i(feet[1])))
		var moves: Array = turn["moves"]
		out["real"] = mini(Num.i(out["real"]), real_steps(stage, moves))
		for each: float in turn["yaws"]:
			out["yaw"] = maxf(Num.f(out["yaw"]), each)
	return out


## The checks for the Behemoth and the Colossus. make: levels -> RampageSim.
static func check_big(check: Callable, make: Callable, stage: String, levels: Dictionary) -> void:
	var w := worst(make, stage, levels)
	var want: float = U_TURN_S[stage]
	var lo := want * (1.0 - U_TURN_TOL)
	var hi := want * (1.0 + U_TURN_TOL)
	(
		check
		. call(
			Num.f(w["t_lo"]) >= lo and Num.f(w["t_hi"]) <= hi,
			(
				(
					"%s: a U-turn while walking takes %.2f-%.2f s to come within %.0f deg of the new way"
					+ " (%.1f-%.1f s)"
				)
				% [stage, w["t_lo"], w["t_hi"], LAND_DEG, lo, hi]
			)
		)
	)
	check.call(
		Num.f(w["peak"]) <= MAX_PEAK,
		(
			"%s: the yaw is spread evenly, its peak rate %.2fx the turn's mean (<= %.1fx)"
			% [stage, w["peak"], MAX_PEAK]
		)
	)
	check.call(
		Num.f(w["centre"]) <= CENTRE_MAX and Num.f(w["origin"]) <= ORIGIN_MAX,
		(
			(
				"%s: no lunge, the body's middle moves at most %.2fx the walk (<= %.1fx),"
				+ " its origin %.2fx (<= %.1fx)"
			)
			% [stage, w["centre"], CENTRE_MAX, w["origin"], ORIGIN_MAX]
		)
	)
	check.call(
		Num.i(w["lifts"]) >= MIN_LIFTS,
		"%s: each foot comes down %d times in the U-turn (>= %d)" % [stage, w["lifts"], MIN_LIFTS]
	)
	(
		check
		. call(
			Num.i(w["real"]) >= MIN_REAL and Num.f(w["yaw"]) <= MAX_STEP_YAW,
			(
				(
					"%s: %d real alternating steps in a row (each foot moves > %.1f foot lengths; >= %d),"
					+ " at most %.0f deg of yaw a step (<= %.0f)"
				)
				% [stage, w["real"], REAL_STEP, MIN_REAL, w["yaw"], MAX_STEP_YAW]
			)
		)
	)


## The young croc's turns (D-131, "Baby turns smoothly"), the stick walked through four legs: for
## each, {pos (where it ends), heading (degrees it ends facing), stick (degrees the stick points),
## path (units walked), seconds, snap (most degrees turned in one frame)}.
static func young_legs(sim: RampageSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	sim.kaiju_pos = Vector2(0.0, 30.0)
	for leg: Array in YOUNG_ROUTE:
		var stick: Vector2 = leg[0]
		var path := 0.0
		var snap := 0.0
		for _n: int in roundi(Num.f(leg[1]) / DT):
			var was_pos := sim.kaiju_pos
			var was := _deg(sim.body.heading)
			sim.step(DT, stick, false, 0)
			path += sim.kaiju_pos.distance_to(was_pos)
			snap = maxf(
				snap, absf(angle_difference(deg_to_rad(was), deg_to_rad(_deg(sim.body.heading))))
			)
		var row := {
			"pos": sim.kaiju_pos,
			"heading": _deg(sim.body.heading),
			"stick": _deg(stick),
			"path": path,
			"seconds": Num.f(leg[1]),
			"snap": rad_to_deg(snap),
		}
		out.append(row)
	return out


## Degrees a heading faces, 0 north (-z), 90 east.
static func _deg(h: Vector2) -> float:
	return rad_to_deg(atan2(h.x, -h.y))
