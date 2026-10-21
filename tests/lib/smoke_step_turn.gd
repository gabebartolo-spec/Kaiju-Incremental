extends RefCounted
## The adult steps its turns (director comments #16 and 2026-10-21 #3: "rather than swivelling on
## the spot like a plastic toy"). The adult reptilian, driven by the real sim the way the rampage
## scene drives it (60 Hz), walks north and the stick swings west: the 90 deg turn takes time, the
## feet step it (footfalls during the turn) and a planted foot holds its spot. Not pinned yet: the
## body still yaws during re-steps with both feet up (follow-up, agent-handoffs/turn-step.md).

const DT := 1.0 / 60.0
const ADULT := {"evolve1": 1, "evolve2": 1}
const WALK_S := 3.0
const TURN_S := 3.0
## The 90 deg turn takes this long (s): lumbering, not a swivel, "but not TOO slow ... its not
## fun to play if hes too sluggish" (director 2026-10-21).
const MIN_TURN_S := 1.0
const MAX_TURN_S := 1.25
## Footfalls while the turn is under way.
const MIN_STEPS := 2
## The turn is made when the yaw still to turn is under this (rad, about 1 deg).
const LANDED := 0.02
## A planted foot may drift at most this far (cm; a world unit is a 3.5 m storey).
const MAX_DRIFT_CM := 5.0
const CM_PER_UNIT := 350.0


static func check(check: Callable, root: Node) -> void:
	var def := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), ADULT, "reptilian")
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
	var steps: Array[float] = []
	var clock: Array[float] = [0.0]
	kaiju.foot_planted.connect(
		func(side: String, _strength: float, _at: Vector3) -> void:
			if side != "tail":
				steps.append(clock[0])
	)
	var gait: BipedGait = kaiju._rig.gait
	var landed := INF
	var drift := 0.0
	var lock: Array[Vector3] = [Vector3.INF, Vector3.INF]
	for f: int in roundi((WALK_S + TURN_S) / DT):
		var t := f * DT
		clock[0] = t
		var move := Vector2(0, -1) if t < WALK_S else Vector2(-1, 0)
		sim.step(DT, move, false, 0)
		kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
		kaiju.animate(DT, 1.0, -sim.body.turn_left)
		for i: int in 2:
			var leg: BipedGait.Leg = gait.legs[i]
			drift = maxf(drift, _drift(kaiju, leg, lock, i) if t > 1.5 else 0.0)
		if t >= WALK_S and landed == INF:
			if absf(sim.body.turn_left) < LANDED:
				landed = t
	kaiju.free()
	var took := landed - WALK_S
	var stepped := steps.filter(func(s: float) -> bool: return s >= WALK_S and s <= landed).size()
	check.call(
		took >= MIN_TURN_S and took <= MAX_TURN_S,
		"the adult's 90 deg turn takes %.2f s (%.1f-%.2f s)" % [took, MIN_TURN_S, MAX_TURN_S]
	)
	check.call(
		stepped >= MIN_STEPS, "the feet step the turn (%d footfalls >= %d)" % [stepped, MIN_STEPS]
	)
	check.call(
		drift < MAX_DRIFT_CM,
		"a planted foot holds its spot (%.1f cm < %.1f)" % [drift, MAX_DRIFT_CM]
	)


## How far (cm, flat) leg `i`'s foot has moved since it went down (0 while it is up).
static func _drift(kaiju: KaijuModel, leg: BipedGait.Leg, lock: Array[Vector3], i: int) -> float:
	var at := kaiju._rig.tail_world(leg.names[2])
	if not leg.planted:
		lock[i] = Vector3.INF
		return 0.0
	if lock[i] == Vector3.INF:
		lock[i] = at
	return Vector2(at.x - lock[i].x, at.z - lock[i].z).length() * CM_PER_UNIT
