class_name CarvePhysics
extends CarvePhysicsStats
## The physics the player sees when buildings are carved (D-094, option A, WP5). It reads the
## sim's carve and settle events and never writes back: what fell, where and what it crushed
## are the sim's; the tumbling, breaking and settling here are cosmetic (Teardown's split).
##  - carved(): the standing part's colliders are rebuilt where cut, rubble that lay there wakes,
##    and some carved cells fly out as live debris in their own material.
##  - fell(): a part that lost support becomes an IslandBody; a topple follows the sim's turn
##    about its pivot for ~1 s, then Jolt takes it and it breaks up from the bottom on hard hits.
##  - Live bodies are capped city-wide (live_cap; Jolt's default limit is 10,240 bodies and the
##    spike's 2,500 per building x 6 hit it): past the cap the oldest pieces shrink away; a piece
##    at rest freezes into its building's static rubble MultiMesh.
## Dust goes to `fx` when set.
## Sits at the world origin: its children are placed in world space.

## A chunk split off an island became an island of its own (captures follow its breaks).
signal spawned(island: IslandBody)

var fx: Fx
var _rng := RandomNumberGenerator.new()
var _colliders: Dictionary = {}  # key -> CarveCollider
var _dust_at: Dictionary = {}  # key -> clock of its last carve dust
var _clock := 0.0  # presentation seconds, for dust spacing only
var _gravity := 1.0  # the sim's fall gravity over the engine's
var _seed := 0


func _init(seed_value: int) -> void:
	_seed = seed_value
	_rng.seed = seed_value
	_cfg = Content.section("carve_physics")
	var engine := Num.f(ProjectSettings.get_setting("physics/3d/default_gravity"))
	_gravity = Num.f(Content.section("city")["fall_gravity"]) / engine


## Registers a carved building (on its first hit): its colliders and its debris.
func add_site(site: CarveSite, grid: PackedByteArray) -> void:
	site.use_palette(_cfg)
	_sites[site.key] = site
	var collider := CarveCollider.new(site)
	add_child(collider)
	collider.build(grid, true)  # over the next ticks: a first hit never hitches (item 10)
	_colliders[site.key] = collider
	var debris := CarveDebris.new()
	debris.site = site
	debris.grid = grid
	add_child(debris)
	_debris[site.key] = debris


func site(key: int) -> CarveSite:
	var out: CarveSite = _sites.get(key)
	return out


## A carve happened: `cut` is {"cells": PackedInt32Array (removed), "mats": PackedByteArray
## (their materials, parallel), "push": Vector3 (the blow's direction)}; `grid` is after it.
func carved(key: int, grid: PackedByteArray, cut: Dictionary) -> void:
	var s: CarveSite = _sites[key]
	var cells: PackedInt32Array = cut["cells"]
	if cells.is_empty():
		return
	var mats: PackedByteArray = cut.get("mats", PackedByteArray())
	var push: Vector3 = cut.get("push", Vector3.ZERO)
	var collider: CarveCollider = _colliders[key]
	collider.touched(grid, cells)
	var box := _box(s, cells)
	var debris: CarveDebris = _debris[key]
	debris.grid = grid
	debris.wake(_above(s, box))
	var n := mini(Num.i(_cfg["debris_per_carve"]), cells.size())
	if live_bodies() >= int(GraphicsPresets.cap("debris_live")):
		n = 0
	var sizes: Array = _cfg["debris_sizes"]
	for _k: int in n:
		var pick := _rng.randi_range(0, cells.size() - 1)
		var cells_wide := Num.f(sizes[_rng.randi_range(0, sizes.size() - 1)])
		var size := Vector3.ONE * cells_wide / s.res
		var m := mats[pick] if pick < mats.size() else 0
		var spread := Vector3(
			_rng.randf_range(-1, 1), _rng.randf_range(0.2, 1), _rng.randf_range(-1, 1)
		)
		var v := push * Num.f(_cfg["debris_push"]) + spread * Num.f(_cfg["debris_spread"])
		var spin := _spin() * Num.f(_cfg["debris_spin"])
		var xf := _lift(Transform3D(Basis(), s.world(s.cell(cells[pick]))), size)
		var motion := [v, spin, Num.f(_cfg["debris_gravity"]), _mass(s, size)]
		debris.spawn(xf, size, s.color(m), motion)
	_carve_dust(key, box, cells.size())


## A part lost support: `event` is VoxelFrame.settle()'s shape {"cells" (building-local),
## "index" (grid indices), "kind": "drop"|"topple", "pivot" (building-local sim units),
## "dir": Vector2i, "mats" (the cells' materials, parallel)} and optionally "duration" (the
## sim's fall time); `grid` is after the part left it.
func fell(key: int, grid: PackedByteArray, event: Dictionary) -> IslandBody:
	var s: CarveSite = _sites[key]
	var cells := s.indices(event)
	var mats: PackedByteArray = event.get("mats", PackedByteArray())
	if mats.size() != cells.size():
		mats.resize(cells.size())
	var collider: CarveCollider = _colliders[key]
	collider.touched(grid, cells)
	var d: CarveDebris = _debris[key]
	d.grid = grid
	var island := _island(key, cells, mats)
	var box := _box(s, cells)
	if str(event["kind"]) == "topple":
		var raw_pivot: Vector3 = event["pivot"]
		var pivot := s.from_local(raw_pivot)
		var dir := _dir(event["dir"])
		var g := Num.f(Content.section("city")["fall_gravity"])
		var duration := sqrt(2.0 * box.size.y / g) * Num.f(_cfg["topple_slow"])
		if event.has("duration"):
			duration = Num.f(event["duration"])
		var seconds := minf(Num.f(_cfg["follow_seconds"]), duration * Num.f(_cfg["follow_share"]))
		island.follow(pivot, dir, duration, seconds)
		_dust(pivot + Vector3.UP * 0.5, box.size.x * 0.3)
	return island


## A new island body of building `key`'s cells, its breaks and splits wired to this view.
func _island(key: int, cells: PackedInt32Array, mats: PackedByteArray) -> IslandBody:
	var s: CarveSite = _sites[key]
	var island := IslandBody.new(s, cells, mats, hash([_seed, key]))
	island.gravity_scale = _gravity
	add_child(island)
	_islands.append(island)
	island.tree_exited.connect(func() -> void: _islands.erase(island))
	island.broke.connect(
		func(pieces: Array[Dictionary], at: Vector3) -> void: _broke(key, pieces, at)
	)
	island.split.connect(func(parts: Array[Dictionary]) -> void: _split(key, parts, island))
	return island


## An island split: each chunk becomes an island where it lay, with the chunk's speed and spin.
func _split(key: int, parts: Array[Dictionary], parent: IslandBody) -> void:
	for part: Dictionary in parts:
		var own: PackedInt32Array = part["cells"]
		var own_mats: PackedByteArray = part["mats"]
		var chunk := _island(key, own, own_mats)
		var layers: Array = part["layers"]  # the parent's, not the defaults
		chunk.collision_layer = Num.i(layers[0])
		chunk.collision_mask = Num.i(layers[1])
		chunk.cell_material = parent.cell_material
		chunk.global_transform = part["xf"]
		chunk.linear_velocity = part["v"]
		chunk.angular_velocity = part["w"]
		spawned.emit(chunk)


func _physics_process(delta: float) -> void:
	_clock += delta
	IslandMesh.reap(false)  # remeshes of islands already gone
	var over := live_bodies() - int(GraphicsPresets.cap("debris_live"))
	if over > 0:
		var live := maxi(1, live_bodies())
		for key: int in _debris:
			var d: CarveDebris = _debris[key]
			d.retire(ceili(float(over) * d.live() / live))
	var statics := 0
	for key: int in _debris:
		var d: CarveDebris = _debris[key]
		statics += d.static_bodies()
	var cap := int(GraphicsPresets.cap("debris_static"))
	if statics > cap:
		for key: int in _debris:
			var d: CarveDebris = _debris[key]
			d.trim_static(floori(float(d.static_bodies()) * cap / statics))


## The islands left before it (children exit first): wait on any remesh still running.
func _exit_tree() -> void:
	IslandMesh.reap(true)


## An island broke on impact: its bricks fly as half-brick pieces in their own colours; rubble
## that lay round the impact wakes; dust where it hit.
func _broke(key: int, pieces: Array[Dictionary], at: Vector3) -> void:
	var s: CarveSite = _sites[key]
	var d: CarveDebris = _debris[key]
	for piece: Dictionary in pieces:
		var size: Vector3 = piece["size"]
		var keep: Vector3 = piece["v"]
		var spread := Vector3(
			_rng.randf_range(-1, 1), _rng.randf_range(0, 1), _rng.randf_range(-1, 1)
		)
		var v := keep * Num.f(_cfg["piece_keep"]) + spread * Num.f(_cfg["piece_spread"])
		var motion := [v, spread * Num.f(_cfg["piece_spread"]), Num.f(_cfg["piece_gravity"])]
		motion.append(_mass(s, size))
		var start: Transform3D = piece["xf"]
		var xf := _lift(start, size)
		var color: Color = piece["color"]
		d.spawn(xf, size, color, motion)
	var reach := Vector3.ONE * Num.f(_cfg["break_depth"])
	d.wake(AABB(at - reach, reach * 2.0))
	_dust(at + Vector3.UP * 0.3, 0.5 + pieces.size() * 0.05)


func _carve_dust(key: int, box: AABB, removed: int) -> void:
	if _clock - Num.f(_dust_at.get(key, -INF)) < Num.f(_cfg["dust_interval"]):
		return
	_dust_at[key] = _clock
	_dust(box.get_center(), 0.5 + removed * Num.f(_cfg["dust_per_cell"]))


func _dust(at: Vector3, size: float) -> void:
	if fx != null:
		fx.dust(at, size)


## The sim's fall direction (Structure gives Vector2i, Collapse Vector2) as a Vector2.
static func _dir(raw: Variant) -> Vector2:
	if raw is Vector2i:
		var di: Vector2i = raw
		return Vector2(di)
	var d: Vector2 = raw
	return d


## A piece starting below the ground is raised onto it: a carve at the foot of a wall or an
## island that hit the street at speed would otherwise seat pieces in the road.
func _lift(xf: Transform3D, size: Vector3) -> Transform3D:
	var b := xf.basis.scaled_local(size)
	var low := xf.origin.y - 0.5 * (absf(b.x.y) + absf(b.y.y) + absf(b.z.y))
	var ground := Num.f(_cfg["ground_y"])
	if low < ground:
		xf.origin.y += ground - low
	return xf


func _spin() -> Vector3:
	return Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))


## A piece's mass grows with its volume in cells to the mass_power (under 1: a half-brick
## piece 64 times a cell's volume weighs 16 cells, so piles of mixed sizes do not crush the
## smallest into the road, a solver limit, not a look).
func _mass(s: CarveSite, size: Vector3) -> float:
	var cells := maxf(1.0, size.x * size.y * size.z * pow(s.res, 3))
	return Num.f(_cfg["cell_mass"]) * pow(cells, Num.f(_cfg["mass_power"]))


static func _box(s: CarveSite, cells: PackedInt32Array) -> AABB:
	var all := PackedInt32Array()
	all.resize(cells.size())
	for k: int in cells.size():
		all[k] = k
	return CarveMesh.span(s, cells, all)


## The cut's box grown a cell and stretched up to the building's top: what rests above a cut
## may have rested on it.
static func _above(s: CarveSite, box: AABB) -> AABB:
	var grown := box.grow(1.0 / s.res)
	grown.end = Vector3(grown.end.x, s.origin.y + float(s.size.y) / s.res + 1.0, grown.end.z)
	return grown
