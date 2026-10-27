class_name IslandFracture
extends RefCounted
## The pure parts of how an IslandBody breaks (no node state): which bricks join which chunk when
## a slab splits, the half-brick pieces of a brick, the spread of a fracture front, and the
## fastest recent velocity a hard hit was lost from. Deterministic given the RNG handed in.


## Splits `keys` (brick keys) into groups of about `chunk` bricks: each brick joins the nearest of
## seeded seed bricks.
static func group_bricks(keys: Array, rng: RandomNumberGenerator, chunk: float) -> Array[Array]:
	var seeds: Array = keys.duplicate()
	for k: int in range(seeds.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var swap: Variant = seeds[k]
		seeds[k] = seeds[j]
		seeds[j] = swap
	seeds.resize(ceili(keys.size() / maxf(1.0, chunk)))
	var groups: Array[Array] = []
	for _s: Variant in seeds:
		groups.append([])
	for key: Vector3i in keys:
		var best := 0
		var near := INF
		for s: int in seeds.size():
			var seed_key: Vector3i = seeds[s]
			var d := Vector3(key - seed_key).length_squared()
			if d < near:
				near = d
				best = s
		groups[best].append(key)
	return groups


## Half-brick pieces (res/2 cells a side) round brick cells `own` (positions in `cells`), each in
## its first material; `com` is the body's centre of mass at spawn.
static func pieces_of(
	site: CarveSite,
	cells: PackedInt32Array,
	mats: PackedByteArray,
	own: PackedInt32Array,
	frame: Array,
	out: Array[Dictionary]
) -> void:
	var xf: Transform3D = frame[0]
	var com: Vector3 = frame[1]
	var v: Vector3 = frame[2]
	var half := maxi(1, site.res >> 1)
	var groups := {}
	for k: int in own:
		var sub := site.cell(cells[k]) / half
		if not groups.has(sub):
			groups[sub] = PackedInt32Array()
		var list: PackedInt32Array = groups[sub]
		list.append(k)
		groups[sub] = list
	for sub: Vector3i in groups:
		var ks: PackedInt32Array = groups[sub]
		var box := CarveMesh.span(site, cells, ks)
		var at := xf * (box.get_center() - com)
		(
			out
			. append(
				{
					"xf": Transform3D(xf.basis, at),
					"size": box.size,
					"color": site.color(mats[ks[0]]),
					"v": v,
				}
			)
		)


## The height spread (standard deviation) of the bricks that border a break of `keys`, or -1 when
## fewer than two border it. `centre` maps brick -> world height.
static func front_spread(keys: Array[Vector3i], bricks: Dictionary, centre: Dictionary) -> float:
	var gone := {}
	for key: Vector3i in keys:
		gone[key] = true
	var ys: Array[float] = []
	var seen := {}
	for key: Vector3i in keys:
		for step: Vector3i in CarveMesh.STEPS:
			var n := key + step
			if bricks.has(n) and not gone.has(n) and not seen.has(n):
				seen[n] = true
				ys.append(Num.f(centre[n]))
	if ys.size() < 2:
		return -1.0
	var mean := 0.0
	for y: float in ys:
		mean += y
	mean /= ys.size()
	var sq := 0.0
	for y: float in ys:
		sq += (y - mean) * (y - mean)
	return sqrt(sq / ys.size())


## The velocity the body had just before a hard hit, or ZERO: the fastest recent velocity above
## break_speed that the body has since lost more than break_jolt of. Looking back break_window
## seconds, not one step, catches a slab that lands on a pile and slows over several steps.
## `recent` holds (velocity, clock) over that window; this step's `v` at `clock` is added to it.
static func hard_hit(recent: Array[Vector4], v: Vector3, clock: float, cfg: Dictionary) -> Vector3:
	var speed := Num.f(cfg["break_speed"])
	var window := Num.f(cfg["break_window"])
	recent.append(Vector4(v.x, v.y, v.z, clock))
	while recent[0].w < clock - window:
		recent.pop_front()
	var out := Vector3.ZERO
	var worst := speed * Num.f(cfg["break_jolt"])
	for r: Vector4 in recent:
		var old := Vector3(r.x, r.y, r.z)
		var lost := (old - v).length()
		if old.length() > speed and lost > worst:
			worst = lost
			out = old
	return out
