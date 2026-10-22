extends RefCounted
## The kaiju steps its turns (director comments #16 and 2026-10-21 #3: "step rather than
## swivelling on the spot like a plastic toy"; #31 "bigger = slower but not TOO slow"). The
## reptilian, driven by the real sim the way the rampage scene drives it (60 Hz), walks north and
## the stick swings west. The adult's 90 deg turn takes time, alternating feet step it, the body
## never yaws with both feet up, and a planted foot holds its spot; the baby turns smoothly at
## its pre-stepped rates (D-131, "Baby turns smoothly").

const DT := 1.0 / 60.0
const ADULT := {"evolve1": 1, "evolve2": 1}
const WALK_S := 3.0
## A turn's length depends on where in a step the stick swings, so the adult turns from four
## places in the step (the step clock's fraction at the swing, within SWING_NEAR of each): the
## turn's average length is the bar, every one must pass the rest and none may drag past
## SLOWEST_TURN_S.
const SWINGS := [0.0, 0.25, 0.5, 0.75]
const SWING_NEAR := 0.1
const SLOWEST_TURN_S := 1.4
const TURN_S := 3.0
## The adult's 90 deg turn takes this long (s): lumbering, not a swivel, "but not TOO slow".
const MIN_TURN_S := 1.0
const MAX_TURN_S := 1.25
## Distinct footfalls (alternating feet; a foot re-stepping after itself is a shuffle) in it.
const MIN_STEPS := 3
## The baby's smooth 90 deg turn (D-131), measured 2026-10-21 at its pre-stepped rates (turn-weight
## d24fe80e), and the share it may move.
const BABY_TURN_S := 0.60
const BABY_SHARE := 0.1
## Each footfall turns the body a slice, a smooth bell (the motion critic's bar: no frame-to-frame
## change in yaw rate over 25% of its peak) that rises and falls inside the step: at least this
## share of the turn's yaw comes in the SLICE_S seconds after a footfall (a swivel spreads it over
## all of it; a step is 0.3 s at the turn's cadence), and the yaw rate never jumps by more than
## MAX_JUMP.
const SLICE_SHARE := 0.8
const SLICE_S := 0.24
const MAX_JUMP := 0.25
## The turn is made when the yaw still to turn is under this (rad, about 1 deg).
const LANDED := 0.02
## A yaw this small in one frame is no turn (rad).
const STILL_YAW := 0.0005
## A planted foot may drift at most this far (cm; a world unit is a 3.5 m storey).
const MAX_DRIFT_CM := 5.0
const CM_PER_UNIT := 350.0
## A planted foot's toes may yaw at most this far in the world while it stays down (deg): the body
## turns over a planted foot, which holds its yaw (motion critic 2026-10-22: toes pivoted 40-50).
const MAX_FOOT_YAW_DEG := 12.0
## A foot skates when it is within SKATE_LOW (world units) of the ground and sweeps over it faster
## than SKATE_SPEED (units/s) in the world (motion critic 2026-10-22: planted-looking feet gliding
## over the ground in a turn). A turn may skate no more per second than the plain walk before it
## does (heel and toe slide a little in the clip), times SKATE_SHARE.
const SKATE_LOW := 0.08
const SKATE_SPEED := 3.0
const SKATE_SHARE := 1.0
## The sim's step length may differ this much from half the walk clip's stride.
const STEP_LEN_TOL := 0.02


static func check(check: Callable, root: Node) -> void:
	var adult := _adult(root)
	var took: float = adult["took"]
	(
		check
		. call(
			took >= MIN_TURN_S and took <= MAX_TURN_S and adult["slowest"] <= SLOWEST_TURN_S,
			(
				"the adult's 90 deg turn takes %.2f s on average, %.2f at its slowest (%.1f-%.2f s, <= %.1f)"
				% [took, adult["slowest"], MIN_TURN_S, MAX_TURN_S, SLOWEST_TURN_S]
			)
		)
	)
	check.call(
		adult["steps"] >= MIN_STEPS,
		(
			"alternating feet step the turn (%.1f distinct footfalls on average >= %d)"
			% [adult["steps"], MIN_STEPS]
		)
	)
	check.call(
		adult["aloft"] == 0,
		"the body yaws only with a foot down (%d frames with both feet up == 0)" % adult["aloft"]
	)
	check.call(
		adult["sliced"] >= SLICE_SHARE,
		(
			"the yaw comes in slices at the footfalls (%.0f%% in the %.2f s after one >= %.0f%%)"
			% [adult["sliced"] * 100, SLICE_S, SLICE_SHARE * 100]
		)
	)
	check.call(
		adult["drift"] < MAX_DRIFT_CM,
		"a planted foot holds its spot (%.1f cm < %.1f)" % [adult["drift"], MAX_DRIFT_CM]
	)
	check.call(
		adult["foot_yaw"] <= MAX_FOOT_YAW_DEG,
		(
			"a planted foot holds its world yaw, no pivot (%.1f deg <= %.0f)"
			% [adult["foot_yaw"], MAX_FOOT_YAW_DEG]
		)
	)
	check.call(
		adult["jump"] <= MAX_JUMP,
		(
			"the yaw rate never jumps (%.0f%% of its peak in one frame <= %.0f%%)"
			% [adult["jump"] * 100, MAX_JUMP * 100]
		)
	)
	(
		check
		. call(
			adult["skate_turn"] <= adult["skate_walk"] * SKATE_SHARE + 1.0,
			(
				"no foot skates over the ground in the turn (%.1f foot-frames a second, the walk's %.1f)"
				% [adult["skate_turn"], adult["skate_walk"]]
			)
		)
	)
	var one_step: float = adult["stride"]
	var sim_step: float = adult["step_len"]
	check.call(
		absf(one_step / sim_step - 1.0) < STEP_LEN_TOL,
		(
			"the sim's step is half the clip's stride, so planted feet are passed at the"
			+ " pace the body walks (%.3f vs %.3f)" % [sim_step, one_step]
		)
	)
	var baby := _turn({}, root)
	var baby_took: float = baby["took"]
	check.call(
		absf(baby_took - BABY_TURN_S) <= BABY_TURN_S * BABY_SHARE,
		(
			"the baby turns smoothly, 90 deg in %.2f s (%.2f s +- %.0f%%)"
			% [baby_took, BABY_TURN_S, BABY_SHARE * 100]
		)
	)


## The adult's turn from each of the SWINGS: the average length, footfalls and sliced share, the
## slowest turn, and the worst of everything else.
static func _adult(root: Node) -> Dictionary:
	var out: Dictionary = {}
	var total := 0.0
	for swing: float in SWINGS:
		var one := _turn(ADULT, root, swing)
		total += Num.f(one["took"])
		out["slowest"] = maxf(Num.f(out.get("slowest", 0.0)), Num.f(one["took"]))
		var skate: Vector2 = one["skate"]
		out["skate_walk"] = maxf(Num.f(out.get("skate_walk", 0.0)), skate.x)
		out["skate_turn"] = maxf(Num.f(out.get("skate_turn", 0.0)), skate.y)
		for key: String in ["drift", "foot_yaw", "jump", "aloft"]:
			out[key] = maxf(Num.f(out.get(key, 0.0)), Num.f(one[key]))
		for key: String in ["steps", "sliced"]:
			out[key] = Num.f(out.get(key, 0.0)) + Num.f(one[key]) / SWINGS.size()
		out["stride"] = one["stride"]
		out["step_len"] = one["step_len"]
	out["took"] = total / SWINGS.size()
	return out


## One walk north then a 90 deg turn west at `levels`, the stick swinging at `at_step` of a step:
## {took, steps, aloft, sliced, drift, stride, step_len} (the last two: one step by the clip and by
## the sim, world units).
static func _turn(levels: Dictionary, root: Node, at_step: float = 0.0) -> Dictionary:
	var def := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.kaiju_pos = Vector2(0, 30)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, KaijuModel.stage_for(sim.size_tier()))
	kaiju.scale = Vector3.ONE * sim.body_scale()
	root.add_child(kaiju)
	var falls: Array[Dictionary] = []
	var clock: Array[float] = [0.0]
	kaiju.foot_planted.connect(
		func(side: String, _strength: float, _at: Vector3) -> void:
			if side != "tail":
				falls.append({"t": clock[0], "side": side})
	)
	var gait: BipedGait = kaiju._rig.gait
	var landed := INF
	var aloft := 0
	var drift := 0.0
	var lock: Array[Vector3] = [Vector3.INF, Vector3.INF]
	var toe_yaw: Array[float] = [INF, INF]
	var foot_yaw := 0.0
	var toes: Array[Vector3] = []  # each foot's ground end each frame, left then right
	var last_yaw := gait.body_yaw
	var yaws: Array[Vector2] = []  # (t, |yaw| this frame) through the turn
	var turn_t := INF  # when the stick swung west
	for f: int in roundi((WALK_S + TURN_S) / DT):
		var t := f * DT
		clock[0] = t
		var into := fposmod(sim.body.phase, 1.0) - at_step
		if turn_t == INF and t >= WALK_S and into >= 0.0 and into < SWING_NEAR:
			turn_t = t
		var move := Vector2(0, -1) if t < turn_t else Vector2(-1, 0)
		sim.step(DT, move, false, 0)
		kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
		kaiju.follow_steps(sim.body.step_clock(), sim.body.step_ratio)
		kaiju.animate(DT, 1.0, -sim.body.turn_left)
		var dyaw := absf(wrapf(gait.body_yaw - last_yaw, -PI, PI))
		var yawed := dyaw > STILL_YAW
		last_yaw = gait.body_yaw
		var down := false
		for i: int in 2:
			var leg: BipedGait.Leg = gait.legs[i]
			down = down or leg.planted
			drift = maxf(drift, _drift(kaiju, leg, lock, i) if t > 1.5 else 0.0)
			foot_yaw = maxf(foot_yaw, _foot_yaw(kaiju, leg, toe_yaw, i) if t > 1.5 else 0.0)
			toes.append(kaiju._rig.tail_world(leg.names[2]))
		if t >= turn_t:
			yaws.append(Vector2(t, dyaw))
		if t >= turn_t and landed == INF:
			aloft += 1 if yawed and not down else 0
			if absf(sim.body.turn_left) < LANDED:
				landed = t
	var stride: float = (gait as ClipGait).stride() * 0.5  # one step: half a cycle
	var step_len := Num.f(Content.tuning()["contact"]["step_len"]) * sim.body_scale()
	kaiju.free()
	var steps := 0
	var side := ""
	for fall: Dictionary in falls:
		var at: float = fall["t"]
		if at >= turn_t and at <= landed and str(fall["side"]) != side:
			steps += 1
			side = str(fall["side"])
	var total := 0.0
	var near := 0.0
	var peak := 0.0
	var jump := 0.0
	for n: int in yaws.size():
		peak = maxf(peak, yaws[n].y)
		jump = maxf(jump, absf(yaws[n].y - yaws[n - 1].y) if n > 0 else 0.0)
	for y: Vector2 in yaws:
		if y.x > landed:
			break
		total += y.y
		for fall: Dictionary in falls:
			var fell: float = fall["t"]
			var dt_after := y.x - fell
			if dt_after >= 0.0 and dt_after <= SLICE_S:
				near += y.y
				break
	return {
		"took": landed - turn_t,
		"steps": steps,
		"aloft": aloft,
		"drift": drift,
		"foot_yaw": foot_yaw,
		"skate": _skate(toes, turn_t, landed),
		"jump": jump / maxf(peak, 0.0001),
		"stride": stride,
		"step_len": step_len,
		"sliced": near / maxf(total, 0.0001)
	}


## How far (cm, flat) leg `i`'s foot has moved since it went down (0 while it is up).
static func _drift(kaiju: KaijuModel, leg: BipedGait.Leg, lock: Array[Vector3], i: int) -> float:
	var at := kaiju._rig.tail_world(leg.names[2])
	if not leg.planted:
		lock[i] = Vector3.INF
		return 0.0
	if lock[i] == Vector3.INF:
		lock[i] = at
	return Vector2(at.x - lock[i].x, at.z - lock[i].z).length() * CM_PER_UNIT


## How far (deg) leg `i`'s toes have yawed in the world since its foot went down (0 while it is up).
static func _foot_yaw(kaiju: KaijuModel, leg: BipedGait.Leg, since: Array[float], i: int) -> float:
	if not leg.planted:
		since[i] = INF
		return 0.0
	var toes := kaiju._rig.tail_world(leg.names[2]) - kaiju._rig.bone(leg.names[2]).global_position
	var yaw := atan2(toes.x, toes.z)
	if since[i] == INF:
		since[i] = yaw
	return absf(rad_to_deg(wrapf(yaw - since[i], -PI, PI)))


## Foot-frames skating a second, as Vector2(walk from 1.5 s to the turn, turn).
static func _skate(toes: Array[Vector3], turn_t: float, landed: float) -> Vector2:
	var ground := INF  # a planted foot's height: the lowest the toes ever are
	for toe: Vector3 in toes:
		ground = minf(ground, toe.y)
	var walk := 0.0
	var turn := 0.0
	for n: int in range(2, toes.size()):
		var t := (n / 2) * DT
		var at := toes[n]
		var speed := Vector2(at.x - toes[n - 2].x, at.z - toes[n - 2].z).length() / DT
		if at.y - ground >= SKATE_LOW or speed <= SKATE_SPEED:
			continue
		if t >= turn_t and t <= landed:
			turn += 1.0
		elif t >= 1.5 and t < turn_t:
			walk += 1.0
	return Vector2(walk / maxf(turn_t - 1.5, 0.01), turn / maxf(landed - turn_t, 0.01))
