extends RefCounted
## Drives the croc titan at one growth step along one route with the real sim and its ClipGait at
## 60 Hz, the way Rampage._update_kaiju does (the sim's stomps reach the body too), and measures
## how it moves (the motion suite's bars, director D-177 "Motion first"):
##   slide      fastest a planted foot moves over the ground (world units/s)
##   catch      catch steps (ClipStomp.restep) a second
##   steps      the walk clip's steps a second (its clock: clip frames played / frames per step)
##   jerk       shin angular jerk, the 99th percentile (deg/frame^2): a knee that pops or flips
##   stretch    longest hip-ankle reach of a planted leg (share of the leg's length)
##   aloft_yaw  degrees the body yawed with no foot down (a swivel in the air)
##   pivot      median distance (hip heights) of the sim's pivot foot (BodyContact._feet[0]) from
##              the nearest drawn planted foot, over frames the body yaws
##   centre     median distance (hip heights) of the drawn body's rotation centre from the nearest
##              planted foot, over the same frames
## Deterministic: a seeded sim, a fixed step, no clock.

const DT := 1.0 / 60.0
## Measuring starts after the body has set off (s); each route lasts ROUTE_S.
const WARM_S := 1.0
const ROUTE_S := 6.0
## Upgrade levels for each growth step (D-135: young, Behemoth, Colossus).
const STAGES := {
	"young": {},
	"Behemoth": {"evolve1": 1},
	"Colossus": {"evolve1": 1, "evolve2": 1},
}
const ROUTES := ["straight", "turn90", "turn180", "stand_turn", "curve"]
## A frame turning faster than this (rad) gets a rotation centre and a pivot distance.
const CENTRE_YAW := 0.0035
const STILL_YAW := 0.0005


## The stick (sim space: -y is north) at time t: walk north, then a hard turn; stand, then go; or
## a held curve.
static func stick(route: String, t: float) -> Vector2:
	match route:
		"turn90":
			return Vector2(0, -1) if t < 3.0 else Vector2(-1, 0)
		"turn180":
			return Vector2(0, -1) if t < 3.0 else Vector2(0, 1)
		"stand_turn":
			return Vector2.ZERO if t < 2.0 else Vector2(1, 0)
		"curve":  # a held curve: the stick swept round at 30 deg/s, never a hard turn
			return Vector2(0, -1).rotated(-deg_to_rad(30.0) * maxf(0.0, t - 2.0))
	return Vector2(0, -1)


static func drive(root: Node, stage: String, route: String) -> Dictionary:
	var def := Content.species_def("reptilian")
	var levels: Dictionary = STAGES[stage]
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), def, tree)
	var layout: Array[Dictionary] = [
		{"x": 38.0, "z": 38.0, "w": 2, "d": 2, "h": 2, "tier": 1, "style": 0}
	]
	var tuning := CityGrowth.for_stats(stats)  # the stage's own tuning, as Rampage plays it
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.kaiju_pos = Vector2(0, 30)
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, KaijuModel.stage_for(sim.size_tier()))
	kaiju.scale = Vector3.ONE * sim.body_scale()
	root.add_child(kaiju)
	var rig: KaijuRig = kaiju._rig
	var gait := rig.gait as ClipGait
	var falls: Array[float] = []
	var clock: Array[float] = [0.0]
	kaiju.foot_planted.connect(
		func(side: String, _strength: float, _at: Vector3) -> void:
			if side != "tail" and clock[0] >= WARM_S:
				falls.append(clock[0])
	)
	var out := {
		"slide": 0.0, "catch": 0, "stretch": 0.0, "aloft_yaw": 0.0, "stepping": sim.body.stepping()
	}
	var jerk: Array[float] = []
	var pivots: Array[float] = []
	var centres: Array[float] = []
	var last_toe: Array[Vector3] = [Vector3.INF, Vector3.INF]
	var last_dir: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var last_v: Array[Vector3] = [Vector3.INF, Vector3.INF]
	var was_catch: Array[bool] = [false, false]
	var was_planted: Array[bool] = [true, true]
	var last_xf := Transform3D()
	var last_yaw := 0.0
	var walk_n := float(gait.clips.frames_of("walk"))
	var last_clip := gait.clip_time
	var walked := 0.0  # walk clip frames played
	for f: int in roundi(ROUTE_S / DT):
		var t := f * DT
		clock[0] = t
		var move := stick(route, t)
		for event: Dictionary in sim.step(DT, move, false, 0):
			if str(event["type"]) == "stomp":
				kaiju.stomp()
		kaiju.position = Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
		kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)
		kaiju.follow_steps(sim.body.step_clock(), sim.body.step_ratio)
		kaiju.follow_body(sim.body)
		kaiju.animate(DT, move.length(), -sim.body.turn_left)
		var hh := gait.hip_height * gait.s
		var xf := rig.global_transform
		var dyaw := wrapf(gait.body_yaw - last_yaw, -PI, PI) if f > 0 else 0.0
		last_yaw = gait.body_yaw
		var warm := t >= WARM_S
		if warm and gait.state == "walk":
			walked += fposmod(gait.clip_time - last_clip, walk_n)
		last_clip = gait.clip_time
		var toes: Array[Vector3] = []
		for i: int in 2:
			var leg: BipedGait.Leg = gait.legs[i]
			var toe := rig.tail_world(leg.names[2])
			var catching := gait._stomp.catching(i)
			if warm and catching and not was_catch[i] and not gait._stomp._stomping[i]:
				out["catch"] = Num.i(out["catch"]) + 1
			if leg.planted:
				toes.append(toe)
				if warm and was_planted[i] and last_toe[i] != Vector3.INF:
					var flat := Vector2(toe.x - last_toe[i].x, toe.z - last_toe[i].z)
					out["slide"] = maxf(Num.f(out["slide"]), flat.length() / DT)
				if warm:
					var hip := rig.bone(leg.names[0]).global_position
					var ankle := rig.bone(leg.names[2]).global_position
					var reach := (ankle - hip).length() / ((leg.l1 + leg.l2) * gait.s)
					out["stretch"] = maxf(Num.f(out["stretch"]), reach)
			var shin := (
				(rig.bone(leg.names[2]).global_position - rig.bone(leg.names[1]).global_position)
				. normalized()
			)
			if last_dir[i] != Vector3.ZERO:
				var v := shin - last_dir[i]
				if warm and last_v[i] != Vector3.INF:
					jerk.append(rad_to_deg((v - last_v[i]).length()))
				last_v[i] = v
			last_dir[i] = shin
			last_toe[i] = toe
			was_catch[i] = catching
			was_planted[i] = leg.planted
		if warm and absf(dyaw) > STILL_YAW and toes.is_empty():
			out["aloft_yaw"] = Num.f(out["aloft_yaw"]) + absf(rad_to_deg(dyaw))
		if warm and absf(dyaw) > CENTRE_YAW and not toes.is_empty():
			centres.append(_nearest(_centre(last_xf, xf), toes) / hh)
			var feet: Array[Vector2] = sim.body._steps.feet
			pivots.append(_nearest(feet[0], toes) / hh)
		last_xf = xf
	out["falls"] = falls.size() / (ROUTE_S - WARM_S)
	var step_frames := walk_n / gait.clips.cycles_of("walk") * 0.5
	out["steps"] = walked / step_frames / (ROUTE_S - WARM_S)
	out["catch"] = Num.i(out["catch"]) / (ROUTE_S - WARM_S)
	out["jerk"] = pct(jerk, 0.99)
	out["pivot"] = pct(pivots, 0.5)
	out["centre"] = pct(centres, 0.5)
	out["step"] = step_len(sim.size_tier()) * sim.body_scale()
	out["half_stride"] = gait.stride() * 0.5
	out["authored_steps"] = (
		2.0 * gait.clips.fps * gait.clips.cycles_of("walk") / gait.clips.frames_of("walk")
	)
	kaiju.free()
	return out


## The sim's step length at body scale 1 for a size tier: its body's own (contact.bodies) when it
## has one, else the shared contact.step_len.
static func step_len(size_tier: int) -> float:
	var contact: Dictionary = Content.tuning()["contact"]
	var bodies: Array = contact["bodies"]["reptilian"]
	var body: Dictionary = bodies[clampi(size_tier - 1, 0, bodies.size() - 1)]
	return Num.f(body.get("step_len", contact["step_len"]))


## The q-th quantile of a list (0 when empty).
static func pct(a: Array[float], q: float) -> float:
	if a.is_empty():
		return 0.0
	var sorted := a.duplicate()
	sorted.sort()
	return sorted[clampi(int(q * (sorted.size() - 1)), 0, sorted.size() - 1)]


## The fixed point (world, flat) of the rigid move from transform a to b.
static func _centre(a: Transform3D, b: Transform3D) -> Vector2:
	var rel := b * a.affine_inverse()
	var bx := rel.basis.x.normalized()
	var bz := rel.basis.z.normalized()
	var m00 := 1.0 - bx.x
	var m01 := -bz.x
	var m10 := -bx.z
	var m11 := 1.0 - bz.z
	var det := m00 * m11 - m01 * m10
	if absf(det) < 1e-9:
		return Vector2(INF, INF)
	var tx := rel.origin.x
	var tz := rel.origin.z
	return Vector2((tx * m11 - m01 * tz) / det, (m00 * tz - m10 * tx) / det)


static func _nearest(p: Vector2, toes: Array[Vector3]) -> float:
	var best := INF
	for toe: Vector3 in toes:
		best = minf(best, p.distance_to(Vector2(toe.x, toe.z)))
	return best
