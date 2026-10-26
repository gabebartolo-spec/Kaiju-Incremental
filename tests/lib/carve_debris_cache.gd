extends RefCounted
## Render plan item 1 (tuning render_opt.debris_cache) for tests/run_carve_debris_tests.gd: two
## CarveDebris in two separate physics worlds get the same throw, one with the cache off (the old
## per-frame reads) and one on. Over 600 physics ticks (a) the live MultiMesh buffers are byte-
## identical every frame, (b) the rubble buffers are byte-identical until the first piece is
## removed and the same set of pieces after it (removal now swaps with the last piece, so the order
## differs by design), (c) the cached one reads the physics server at most 3 times per live piece
## per tick while the old one reads more, (d) every drawn piece, live or rubble, lies inside the
## MultiMesh's hand-set bounds, including one thrown 60 m clear of the building.
## Seeded by design: the throw is drawn from a RandomNumberGenerator with a fixed seed.

const TICKS := 600
const PIECES := 90
const SEED := 20261026

var _check: Callable
var _tree: SceneTree


class Rig:
	extends RefCounted
	var view: SubViewport
	var debris: CarveDebris
	var ground: RID
	var box: BoxShape3D


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func run() -> void:
	var off := _rig(false)
	var on := _rig(true)
	await _tree.process_frame
	_throw(off.debris)
	_throw(on.debris)
	# Slower than the physics rate, so every frame follows at least one tick: the old per-frame draw
	# lifts a pressed-in piece again on a frame with no tick (another rounding of its pose), which
	# makes its result depend on the frame schedule.
	var fps_before := Engine.max_fps
	Engine.max_fps = 30
	var start := Engine.get_physics_frames()
	var last := start
	var strict_rubble := true
	var live_equal := true
	var rubble_equal := true
	var counts_equal := true
	var inside := true
	var piece_ticks := 0
	var reads_on := 0
	var reads_off := 0
	var guard := 0
	while Engine.get_physics_frames() - start < TICKS and guard < 2000:
		guard += 1
		var before: int = on.debris.bodies()
		var r0 := on.debris.state_reads
		var o0 := off.debris.state_reads
		await _tree.process_frame
		piece_ticks += (Engine.get_physics_frames() - last) * before
		last = Engine.get_physics_frames()
		reads_on += on.debris.state_reads - r0
		reads_off += off.debris.state_reads - o0
		counts_equal = counts_equal and _same_counts(off.debris, on.debris)
		live_equal = live_equal and _same_live(off.debris, on.debris)
		if on.debris._rubble.removes > 0:
			strict_rubble = false
		var same := _same_rubble(off.debris, on.debris, strict_rubble)
		rubble_equal = rubble_equal and same
		inside = inside and _inside_bounds(on.debris)
	Engine.max_fps = fps_before
	var rubble: int = on.debris.rubble()
	_check.call(guard < 2000, "the 600-tick run finished (took %d frames)" % guard)
	_check.call(counts_equal, "live, rubble and fading counts match with the cache off and on")
	_check.call(live_equal, "the live MultiMesh buffer is byte-identical every frame")
	_check.call(rubble_equal, "the rubble buffer matches (byte-identical until the first removal)")
	_check.call(rubble > 5, "the throw settled into rubble to compare (%d pieces)" % rubble)
	_check.call(
		on.debris._rubble.removes > 0, "the run removed rubble, so the swap path was compared"
	)
	_check.call(inside, "every drawn piece is inside its MultiMesh's custom bounds")
	_check.call(
		(
			on.debris._view.mm.custom_aabb.size.x > 0.0
			and off.debris._view.mm.custom_aabb.size.x == 0.0
		),
		"the cached MultiMesh has bounds set, the old one has none"
	)
	_check.call(
		reads_on <= 3 * piece_ticks,
		(
			"state reads %d are at most 3 per live piece per tick (%d piece-ticks)"
			% [reads_on, piece_ticks]
		)
	)
	_check.call(
		reads_off > 3 * piece_ticks,
		(
			"the counter tells them apart: the old path made %d reads over the same piece-ticks"
			% reads_off
		)
	)
	for rig: Rig in [off, on]:
		PhysicsServer3D.free_rid(rig.ground)
		rig.view.queue_free()
	await _tree.process_frame


func _rig(opt: bool) -> Rig:
	var rig := Rig.new()
	rig.view = SubViewport.new()
	rig.view.own_world_3d = true
	rig.view.size = Vector2i(64, 64)
	_tree.root.add_child(rig.view)
	var space := rig.view.find_world_3d().space
	var ground := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(ground, PhysicsServer3D.BODY_MODE_STATIC)
	var box := BoxShape3D.new()
	box.size = Vector3(600, 2, 600)
	PhysicsServer3D.body_add_shape(ground, box.get_rid())
	PhysicsServer3D.body_set_space(ground, space)
	PhysicsServer3D.body_set_state(
		ground, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(), Vector3(0, -1, 0))
	)
	rig.debris = CarveDebris.new()
	rig.debris.opt = opt
	rig.debris._cfg = rig.debris._cfg.duplicate()
	rig.debris._cfg["rubble_cap"] = 30  # so the cap, the fade and the removal all happen
	rig.debris.site = CarveSite.new(1, Vector3(-10, 0, -10), Vector3i(20, 30, 20), 1)
	rig.debris.grid = PackedByteArray()
	rig.view.add_child(rig.debris)
	rig.ground = ground
	rig.box = box
	return rig


## The same throw for both: a burst out of the building, one piece flung 60 m clear.
func _throw(debris: CarveDebris) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var cfg: Dictionary = debris._cfg
	for i: int in PIECES:
		var at := Vector3(rng.randf_range(-6, 6), rng.randf_range(2, 14), rng.randf_range(-6, 6))
		var v := Vector3(rng.randf_range(-9, 9), rng.randf_range(0, 8), rng.randf_range(-9, 9))
		var spin := Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		var size := Vector3.ONE * (1.0 if i % 4 else 2.0)
		var motion := [v, spin, Num.f(cfg["piece_gravity"]), 1.0]
		debris.spawn(Transform3D(Basis(), at), size, Color(0.5, 0.4, 0.3), motion)
	var far := [Vector3(30, 4, 0), Vector3.ZERO, 1.0, 1.0]
	debris.spawn(Transform3D(Basis(), Vector3(60, 6, 0)), Vector3.ONE, Color.WHITE, far)


func _same_counts(a: CarveDebris, b: CarveDebris) -> bool:
	return a.bodies() == b.bodies() and a.live() == b.live() and a.rubble() == b.rubble()


func _same_live(a: CarveDebris, b: CarveDebris) -> bool:
	var n := a._rids.size() * CarveRubble.FLOATS
	if a._view.mm.visible_instance_count != b._view.mm.visible_instance_count:
		return false
	return a._view.mm.buffer.slice(0, n) == b._view.mm.buffer.slice(0, n)


func _same_rubble(a: CarveDebris, b: CarveDebris, strict: bool) -> bool:
	if a.rubble() != b.rubble():
		return false
	var n := a.rubble() * CarveRubble.FLOATS
	if n == 0:
		return true
	if a._rubble.mm.visible_instance_count != b._rubble.mm.visible_instance_count:
		return false
	var x := a._rubble.mm.buffer.slice(0, n)
	var y := b._rubble.mm.buffer.slice(0, n)
	if strict:
		return x == y
	return _records(x) == _records(y)


## A buffer as its sorted 16-float records, so two orders of the same pieces compare equal.
func _records(buf: PackedFloat32Array) -> PackedStringArray:
	var out := PackedStringArray()
	for o: int in range(0, buf.size(), CarveRubble.FLOATS):
		out.append(buf.slice(o, o + CarveRubble.FLOATS).to_byte_array().hex_encode())
	out.sort()
	return out


func _inside_bounds(d: CarveDebris) -> bool:
	return (
		_all_inside(d._view.mm, d._view.mm.buffer, d._rids.size())
		and _all_inside(d._rubble.mm, d._rubble.mm.buffer, d.rubble())
	)


func _all_inside(mm: MultiMesh, buf: PackedFloat32Array, _n: int) -> bool:
	var n := mini(mm.visible_instance_count, buf.size() / CarveRubble.FLOATS)
	for k: int in n:
		var o := k * CarveRubble.FLOATS
		if not mm.custom_aabb.has_point(Vector3(buf[o + 3], buf[o + 7], buf[o + 11])):
			return false
	return true
