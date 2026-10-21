class_name StreetLife
extends Node3D
## People in the streets. Civilians walk the pavement round every block and cross at the
## corners; when the kaiju comes near they turn and run from it, arms up. Police set up
## blockades on a street ahead of it: cruisers park across the road, lights flashing, and
## officers fire their pistols in vain until it is almost on them, then scatter. Stomps,
## falling sections and tank tracks crush them in a puff of dust. Owns the moving traffic.
## Presentation only: the sim and the economy never know any of them exist.

const SIDE_STEP := 0.2  # people keep a little to one side of the line
const PACE_SPREAD := 0.2  # walkers differ in pace, so a crowd strings out instead of merging
const WALK_HZ := 3.0
const RUN_HZ := 6.0
const CROSS_CHANCE := 0.3  # a walker at a corner crosses the street rather than turns
const WALK_SAMPLE := 0.5  # a pavement line is checked for road this often
const MAX_PUFFS_PER_CRUSH := 1  # each puff is a particle node: one per stomp keeps it cheap


class Person:
	extends RefCounted
	var pos := Vector2.ZERO
	var heading := Vector2(0, -1)
	var outfit := 0
	var phase := 0.0
	var side := 0.0
	var pace := 1.0
	var from_node := 0
	var to_node := 0
	var fleeing := false
	## Standing still until this clock time: gawking at the kaiju a moment before running, or
	## frozen under a falling tower (nobody outruns one).
	var pinned_until := -1.0
	var cop := false
	var state := 0  # officers: 0 to post, 1 holding, 2 fleeing
	var post := Vector2.ZERO
	var away := Vector2.ZERO
	var fire_in := 0.0
	var timer := 0.0
	var blockade: Police.Blockade


var sim: RampageSim
var traffic: Traffic
var police: Police
var people: Array[Person] = []
## A match on each stadium's pitch (D-078).
var matches: Array[StadiumMatch] = []
## Running totals (tests and the capture tool read them).
var fled := 0
var killed := 0
## Of those killed, the ones tanks rolled over (the rest the kaiju crushed: stomps, falls, claws).
var run_over := 0
var army_killed := 0  # civilians the army's own stray shells killed (StrayShell)
## Per-frame cost of street life, in microseconds: worst and running total (benchmarking).
var worst_usec := 0
var total_usec := 0
var frames := 0
var _army_fans := 0  # of those, players and fans in a stadium (not the kaiju's kills)
var _cfg: Dictionary
var _fx: Fx
var _rng: RandomNumberGenerator
var _voxel: float
var _nodes := PackedVector2Array()
var _links: Array[Array] = []
var _mms: Array[MultiMesh] = []
var _counts := PackedInt32Array()
var _clock := 0.0
var _sport_rng: RandomNumberGenerator


## sport_rng: the run's presentation stream that picks each stadium's sport (null: a fixed one).
func _init(
	p_sim: RampageSim, fx: Fx, rng: RandomNumberGenerator, sport_rng: RandomNumberGenerator = null
) -> void:
	sim = p_sim
	_fx = fx
	_rng = rng
	_sport_rng = sport_rng if sport_rng != null else Seeds.make("sport", 0)
	_cfg = Content.section("street")
	_voxel = Num.f(_cfg["person_voxel"])


func _ready() -> void:
	traffic = Traffic.new(sim, Seeds.make("traffic", 0))
	add_child(traffic)
	var pavements := Pavements.new(sim)  # the walkable graph
	_nodes = pavements.nodes
	_links = pavements.links
	# A few people per building, spread over the blocks.
	var per_lot := int(GraphicsPresets.cap("civilians"))
	var blocks := _nodes.size() >> 2
	for n: int in per_lot * sim.buildings.size():
		_spawn_civilian(n % maxi(1, blocks))
	var capacity := people.size() + Num.i(_cfg["max_blockades"]) * Num.i(_cfg["cops_per_blockade"])
	capacity += Num.i(_cfg["cops_per_blockade"]) * 4  # officers still running from old blockades
	for outfit: int in VoxelPerson.OUTFITS.size():
		for pose: int in VoxelPerson.POSES:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = VoxelPerson.mesh(outfit, pose, _voxel)
			mm.instance_count = capacity
			mm.visible_instance_count = 0
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			add_child(mmi)
			_mms.append(mm)
	_counts.resize(_mms.size())
	police = Police.new(self, Seeds.make("police", 0))
	add_child(police)
	var stadium := str(Content.sports()["pitch"]["landmark"])
	for i: int in sim.buildings.size():
		if sim.buildings[i].landmark == stadium:
			matches.append(StadiumMatch.new(sim, i, _fx, _sport_rng))
			add_child(matches[-1])


## The pavement corners people can walk between (4 per block, minus the ones in the road).
func ring_nodes() -> PackedVector2Array:
	var out := PackedVector2Array()
	for n: int in _nodes.size():
		if not _links[n].is_empty():
			out.append(_nodes[n])
	return out


func _spawn_civilian(lot: int) -> void:
	var p := Person.new()
	var corner := _rng.randi_range(0, 3)
	var blocks := _nodes.size() >> 2
	# Along the pavement line where there is one: the next corner round, then the next block.
	for _try: int in blocks * 4:
		var from := (lot % blocks) * 4 + corner
		if _links[from].has((from & ~3) + ((from + 1) & 3)):
			break
		corner = (corner + 1) % 4
		lot += 1 if corner == 0 else 0
	p.from_node = (lot % blocks) * 4 + corner
	p.to_node = (p.from_node & ~3) + ((p.from_node + 1) & 3)
	p.pos = _nodes[p.from_node].lerp(_nodes[p.to_node], _rng.randf())
	p.heading = (_nodes[p.to_node] - _nodes[p.from_node]).normalized()
	p.outfit = _rng.randi_range(0, VoxelPerson.COP - 1)
	p.phase = _rng.randf()
	p.side = _rng.randf_range(-SIDE_STEP, SIDE_STEP)
	p.pace = _rng.randf_range(1.0 - PACE_SPREAD, 1.0 + PACE_SPREAD)
	people.append(p)


func civilians() -> int:
	var n := 0
	for p: Person in people:
		if not p.cop:
			n += 1
	return n


## Civilians crushed so far: on the streets, on the pitch and in the stands (fans crushed or
## gone with their stand: director playtest, 2026-10-19); fans a stray shell killed are the army's.
func civilians_killed() -> int:
	var n := killed - _army_fans
	for game: StadiumMatch in matches:
		n += game.killed
		if game.crowd != null:
			n += game.crowd.killed + game.crowd.fallen
	return n


## A number from the "street" tuning (CityView reads fall_spill, Rampage stomp_catch).
func tune(key: String) -> float:
	return Num.f(_cfg[key])


## People the kaiju itself crushed on the streets (stomps, falls, claws): not the tanks' run-overs.
func kaiju_killed() -> int:
	return killed - run_over


## How many civilians are running from the kaiju now (the crowd-panic sound follows it).
func panicking() -> int:
	var n := 0
	for p: Person in people:
		if p.fleeing and not p.cop:
			n += 1
	for game: StadiumMatch in matches:  # a stadium crowd on the run screams with them
		if game.crowd != null:
			n += game.crowd.running()
	return n


## Everyone within `radius` of `at` is crushed (a small dust puff); cars there go flat.
## by_tank: a tank rolled over them, not the kaiju (counted in run_over too). by_army: a stray
## shell did it, so they count as the army's casualties (army_killed), not the kaiju's.
func crush(at: Vector3, radius: float, by_tank: bool = false, by_army: bool = false) -> void:
	var spot: Array[Vector3] = [Vector3(at.x, at.z, radius)]
	crush_all(spot, by_tank, by_army)


## Everyone within any of `spots` (x, z, radius) is crushed, spot by spot as crush() would, with
## one pass over the people (each goes to the first spot that holds it; puffs capped per spot).
## by_tank: tanks rolled over them (run_over), not the kaiju. by_army: stray shells (army_killed).
func crush_all(spots: Array[Vector3], by_tank: bool = false, by_army: bool = false) -> void:
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for s: Vector3 in spots:
		var centre := Vector2(s.x, s.y)
		traffic.crush(centre, s.z)
		for game: StadiumMatch in matches:
			var fans := game.crush(Vector3(s.x, 0.0, s.y), s.z)
			if by_army:
				army_killed += fans
				_army_fans += fans
		lo = lo.min(centre - Vector2.ONE * s.z)
		hi = hi.max(centre + Vector2.ONE * s.z)
	var puffs := PackedInt32Array()
	puffs.resize(spots.size())
	for i: int in range(people.size() - 1, -1, -1):
		var p := people[i]
		if p.pos.x < lo.x or p.pos.y < lo.y or p.pos.x > hi.x or p.pos.y > hi.y:
			continue
		for k: int in spots.size():
			var s := spots[k]
			if p.pos.distance_to(Vector2(s.x, s.y)) > s.z:
				continue
			if puffs[k] < MAX_PUFFS_PER_CRUSH:
				puffs[k] += 1
				_fx.puff(Vector3(p.pos.x, 0.15, p.pos.y))
			_remove(i)
			if by_army:
				army_killed += 1
			else:
				killed += 1
				run_over += 1 if by_tank else 0
			break


## The people under a section that starts to fall (a fall_start event) freeze there; its landing
## (CityView) crushes the same reach: a topple's strip, or a drop's walls plus drop_reach.
func brace_fall(event: Dictionary, drop_reach: float) -> void:
	var b := sim.buildings[Num.i(event["building"])]
	var cells: Array = event["cells"]
	if cells.is_empty():  # a carved scrap smashes nothing
		return
	var seconds := Num.f(event["duration"])
	var spill := tune("fall_spill")
	if str(event["kind"]) == "topple" and event.has("to"):
		var pivot: Vector3 = event["pivot"]
		var to: Vector2 = event["to"]
		var from := Vector2(pivot.x, pivot.z)
		brace(from, to, Num.f(event["width"]) * 0.6 + spill, seconds)
	elif b.landmark == "":
		var at := Vector2(b.x, b.z)
		brace(at, at, maxf(b.w, b.d) * 0.5 + drop_reach + spill, seconds)


## A falling section will land along from..to (a point for a drop) within `radius` in
## `seconds`: the civilians under it freeze there (they cannot outrun a falling tower), so its
## landing crushes them (CityView crushes the same strip).
func brace(from: Vector2, to: Vector2, radius: float, seconds: float) -> void:
	for p: Person in people:
		if p.cop:
			continue
		var q := Geometry2D.get_closest_point_to_segment(p.pos, from, to)
		if p.pos.distance_to(q) <= radius:
			p.pinned_until = _clock + seconds + 0.5


func _remove(i: int) -> void:
	var p := people[i]
	if p.cop and p.state < 2 and p.blockade != null:
		p.blockade.holding -= 1
	people[i] = people[people.size() - 1]
	people.pop_back()


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_clock += delta
	var kaiju := sim.kaiju_pos
	traffic.update(delta)
	police.update(delta, kaiju)
	for i: int in range(people.size() - 1, -1, -1):
		var p := people[i]
		if p.cop:
			if police.update_cop(p, delta, kaiju):
				_remove(i)
		else:
			_update_civilian(p, delta, kaiju)
	_draw_people()
	var spent := Time.get_ticks_usec() - t0
	worst_usec = maxi(worst_usec, spent)
	total_usec += spent
	frames += 1


func _update_civilian(p: Person, delta: float, kaiju: Vector2) -> void:
	if p.pinned_until > _clock:
		return
	var d := p.pos.distance_to(kaiju)
	var panic := _panic_radius()
	if not p.fleeing and d < panic:
		p.fleeing = true
		fled += 1
		p.pinned_until = _clock + Num.f(_cfg["panic_gawk"])  # a moment to take it in
		p.heading = (kaiju - p.pos).normalized()
		var ahead := _nodes[p.to_node] - p.pos
		if ahead.dot(kaiju - p.pos) > 0.0:  # walking toward it: turn round
			var swap := p.from_node
			p.from_node = p.to_node
			p.to_node = swap
	elif p.fleeing and d > panic * Num.f(_cfg["calm_radius"]) / Num.f(_cfg["panic_radius"]):
		p.fleeing = false
	var speed := Num.f(_cfg["run_speed"]) if p.fleeing else Num.f(_cfg["walk_speed"])
	var to := _nodes[p.to_node] - p.pos
	var step := speed * p.pace * delta
	if to.length() > step:
		p.heading = to.normalized()
		p.pos += p.heading * step
		return
	p.pos = _nodes[p.to_node]
	var next := _next_node(p, kaiju)
	p.from_node = p.to_node
	p.to_node = next


func _next_node(p: Person, kaiju: Vector2) -> int:
	var here := p.to_node
	var links: Array = _links[here]
	var options: Array[int] = []
	for n: int in links:
		if n != p.from_node:
			options.append(n)
	if options.is_empty():
		return p.from_node
	if p.fleeing:  # the corner that takes it furthest from the kaiju
		var best := options[0]
		for n: int in options:
			if _nodes[n].distance_to(kaiju) > _nodes[best].distance_to(kaiju):
				best = n
		return best
	var lot := here >> 2
	var crossings: Array[int] = []
	var round_lot: Array[int] = []
	for n: int in options:
		if n >> 2 == lot:
			round_lot.append(n)
		else:
			crossings.append(n)
	var pick := round_lot
	if round_lot.is_empty() or (not crossings.is_empty() and _rng.randf() < CROSS_CHANCE):
		pick = crossings
	return pick[_rng.randi_range(0, pick.size() - 1)]


## How near the kaiju comes before people run: panic_per_scale x body scale, at most
## panic_radius (an adult's): a young kaiju is noticed late, so it reaches the street's people.
func _panic_radius() -> float:
	var r := Num.f(_cfg["panic_per_scale"]) * sim.body_scale()
	return minf(Num.f(_cfg["panic_radius"]), r)


func _pose(p: Person) -> int:
	if p.pinned_until > _clock and not p.cop:  # gawking, or frozen under a fall: standing
		return VoxelPerson.Pose.WALK_A
	var running := p.fleeing or (p.cop and p.state == 2)
	if p.cop and p.state == 1:
		return VoxelPerson.Pose.AIM
	var hz := RUN_HZ if running or p.cop else WALK_HZ
	var odd := int(_clock * hz + p.phase * 2.0) % 2
	if running:
		return VoxelPerson.Pose.RUN_A + odd
	return VoxelPerson.Pose.WALK_A + odd


func _draw_people() -> void:
	_counts.fill(0)
	for p: Person in people:
		var bucket := p.outfit * VoxelPerson.POSES + _pose(p)
		var mm := _mms[bucket]
		if _counts[bucket] >= mm.instance_count:
			continue
		var at := p.pos + Vector2(-p.heading.y, p.heading.x) * p.side
		var basis := Basis(Vector3.UP, atan2(-p.heading.x, -p.heading.y))
		mm.set_instance_transform(_counts[bucket], Transform3D(basis, Vector3(at.x, 0, at.y)))
		_counts[bucket] += 1
	for i: int in _mms.size():
		_mms[i].visible_instance_count = _counts[i]
