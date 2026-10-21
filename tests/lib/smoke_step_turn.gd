extends RefCounted
## The kaiju steps its turns (director comments #16 and 2026-10-21 #3: "step rather than
## swivelling on the spot like a plastic toy"; #31 "bigger = slower but not TOO slow"). The
## reptilian, driven by the real sim the way the rampage scene drives it (60 Hz), walks north and
## the stick swings west. The adult's 90 deg turn takes time, alternating feet step it, the body
## never yaws with both feet up, and a planted foot holds its spot; the baby keeps today's turn.

const DT := 1.0 / 60.0
const ADULT := {"evolve1": 1, "evolve2": 1}
const WALK_S := 3.0
const TURN_S := 3.0
## The adult's 90 deg turn takes this long (s): lumbering, not a swivel, "but not TOO slow".
const MIN_TURN_S := 1.0
const MAX_TURN_S := 1.25
## Distinct footfalls (alternating feet; a foot re-stepping after itself is a shuffle) in it.
const MIN_STEPS := 3
## The baby's 90 deg turn, measured 2026-10-21 (turn-weight d24fe80e), and the share it may move.
const BABY_TURN_S := 0.60
const BABY_SHARE := 0.1
## Each footfall turns the body a slice; between steps only the head leads: at least this share
## of the turn's yaw comes in the SLICE_S seconds after a footfall (a smooth swivel spreads it).
const SLICE_SHARE := 0.7
const SLICE_S := 0.15
## The turn is made when the yaw still to turn is under this (rad, about 1 deg).
const LANDED := 0.02
## A yaw this small in one frame is no turn (rad).
const STILL_YAW := 0.0005
## A planted foot may drift at most this far (cm; a world unit is a 3.5 m storey).
const MAX_DRIFT_CM := 5.0
const CM_PER_UNIT := 350.0
## The sim's step length may differ this much from half the walk clip's stride.
const STEP_LEN_TOL := 0.02


static func check(check: Callable, root: Node) -> void:
	var adult := _turn(ADULT, root)
	var took: float = adult["took"]
	check.call(
		took >= MIN_TURN_S and took <= MAX_TURN_S,
		"the adult's 90 deg turn takes %.2f s (%.1f-%.2f s)" % [took, MIN_TURN_S, MAX_TURN_S]
	)
	check.call(
		adult["steps"] >= MIN_STEPS,
		"alternating feet step the turn (%d distinct footfalls >= %d)" % [adult["steps"], MIN_STEPS]
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
	var one_step: float = adult["stride"]
	var sim_step: float = adult["step_len"]
	check.call(
		absf(one_step / sim_step - 1.0) < STEP_LEN_TOL,
		(
			"the sim's step is half the clip's stride, so planted feet are passed at the pace the body walks (%.3f vs %.3f)"
			% [sim_step, one_step]
		)
	)
	var baby := _turn({}, root)
	var baby_took: float = baby["took"]
	check.call(
		absf(baby_took - BABY_TURN_S) <= BABY_TURN_S * BABY_SHARE,
		(
			"the baby keeps its turn (%.2f s, %.2f s +- %.0f%%)"
			% [baby_took, BABY_TURN_S, BABY_SHARE * 100]
		)
	)


## One walk north then a 90 deg turn west at `levels`: {took, steps, aloft, sliced, drift, stride,
## step_len} (the last two: one step by the clip and by the sim, world units).
static func _turn(levels: Dictionary, root: Node) -> Dictionary:
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
	var last_yaw := gait.body_yaw
	var yaws: Array[Vector2] = []  # (t, |yaw| this frame) through the turn
	for f: int in roundi((WALK_S + TURN_S) / DT):
		var t := f * DT
		clock[0] = t
		var move := Vector2(0, -1) if t < WALK_S else Vector2(-1, 0)
		sim.step(DT, move, false, 0)
		kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
		kaiju.animate(DT, 1.0, -sim.body.turn_left, sim.body.step_clock(), sim.body.step_ratio)
		var dyaw := absf(wrapf(gait.body_yaw - last_yaw, -PI, PI))
		var yawed := dyaw > STILL_YAW
		last_yaw = gait.body_yaw
		var down := false
		for i: int in 2:
			var leg: BipedGait.Leg = gait.legs[i]
			down = down or leg.planted
			drift = maxf(drift, _drift(kaiju, leg, lock, i) if t > 1.5 else 0.0)
		if t >= WALK_S and landed == INF:
			aloft += 1 if yawed and not down else 0
			yaws.append(Vector2(t, dyaw))
			if absf(sim.body.turn_left) < LANDED:
				landed = t
	var stride: float = (gait as ClipGait).stride() * 0.5  # one step: half a cycle
	var step_len := Num.f(Content.tuning()["contact"]["step_len"]) * sim.body_scale()
	kaiju.free()
	var steps := 0
	var side := ""
	for fall: Dictionary in falls:
		var at: float = fall["t"]
		if at >= WALK_S and at <= landed and str(fall["side"]) != side:
			steps += 1
			side = str(fall["side"])
	var total := 0.0
	var near := 0.0
	for y: Vector2 in yaws:
		total += y.y
		for fall: Dictionary in falls:
			var fell: float = fall["t"]
			var dt_after := y.x - fell
			if dt_after >= 0.0 and dt_after <= SLICE_S:
				near += y.y
				break
	return {
		"took": landed - WALK_S,
		"steps": steps,
		"aloft": aloft,
		"drift": drift,
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
