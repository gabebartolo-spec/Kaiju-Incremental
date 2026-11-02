class_name FallContact
extends RefCounted
## What a falling part runs into on its way down (director 2026-11-03: a falling building never
## passes through a standing neighbour or the kaiju). Each tick the part's chunks are placed where
## the view draws them (the topple's tilt curve, ToppleFx, and the drop's fall) and sampled (centre
## and corners, inset) against two volumes:
##  - a standing neighbour's live chunks: the part carves them (city impact_damage, a landing's
##    blow); a chunk that survives the blow stops the part there, and it breaks up against it;
##  - the kaiju's hide (a rigid capsule round his body, never deformed): the part breaks up
##    against him at once and its fragments fall off him (KaijuHide in the view).
## Tuning: fall_contact. Part of Collapse; deterministic, no randomness.


## The tilt (radians) t seconds into a topple the sim times at `duration` (tuning topple_fx): a
## shudder that creeps to lean_deg, then a lean that accelerates (sinh) to 90 deg at `duration`.
static func tilt(cfg: Dictionary, t: float, duration: float) -> float:
	var shudder := minf(Num.f(cfg["shudder_s"]), duration * Num.f(cfg["shudder_max_share"]))
	var lean := deg_to_rad(Num.f(cfg["lean_deg"]))
	if t < shudder:
		var k := t / shudder
		var wobble := (
			sin(t * TAU * Num.f(cfg["shudder_hz"])) * deg_to_rad(Num.f(cfg["shudder_deg"]))
		)
		return lean * k * k + wobble * (1.0 - k * 0.5)
	var u := clampf((t - shudder) / maxf(0.001, duration - shudder), 0.0, 1.0)
	var c := Num.f(cfg["lean_curve"])
	return lean + (PI * 0.5 - lean) * sinh(c * u) / sinh(c)


## The part's pose at t: world = pose * (chunk centre - pivot). A topple turns about the level
## axis across its direction (FallMotion's); both kinds fall their drop with the square of time.
static func pose(f: RampageSim.Fall, t: float, topple_cfg: Dictionary) -> Transform3D:
	var k := clampf(t / maxf(0.05, f.duration), 0.0, 1.0)
	var origin := f.pivot - Vector3(0, f.drop * k * k, 0)
	if f.kind != "topple":
		return Transform3D(Basis(), origin)
	var axis := Vector3(f.dir.y, 0, -f.dir.x)
	if axis.is_zero_approx():
		axis = Vector3.RIGHT
	return Transform3D(Basis(axis.normalized(), tilt(topple_cfg, t, f.duration)), origin)


## The kaiju's hide: [foot centre, head centre, radius] (a capsule, world).
static func hide(sim: RampageSim, cfg: Dictionary) -> Array:
	var r := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale() * Num.f(cfg["hide_radius"])
	var tall := maxf(sim.reach_height() * Num.f(cfg["hide_height"]), 2.0 * r)
	var foot := Vector3(sim.kaiju_pos.x, sim.stand_y + r, sim.kaiju_pos.y)
	return [foot, foot + Vector3(0, tall - 2.0 * r, 0), r]


## How deep point p is inside capsule `cap` (hide()); <= 0 outside.
static func hide_depth(p: Vector3, cap: Array) -> float:
	var a: Vector3 = cap[0]
	var b: Vector3 = cap[1]
	var on := a + (b - a) * clampf((p - a).dot(b - a) / maxf(1e-6, (b - a).length_squared()), 0, 1)
	return Num.f(cap[2]) - p.distance_to(on)


## How deep point p is inside a live chunk of building b; <= 0 outside every one.
static func chunk_depth(b: RampageSim.Building, p: Vector3) -> float:
	var local := Vector3(p.x - (b.x - b.w * 0.5), p.y - b.base, p.z - (b.z - b.d * 0.5))
	var c := Vector3i(floori(local.x), floori(local.y), floori(local.z))
	if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= b.w or c.y >= b.height or c.z >= b.d:
		return 0.0
	if not b.frame.alive(c):
		return 0.0
	var f := local - Vector3(c)
	return minf(minf(minf(f.x, 1.0 - f.x), minf(f.y, 1.0 - f.y)), minf(f.z, 1.0 - f.z))


## The sample points of a part's chunks at `xf` (centre and 8 corners pulled in by `inset`),
## only of chunks whose centre lies inside `within` (what it may touch, grown by a chunk):
## [points, the same points where the fall began] (no tilt, no drop). What a point already
## touched as it began (the base he chewed, a wall it leant on) never counts as running into it.
static func samples(
	f: RampageSim.Fall, b: RampageSim.Building, xf: Transform3D, inset: float, within: AABB
) -> Array[PackedVector3Array]:
	var out := PackedVector3Array()
	var was := PackedVector3Array()
	var start := Transform3D(Basis(), f.pivot)
	var h := 0.5 - inset
	for c: Vector3i in f.cells:
		var rel := b.chunk_world(c) - f.pivot
		if not within.has_point(xf * rel):
			continue
		for k: int in 9:
			var off := Vector3.ZERO
			if k < 8:
				off = Vector3(h if k & 1 else -h, h if k & 2 else -h, h if k & 4 else -h)
			out.append(xf * (rel + off))
			was.append(start * (rel + off))
	return [out, was]


## What part f runs into this tick (f.t already advanced by dt): {} for nothing, else
## {"contact": "kaiju"} or {"contact": "building"} (a chunk survived its blow). Neighbour chunks
## it reaches are carved on the way. On a contact f.t is set back to the moment of first touch
## (bisected over the tick, bisect steps), so it stops on the surface, not a tick's sweep inside.
static func step(
	sim: RampageSim, f: RampageSim.Fall, cfg: Dictionary, topple_cfg: Dictionary, dt: float
) -> Dictionary:
	if f.cells.is_empty():
		return {}
	var hit := probe(sim, f, f.t, cfg, topple_cfg, true)
	if hit.is_empty():
		return hit
	var lo := maxf(0.0, f.t - dt)
	var hi := f.t
	for _k: int in Num.i(cfg["bisect"]):
		var mid := (lo + hi) * 0.5
		if probe(sim, f, mid, cfg, topple_cfg, false).is_empty():
			lo = mid
		else:
			hi = mid
	f.t = lo  # the last pose clear of it: the view shatters the part there
	return hit


## What f touches at time t (`carve`: neighbour chunks it reaches take a landing's blow first).
static func probe(
	sim: RampageSim,
	f: RampageSim.Fall,
	t: float,
	cfg: Dictionary,
	topple_cfg: Dictionary,
	carve: bool
) -> Dictionary:
	var own := sim.buildings[f.building]
	var xf := pose(f, t, topple_cfg)
	var box := xf * _span(f, own)  # its whole box first: most ticks touch nothing and stop here
	var lo := box.position
	var hi := box.end
	var cap := hide(sim, cfg)
	var a: Vector3 = cap[0]
	var b: Vector3 = cap[1]
	var r := Num.f(cap[2])
	var near_kaiju := (
		lo.x < a.x + r
		and hi.x > a.x - r
		and lo.z < a.z + r
		and hi.z > a.z - r
		and lo.y < b.y + r
		and hi.y > a.y - r
	)
	var near: Array[int] = []
	# Neighbours from the end of the shudder (its few degrees of wobble are the tower's death
	# throes, drawn against a wall it shares, not a fall into it).
	var shudder := minf(
		Num.f(topple_cfg["shudder_s"]), f.duration * Num.f(topple_cfg["shudder_max_share"])
	)
	if f.kind == "topple" and t >= shudder:
		for i: int in sim.grid.in_rect(Vector2(lo.x, lo.z), Vector2(hi.x, hi.z)):
			var nb := sim.buildings[i]
			if i == f.building or lo.y > nb.base + nb.height:
				continue
			if hi.x < nb.x - nb.w * 0.5 or lo.x > nb.x + nb.w * 0.5:
				continue
			if hi.z < nb.z - nb.d * 0.5 or lo.z > nb.z + nb.d * 0.5:
				continue
			near.append(i)
	if not near_kaiju and near.is_empty():
		return {}
	var within := AABB()
	var first := true
	if near_kaiju:
		within = AABB(Vector3(a.x - r, a.y - r, a.z - r), Vector3(2 * r, b.y - a.y + 2 * r, 2 * r))
		first = false
	for i: int in near:
		var nb := sim.buildings[i]
		var nbox := AABB(
			Vector3(nb.x - nb.w * 0.5, nb.base, nb.z - nb.d * 0.5), Vector3(nb.w, nb.height, nb.d)
		)
		within = nbox if first else within.merge(nbox)
		first = false
	var both := samples(f, own, xf, Num.f(cfg["inset"]), within.grow(0.9))
	var pts := both[0]
	var was := both[1]
	if near_kaiju:
		for n: int in pts.size():
			if hide_depth(pts[n], cap) > 0.0 and hide_depth(was[n], cap) <= 0.0:
				return {"contact": "kaiju"}
	var blow := Num.f(sim.city["impact_damage"])
	for i: int in near:
		var nb := sim.buildings[i]
		var hit: Array[Vector3i] = []
		for n: int in pts.size():
			var p := pts[n]
			if chunk_depth(nb, p) > 0.0 and chunk_depth(nb, was[n]) <= 0.0:
				var c := Vector3i(
					floori(p.x - (nb.x - nb.w * 0.5)),
					floori(p.y - nb.base),
					floori(p.z - (nb.z - nb.d * 0.5))
				)
				if not hit.has(c):
					hit.append(c)
		if hit.is_empty():
			continue
		if carve:
			sim.damage_chunks(i, hit, blow)
		for c: Vector3i in hit:
			if nb.frame.alive(c):
				return {"contact": "building", "with": i}
	return {}


## The local box (relative to the pivot, sim units) round all of f's chunks.
static func _span(f: RampageSim.Fall, b: RampageSim.Building) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for c: Vector3i in f.cells:
		var p := b.chunk_world(c) - f.pivot
		lo = lo.min(p)
		hi = hi.max(p)
	return AABB(lo - Vector3.ONE * 0.5, hi - lo + Vector3.ONE)
