class_name StreetLife
extends Node3D
## People in the streets. Civilians walk the pavement round every block and cross at the
## corners; when the kaiju comes near they turn and run from it, arms up. Police set up
## blockades on a street ahead of it: cruisers park across the road, lights flashing, and
## officers fire their pistols in vain until it is almost on them, then scatter. Stomps,
## falling sections and tank tracks crush them in a puff of dust. Owns the moving traffic.
## Presentation only: the sim and the economy never know any of them exist.
## People are parallel packed arrays (8.9k-17.7k): the frame loop touches no per-person object.

const SIDE_STEP := 0.2  # people keep a little to one side of the line
const PACE_SPREAD := 0.2  # walkers differ in pace, so a crowd strings out instead of merging
const WALK_HZ := 3.0
const RUN_HZ := 6.0
const WALK_SAMPLE := 0.5  # a pavement line is checked for road this often
const MAX_PUFFS_PER_CRUSH := 1  # each puff is a particle node: one per stomp keeps it cheap

var sim: RampageSim
var traffic: Traffic
var police: Police
## Everyone in the street, person i at index i of every array (a removal moves the last one in).
var pos := PackedVector2Array()
var heading := PackedVector2Array()
var outfit := PackedInt32Array()
var phase := PackedFloat64Array()  # 64-bit, as GDScript floats are: the same math as before
var side := PackedFloat64Array()
var pace := PackedFloat64Array()
var from_node := PackedInt32Array()
var to_node := PackedInt32Array()
var fleeing := PackedByteArray()
## Standing still until this clock time: gawking at the kaiju a moment before running, or
## frozen under a falling tower (nobody outruns one).
var pinned_until := PackedFloat64Array()
var cop := PackedByteArray()
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
var _officers: Array[Police.Officer] = []  # null for a civilian
var _cfg: Dictionary
var _fx: Fx
var _rng: RandomNumberGenerator
var _voxel: float
var _pavements: Pavements
var _nodes := PackedVector2Array()
var _mms: Array[MultiMesh] = []
var _counts := PackedInt32Array()
var _capacity := 0
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
	_pavements = Pavements.new(sim)  # the walkable graph
	_pavements.rng = _rng
	_nodes = _pavements.nodes
	# A few people per building, spread over the blocks.
	var per_lot := int(GraphicsPresets.cap("civilians"))
	var blocks := _nodes.size() >> 2
	for n: int in per_lot * sim.buildings.size():
		_spawn_civilian(n % maxi(1, blocks))
	_capacity = pos.size() + Num.i(_cfg["max_blockades"]) * Num.i(_cfg["cops_per_blockade"])
	_capacity += Num.i(_cfg["cops_per_blockade"]) * 4  # officers still running from old blockades
	for dress: int in VoxelPerson.OUTFITS.size():
		for pose: int in VoxelPerson.POSES:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = VoxelPerson.mesh(dress, pose, _voxel)
			mm.instance_count = _capacity
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
	return _pavements.ring_nodes()


## One more person at the end of every array, standing at the origin; returns its index.
func _add() -> int:
	pos.append(Vector2.ZERO)
	heading.append(Vector2(0, -1))
	outfit.append(0)
	phase.append(0.0)
	side.append(0.0)
	pace.append(1.0)
	from_node.append(0)
	to_node.append(0)
	fleeing.append(0)
	pinned_until.append(-1.0)
	cop.append(0)
	_officers.append(null)
	return pos.size() - 1


func _spawn_civilian(lot: int) -> void:
	var corner := _rng.randi_range(0, 3)
	var blocks := _nodes.size() >> 2
	# Along the pavement line where there is one: the next corner round, then the next block.
	for _try: int in blocks * 4:
		var from := (lot % blocks) * 4 + corner
		if _pavements.links[from].has((from & ~3) + ((from + 1) & 3)):
			break
		corner = (corner + 1) % 4
		lot += 1 if corner == 0 else 0
	var i := _add()
	from_node[i] = (lot % blocks) * 4 + corner
	to_node[i] = (from_node[i] & ~3) + ((from_node[i] + 1) & 3)
	pos[i] = _nodes[from_node[i]].lerp(_nodes[to_node[i]], _rng.randf())
	heading[i] = (_nodes[to_node[i]] - _nodes[from_node[i]]).normalized()
	outfit[i] = _rng.randi_range(0, VoxelPerson.COP - 1)
	phase[i] = _rng.randf()
	side[i] = _rng.randf_range(-SIDE_STEP, SIDE_STEP)
	pace[i] = _rng.randf_range(1.0 - PACE_SPREAD, 1.0 + PACE_SPREAD)


## An officer joins the street (Police): drawn and crushed with everyone else.
func add_cop(officer: Police.Officer) -> void:
	var i := _add()
	pos[i] = officer.pos
	heading[i] = officer.heading
	outfit[i] = VoxelPerson.COP
	phase[i] = officer.phase
	cop[i] = 1
	_officers[i] = officer


func civilians() -> int:
	return cop.count(0)


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
	for i: int in pos.size():
		if fleeing[i] == 1 and cop[i] == 0:
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
		_crush_stadiums(s, by_army)
		lo = lo.min(centre - Vector2.ONE * s.z)
		hi = hi.max(centre + Vector2.ONE * s.z)
	var puffs := PackedInt32Array()
	puffs.resize(spots.size())
	for i: int in range(pos.size() - 1, -1, -1):
		var at := pos[i]
		if at.x < lo.x or at.y < lo.y or at.x > hi.x or at.y > hi.y:
			continue
		for k: int in spots.size():
			var s := spots[k]
			if at.distance_to(Vector2(s.x, s.y)) > s.z:
				continue
			if puffs[k] < MAX_PUFFS_PER_CRUSH:
				puffs[k] += 1
				_fx.puff(Vector3(at.x, 0.15, at.y))
			_remove(i)
			_count_crushed(by_tank, by_army)
			break


## The pitch and stands within spot s (x, z, radius) are crushed; a stray's fans are the army's.
func _crush_stadiums(s: Vector3, by_army: bool) -> void:
	for game: StadiumMatch in matches:
		var fans := game.crush(Vector3(s.x, 0.0, s.y), s.z)
		if by_army:
			army_killed += fans
			_army_fans += fans


## One person crushed: the kaiju's (killed; run_over too if a tank did it) or the army's own.
func _count_crushed(by_tank: bool, by_army: bool) -> void:
	if by_army:
		army_killed += 1
	else:
		killed += 1
		run_over += 1 if by_tank else 0


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
	for i: int in pos.size():
		if cop[i] == 1:
			continue
		var q := Geometry2D.get_closest_point_to_segment(pos[i], from, to)
		if pos[i].distance_to(q) <= radius:
			pinned_until[i] = _clock + seconds + 0.5


func _remove(i: int) -> void:
	var officer := _officers[i]
	if officer != null and officer.state < 2 and officer.blockade != null:
		officer.blockade.holding -= 1
	var last := pos.size() - 1
	pos[i] = pos[last]
	heading[i] = heading[last]
	outfit[i] = outfit[last]
	phase[i] = phase[last]
	side[i] = side[last]
	pace[i] = pace[last]
	from_node[i] = from_node[last]
	to_node[i] = to_node[last]
	fleeing[i] = fleeing[last]
	pinned_until[i] = pinned_until[last]
	cop[i] = cop[last]
	_officers[i] = _officers[last]
	pos.resize(last)
	heading.resize(last)
	outfit.resize(last)
	phase.resize(last)
	side.resize(last)
	pace.resize(last)
	from_node.resize(last)
	to_node.resize(last)
	fleeing.resize(last)
	pinned_until.resize(last)
	cop.resize(last)
	_officers.resize(last)


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_clock += delta
	var kaiju := sim.kaiju_pos
	traffic.update(delta)
	police.update(delta, kaiju)
	_walk(delta, kaiju)
	_draw_people()
	var spent := Time.get_ticks_usec() - t0
	worst_usec = maxi(worst_usec, spent)
	total_usec += spent
	frames += 1


## Everyone's step this frame, last index first (a removal moves the last in); officers go to
## Police. Tuning reads and the panic radius are taken once (the same values: the same math).
func _walk(delta: float, kaiju: Vector2) -> void:
	var panic := _panic_radius()
	var calm := panic * Num.f(_cfg["calm_radius"]) / Num.f(_cfg["panic_radius"])
	var gawk := Num.f(_cfg["panic_gawk"])
	var run := Num.f(_cfg["run_speed"])
	var walk := Num.f(_cfg["walk_speed"])
	for i: int in range(pos.size() - 1, -1, -1):
		if cop[i] == 1:
			var officer := _officers[i]
			if police.update_cop(officer, delta, kaiju):
				_remove(i)
			else:
				pos[i] = officer.pos
				heading[i] = officer.heading
			continue
		if pinned_until[i] > _clock:
			continue
		var at := pos[i]
		var d := at.distance_to(kaiju)
		if fleeing[i] == 0 and d < panic:
			_startle(i, at, kaiju, gawk)
		elif fleeing[i] == 1 and d > calm:
			fleeing[i] = 0
		var running := fleeing[i] == 1
		var to := _nodes[to_node[i]] - at
		var step := (run if running else walk) * pace[i] * delta
		if to.length() > step:
			var dir := to.normalized()
			heading[i] = dir
			pos[i] = at + dir * step
			continue
		pos[i] = _nodes[to_node[i]]
		var next := _pavements.next_corner(to_node[i], from_node[i], kaiju, fleeing[i] == 1)
		from_node[i] = to_node[i]
		to_node[i] = next


## Person i sees the kaiju: a moment (gawk) facing it, then runs; one walking toward it turns.
func _startle(i: int, at: Vector2, kaiju: Vector2, gawk: float) -> void:
	fleeing[i] = 1
	fled += 1
	pinned_until[i] = _clock + gawk
	heading[i] = (kaiju - at).normalized()
	if (_nodes[to_node[i]] - at).dot(kaiju - at) > 0.0:
		var swap := from_node[i]
		from_node[i] = to_node[i]
		to_node[i] = swap


## How near the kaiju comes before people run: panic_per_scale x body scale, at most
## panic_radius (an adult's): a young kaiju is noticed late, so it reaches the street's people.
func _panic_radius() -> float:
	var r := Num.f(_cfg["panic_per_scale"]) * sim.body_scale()
	return minf(Num.f(_cfg["panic_radius"]), r)


## A person's pose: standing (gawking or frozen), aiming (an officer holding), else a stride.
func _pose(i: int) -> int:
	if cop[i] == 1:
		var state := _officers[i].state
		if state == 1:
			return VoxelPerson.Pose.AIM
		var stride := int(_clock * RUN_HZ + phase[i] * 2.0) % 2
		return (VoxelPerson.Pose.RUN_A if state == 2 else VoxelPerson.Pose.WALK_A) + stride
	if pinned_until[i] > _clock:
		return VoxelPerson.Pose.WALK_A
	if fleeing[i] == 1:
		return VoxelPerson.Pose.RUN_A + int(_clock * RUN_HZ + phase[i] * 2.0) % 2
	return VoxelPerson.Pose.WALK_A + int(_clock * WALK_HZ + phase[i] * 2.0) % 2


func _draw_people() -> void:
	_counts.fill(0)
	for i: int in pos.size():
		var bucket := outfit[i] * VoxelPerson.POSES + _pose(i)
		if _counts[bucket] >= _capacity:
			continue
		var look := heading[i]
		var at := pos[i] + Vector2(-look.y, look.x) * side[i]
		var basis := Basis(Vector3.UP, atan2(-look.x, -look.y))
		_mms[bucket].set_instance_transform(
			_counts[bucket], Transform3D(basis, Vector3(at.x, 0, at.y))
		)
		_counts[bucket] += 1
	for i: int in _mms.size():
		_mms[i].visible_instance_count = _counts[i]
