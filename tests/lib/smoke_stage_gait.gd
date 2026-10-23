extends RefCounted
## The croc's gait at every growth step (D-177, "Motion first"; beside tests/lib/smoke_step_turn.gd,
## which drives the adult's turns): the sim's step is half the clip's stride at each step (so
## planted feet are passed at the pace the body walks), and a held curve, the stick swept round,
## yaws the body only with a foot down. Driven with the real sim and the real clips at 60 Hz, the
## way the rampage scene drives them.

const DT := 1.0 / 60.0
## The growth steps (D-135) and the upgrade levels that make each.
const STAGES := {"young": {}, "Behemoth": {"evolve1": 1}, "Colossus": {"evolve1": 1, "evolve2": 1}}
const WALK_S := 3.0
## The sim's step length may differ this much from half the walk clip's stride.
const STEP_LEN_TOL := 0.02
## A held curve: the stick swept round at CURVE_DEG_S from CURVE_FROM_S on, for ROUTE_S, after the
## body has set off (WARM_S). A body that steps its turns yaws only with a foot down: no more than
## MAX_ALOFT_DEG of the curve with both feet up (a yaw this small in one frame is no turn).
const CURVE_FROM_S := 2.0
const CURVE_DEG_S := 30.0
const ROUTE_S := 6.0
const WARM_S := 1.0
const MAX_ALOFT_DEG := 0.0
const STILL_YAW := 0.0005


static func check(check: Callable, root: Node) -> void:
	for stage: String in STAGES:
		_stride(check, root, stage)
		_curve(check, root, stage)


## The step in the data and the step the sim walks, against half the clip's stride, at each growth
## step that steps (the young croc walks by distance, D-131: it has no step length).
static func _stride(check: Callable, root: Node, stage: String) -> void:
	var levels: Dictionary = STAGES[stage]
	var rig := _rig(levels, root)
	var sim: RampageSim = rig["sim"]
	var kaiju: KaijuModel = rig["kaiju"]
	var from := sim.kaiju_pos
	var phase := sim.body.phase
	for f: int in roundi(WALK_S / DT):
		_drive(sim, kaiju, Vector2(0, -1))
		if f == roundi(WARM_S / DT):
			from = sim.kaiju_pos
			phase = sim.body.phase
	var clip: float = (kaiju._rig.gait as ClipGait).stride() * 0.5  # world units once it has moved
	if sim.body.stepping():
		var bodies: Array = Content.tuning()["contact"]["bodies"]["reptilian"]
		var body: Dictionary = bodies[sim.size_tier() - 1]
		var data := Num.f(body["step_len"]) * sim.body_scale()
		check.call(
			absf(clip / data - 1.0) < STEP_LEN_TOL,
			(
				"%s: the step in the data is half the clip's stride (%.3f vs %.3f)"
				% [stage, data, clip]
			)
		)
		var walked := sim.kaiju_pos.distance_to(from) / maxf(sim.body.phase - phase, 0.001)
		check.call(
			absf(clip / walked - 1.0) < STEP_LEN_TOL,
			"%s: the sim walks half the clip's stride a step (%.3f vs %.3f)" % [stage, walked, clip]
		)
	kaiju.free()


## A held curve yaws only with a foot down, at each growth step that steps its turns.
static func _curve(check: Callable, root: Node, stage: String) -> void:
	var levels: Dictionary = STAGES[stage]
	var rig := _rig(levels, root)
	var sim: RampageSim = rig["sim"]
	var kaiju: KaijuModel = rig["kaiju"]
	var gait: BipedGait = kaiju._rig.gait
	var last_yaw := gait.body_yaw
	var aloft := 0.0
	for f: int in roundi(ROUTE_S / DT):
		var t := f * DT
		var way := Vector2(0, -1).rotated(-deg_to_rad(CURVE_DEG_S) * maxf(0.0, t - CURVE_FROM_S))
		_drive(sim, kaiju, way)
		var dyaw := wrapf(gait.body_yaw - last_yaw, -PI, PI)
		last_yaw = gait.body_yaw
		var left: BipedGait.Leg = gait.legs[0]
		var right: BipedGait.Leg = gait.legs[1]
		if t >= WARM_S and absf(dyaw) > STILL_YAW and not (left.planted or right.planted):
			aloft += absf(rad_to_deg(dyaw))
	var steps := sim.body.stepping()
	kaiju.free()
	if steps:  # the young turns smoothly by design (D-131)
		check.call(
			aloft <= MAX_ALOFT_DEG,
			(
				"%s: a held %.0f deg/s curve yaws %.1f deg with no foot down (<= %.1f)"
				% [stage, CURVE_DEG_S, aloft, MAX_ALOFT_DEG]
			)
		)


## One frame: the stick `way` steps the sim, and the model follows it as the rampage scene does.
static func _drive(sim: RampageSim, kaiju: KaijuModel, way: Vector2) -> void:
	sim.step(DT, way, false, 0)
	kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
	kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
	kaiju.follow_steps(sim.body.step_clock(), sim.body.step_ratio)
	kaiju.animate(DT, way.length(), -sim.body.turn_left)


## The reptilian at `levels` at (0, 30), with its model.
static func _rig(levels: Dictionary, root: Node) -> Dictionary:
	var def := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var tuning := CityGrowth.for_stats(stats)  # the stage's own tuning and speed, as played
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.kaiju_pos = Vector2(0, 30)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, KaijuModel.stage_for(sim.size_tier()))
	kaiju.scale = Vector3.ONE * sim.body_scale()
	root.add_child(kaiju)
	return {"sim": sim, "kaiju": kaiju}
