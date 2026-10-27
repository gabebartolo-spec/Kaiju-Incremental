extends RefCounted
## The camera bubble on replayed rampages (D-283, D-326; the lead's bars, 2026-10-27): the new
## save's street rampage (the flow city, army seed 0, no upgrades) and one run per growth stage
## (Kit.STAGE_LEVELS, its own city and army seed), autoplayed (AutoWalk, as Rampage's autoplay)
## through the rise and SECONDS after it, the camera following the way Rampage does (CameraFollow:
## the body eased in at the model's 12/s, the lead; no shake, dip or head tilt) and CameraBubble
## fed the eye, the kaiju's feet and his field as CityView feeds it. On every frame:
## (1) no building whose footprint lies in the destruction field (CameraBubble.in_field) has a cut
##     fragment: a part of it nearer the camera than its share of the radius;
## (2) the sphere's far edge stays at least the field's radius from the kaiju on the ground;
## (3) no damaged building is cut at all.
## And (4) no wall fills the frame: every SAMPLE-th frame, a GRID of rays through the game
## camera's view (to the kaiju's distance): no single building outside the field is the first
## drawn chunk on more than FILL of them (a chunk the bubble cuts away is not drawn).
## Headless and sim-only; prints the numbers it measured.

const Kit := preload("res://tools/capture/capture_kit.gd")
const SPECIES := "reptilian"
const SECONDS := 12.0
const DT := 1.0 / 60.0
const BODY_FOLLOW := 12.0  # RampageAbility.place: the model eases to the sim at 12/s
const SAMPLE := 6
const GRID := Vector2i(16, 9)
const FILL := 0.5
const STEP := 0.5  # ray march step (metres)
const EPS := 0.001

var _check: Callable
var _runs: Array[Vector2i] = [Vector2i(0, 0)]  # (stage, seed): the new save's street rampage


func _init(p_check: Callable) -> void:
	_check = p_check
	for stage: int in range(1, CityGrowth.stage_count(Content.tuning()) + 1):
		_runs.append(Vector2i(stage, stage))


func run() -> void:
	for r: Vector2i in _runs:
		_run(r.x, r.y)


static func sim_for(stage: int, seed: int) -> RampageSim:
	var stats := Kit.stats(SPECIES)
	var layout := Kit.flow_city()
	if stage > 0:
		stats = Kit.stats(SPECIES, Kit.STAGE_LEVELS[stage - 1], SPECIES)
		var tier := Num.i(stats["size"])
		layout = CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", seed))
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", seed))
	sim.emerge.start(sim)
	return sim


func _run(stage: int, seed: int) -> void:
	var sim := sim_for(stage, seed)
	var bubble := CameraBubble.new(sim.buildings, func(_n: int) -> BuildingView: return null)
	var walk := AutoWalk.new()
	var body := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
	var zoom := CameraTuning.zoom(sim.body_scale())
	var follow := CameraFollow.new(body, CameraTuning.offset())
	follow.step(body, CameraTuning.offset() * zoom, 1.0)  # Rampage._ready's first placement
	var m := {"frames": 0, "cut_frames": 0, "field_cut": 0, "edge_short": 0, "damaged_cut": 0}
	m.merge({"edge_min": INF, "radius_min": INF, "radius_max": 0.0, "fill_max": 0.0})
	m.merge({"walled": 0, "samples": 0, "field": 0.0})
	var steps := 0
	var left := int(SECONDS / DT)
	while left > 0:
		if not sim.emerge.active:
			left -= 1
		sim.step(DT, walk.move(sim, steps), false, 0)
		steps += 1
		var feet := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
		body = body.lerp(feet, minf(1.0, DT * BODY_FOLLOW))
		follow.step(body, CameraTuning.offset() * zoom, DT)
		follow.step_lead(body, sim.body_scale(), false, DT)
		var eye := follow.eye()
		var field := CameraBubble.field(sim)
		bubble.update(eye, feet, field, DT)
		_frame(m, sim, bubble, eye, feet, field)
		if steps % SAMPLE == 0:
			_sample(m, sim, bubble, eye, follow.look_at(sim.body_scale()), feet, field)
	_report(m, stage, seed)


## Bars 1-3 on one frame, into the run's tallies.
static func _frame(
	m: Dictionary, sim: RampageSim, bubble: CameraBubble, eye: Vector3, feet: Vector3, field: float
) -> void:
	var radius := bubble.radius()
	m["frames"] += 1
	m["field"] = field
	m["radius_min"] = minf(Num.f(m["radius_min"]), radius)
	m["radius_max"] = maxf(Num.f(m["radius_max"]), radius)
	var flat := Vector2(eye.x, eye.z).distance_to(Vector2(feet.x, feet.z))
	m["edge_min"] = minf(Num.f(m["edge_min"]), flat - radius - field)
	m["edge_short"] += 1 if flat - radius < field - EPS else 0
	var any := false
	for n: int in sim.buildings.size():
		var share := bubble.cut(n)
		if share <= 0.0:
			continue
		any = true
		var b := sim.buildings[n]
		var reaches := CameraBubble.reach(eye, b) < radius * share
		m["field_cut"] += 1 if reaches and CameraBubble.in_field(b, feet, field) else 0
		m["damaged_cut"] += 1 if CameraBubble.damaged(b) else 0
	m["cut_frames"] += 1 if any else 0


## Bar 4 on one frame: the largest share of the view one building outside the field covers.
static func _sample(
	m: Dictionary,
	sim: RampageSim,
	bubble: CameraBubble,
	eye: Vector3,
	look: Vector3,
	feet: Vector3,
	field: float
) -> void:
	var owners := first_hits(sim.buildings, bubble, eye, look, eye.distance_to(feet))
	var count := {}
	for n: int in owners:
		if n >= 0 and not CameraBubble.in_field(sim.buildings[n], feet, field):
			count[n] = Num.i(count.get(n, 0)) + 1
	var most := 0
	for n: int in count:
		most = maxi(most, Num.i(count[n]))
	var share := float(most) / owners.size()
	m["samples"] += 1
	m["fill_max"] = maxf(Num.f(m["fill_max"]), share)
	m["walled"] += 1 if share > FILL else 0


## For each ray of a GRID through a camera at `eye` looking at `look` (CameraTuning.fov, 16:9),
## out to `reach` metres: the index of the building whose drawn chunk it meets first, or -1.
static func first_hits(
	buildings: Array[RampageSim.Building],
	bubble: CameraBubble,
	eye: Vector3,
	look: Vector3,
	reach: float
) -> PackedInt32Array:
	var forward := (look - eye).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward)
	var tan_v := tan(deg_to_rad(CameraTuning.fov()) * 0.5)
	var tan_h := tan_v * 16.0 / 9.0
	var ends := PackedVector3Array()
	var lo := Vector2(eye.x, eye.z)
	var hi := lo
	for j: int in GRID.y:
		for i: int in GRID.x:
			var u := ((i + 0.5) / GRID.x * 2.0 - 1.0) * tan_h
			var v := (1.0 - (j + 0.5) / GRID.y * 2.0) * tan_v
			var end := eye + (forward + right * u + up * v).normalized() * reach
			ends.append(end)
			lo = Vector2(minf(lo.x, end.x), minf(lo.y, end.z))
			hi = Vector2(maxf(hi.x, end.x), maxf(hi.y, end.z))
	var near: Array[int] = []
	for n: int in buildings.size():
		var b := buildings[n]
		if b.x + b.w * 0.5 >= lo.x and b.x - b.w * 0.5 <= hi.x:
			if b.z + b.d * 0.5 >= lo.y and b.z - b.d * 0.5 <= hi.y:
				near.append(n)
	var out := PackedInt32Array()
	for end: Vector3 in ends:
		var best := INF
		var owner := -1
		for n: int in near:
			var at := _hit(buildings[n], eye, end, bubble.radius() * bubble.cut(n), best)
			if at < best:
				best = at
				owner = n
		out.append(owner)
	return out


## How far along eye -> end the ray first meets a standing chunk of b that is drawn (not within
## `cut_radius` of the eye), or INF; stops looking past `best`.
static func _hit(
	b: RampageSim.Building, eye: Vector3, end: Vector3, cut_radius: float, best: float
) -> float:
	var corner := Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5)
	var box := AABB(corner, Vector3(b.w, b.height, b.d))
	var enter: Variant = Vector3(eye) if box.has_point(eye) else box.intersects_segment(eye, end)
	if enter == null:
		return INF
	var out: Variant = box.intersects_segment(end, eye)
	var first: Vector3 = enter
	var last: Vector3 = end if out == null else out
	var t0 := eye.distance_to(first)
	var t1 := eye.distance_to(last)
	var dir := (end - eye).normalized()
	var t := maxf(t0, cut_radius)
	while t <= minf(t1, best):
		var p := eye + dir * t
		if b.frame == null or b.frame.alive(Vector3i((p - corner).floor())):
			return t
		t += STEP
	return INF


func _report(m: Dictionary, stage: int, seed: int) -> void:
	var name := "stage %d seed %d" % [stage, seed]
	print(
		(
			(
				"%s: %d frames (field %.1f m), cut on %d, radius %.1f..%.1f m, far edge >= field + %.2f m;"
				+ " largest foreground wall %.0f%% of the view (%d of %d samples over %.0f%%)"
			)
			% [
				name,
				m["frames"],
				m["field"],
				m["cut_frames"],
				m["radius_min"],
				m["radius_max"],
				m["edge_min"],
				Num.f(m["fill_max"]) * 100.0,
				m["walled"],
				m["samples"],
				FILL * 100.0
			]
		)
	)
	_check.call(
		m["field_cut"] == 0,
		"%s: no cut fragment on a building in the field (%d)" % [name, m["field_cut"]]
	)
	_check.call(
		m["edge_short"] == 0,
		(
			"%s: the sphere's far edge stays the field's radius from the kaiju (%d short)"
			% [name, m["edge_short"]]
		)
	)
	_check.call(
		m["damaged_cut"] == 0, "%s: no damaged building is cut (%d)" % [name, m["damaged_cut"]]
	)
	_check.call(
		m["walled"] == 0,
		"%s: no wall outside the field fills over %.0f%% of the view" % [name, FILL * 100.0]
	)
