class_name StreetLife
extends Node3D
## People in the streets. Civilians walk the pavement round every lot and cross at the
## corners; when the kaiju comes near they turn and run from it, arms up. Police set up
## blockades on a street ahead of it: cruisers park across the road, lights flashing, and
## officers fire their pistols in vain until it is almost on them, then scatter. Stomps,
## falling sections and tank tracks crush them in a puff of dust. Owns the moving traffic.
## Presentation only: the sim and the economy never know any of them exist.

const CORNERS: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
const PAVEMENT := 0.35  # pavement line, out from a building's wall
const PARK_EDGE := 2.95  # pavement line round a park lot, from its middle
const SIDE_STEP := 0.2  # people keep a little to one side of the line
const PACE_SPREAD := 0.2  # walkers differ in pace, so a crowd strings out instead of merging
const WALK_HZ := 3.0
const RUN_HZ := 6.0
const CROSS_CHANCE := 0.3  # a walker at a corner crosses the street rather than turns
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
## Running totals (tests and the capture tool read them).
var fled := 0
var killed := 0
## Per-frame cost of street life, in microseconds: worst and running total (benchmarking).
var worst_usec := 0
var total_usec := 0
var frames := 0
var _cfg: Dictionary
var _fx: Fx
var _rng: RandomNumberGenerator
var _voxel: float
var _nodes := PackedVector2Array()
var _links: Array[Array] = []
var _mms: Array[MultiMesh] = []
var _counts := PackedInt32Array()
var _clock := 0.0


func _init(p_sim: RampageSim, fx: Fx, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	_fx = fx
	_rng = rng
	_cfg = Content.section("street")
	_voxel = Num.f(_cfg["person_voxel"])


func _ready() -> void:
	traffic = Traffic.new(sim, Seeds.make("traffic", 0))
	add_child(traffic)
	_build_pavements()
	var per_lot := Num.i(_cfg["civilians_per_lot"])
	for lot: int in _nodes.size() >> 2:
		for n: int in per_lot:
			_spawn_civilian(lot)
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


## Pavement corners round every lot (4 per lot), linked round the lot and across the streets.
func _build_pavements() -> void:
	var grid := Num.i(sim.city["grid"])
	var spacing := Num.f(sim.city["spacing"])
	var half := CityGen.half_extent(sim.city)
	var lots := {}
	for b: RampageSim.Building in sim.buildings:
		lots[Vector2i(roundi((b.x + half) / spacing), roundi((b.z + half) / spacing))] = b
	for gx: int in grid:
		for gz: int in grid:
			var centre := Vector2(-half + gx * spacing, -half + gz * spacing)
			var size := Vector2(PARK_EDGE, PARK_EDGE)
			var key := Vector2i(gx, gz)
			if lots.has(key):
				var b: RampageSim.Building = lots[key]
				centre = Vector2(b.x, b.z)
				size = Vector2(b.w * 0.5 + PAVEMENT, b.d * 0.5 + PAVEMENT)
			for c: Vector2 in CORNERS:
				_nodes.append(centre + c * size)
				_links.append([])
	for gx: int in grid:
		for gz: int in grid:
			var lot := gx * grid + gz
			for c: int in 4:
				_link(lot * 4 + c, lot * 4 + (c + 1) % 4)
			if gx + 1 < grid:  # across the street to the lot on +x
				var east := (gx + 1) * grid + gz
				_link(lot * 4 + 1, east * 4 + 0)
				_link(lot * 4 + 2, east * 4 + 3)
			if gz + 1 < grid:  # across the street to the lot on +z
				var south := gx * grid + gz + 1
				_link(lot * 4 + 3, south * 4 + 0)
				_link(lot * 4 + 2, south * 4 + 1)


func _link(a: int, b: int) -> void:
	_links[a].append(b)
	_links[b].append(a)


func _spawn_civilian(lot: int) -> void:
	var p := Person.new()
	var corner := _rng.randi_range(0, 3)
	p.from_node = lot * 4 + corner
	p.to_node = lot * 4 + (corner + 1) % 4
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


## Everyone within `radius` of `at` is crushed (a small dust puff); cars there go flat.
func crush(at: Vector3, radius: float) -> void:
	var centre := Vector2(at.x, at.z)
	traffic.crush(centre, radius)
	var puffs := 0
	for i: int in range(people.size() - 1, -1, -1):
		var p := people[i]
		if p.pos.distance_to(centre) > radius:
			continue
		if puffs < MAX_PUFFS_PER_CRUSH:
			puffs += 1
			_fx.puff(Vector3(p.pos.x, 0.15, p.pos.y))
		_remove(i)
		killed += 1


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
	var d := p.pos.distance_to(kaiju)
	if not p.fleeing and d < Num.f(_cfg["panic_radius"]):
		p.fleeing = true
		fled += 1
		var ahead := _nodes[p.to_node] - p.pos
		if ahead.dot(kaiju - p.pos) > 0.0:  # walking toward it: turn round
			var swap := p.from_node
			p.from_node = p.to_node
			p.to_node = swap
	elif p.fleeing and d > Num.f(_cfg["calm_radius"]):
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


func _pose(p: Person) -> int:
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
