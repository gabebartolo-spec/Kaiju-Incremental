extends RefCounted
## Render plan item 11 (D-311, tuning render_opt.island_merged) for tests/run_carve_debris_tests.gd.
## (a) A 300-brick IslandBody draws with at most 2 MeshInstance3D merged (300 per brick, the old
## path), and its boxes, added straight to the body's RID, are the old CollisionShape3D boxes in the
## same order, before and after every share of a staged break. (b) IslandMesh draws exactly the
## faces a fresh mesh of the cells left has: after each drop (the merged mesh less the hidden
## bricks' vertex ranges, plus the patch), after a remesh with a drop while it ran, and its ranges
## are each brick's own faces; after a last remesh its shades are a fresh mesh's too (between a drop
## and the remesh a face next to the hole may keep its old corner shade: the share is printed).
## Seeded by design (SEED); no clock.

const SEED := 20261027
const BRICKS := Vector3i(10, 6, 5)  # 300 bricks of RES cells a side
const RES := 2
const STEP := 0.05  # seconds per share of a staged break
const STRENGTH := 0.6  # AO strength for (b): not 0, so the corners are tested

var _check: Callable
var _tree: SceneTree


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


func run() -> void:
	await _bodies()
	_faces()


# ---- (a) the body: meshes and shapes, merged against the old path ----------------------------


func _bodies() -> void:
	var dims := BRICKS * RES
	var site := CarveSite.new(0, Vector3(3.0, 0.0, -2.0), dims, RES)
	var cells := PackedInt32Array()
	var mats := PackedByteArray()
	for i: int in site.count():
		cells.append(i)
		mats.append(1 + i % 5)
	var opt := Content.section("render_opt")
	var was: Variant = opt.get("island_merged", true)
	opt["island_merged"] = false
	var old := IslandBody.new(site, cells, mats, SEED)
	opt["island_merged"] = true
	var on := IslandBody.new(site, cells, mats, SEED)
	opt["island_merged"] = was
	var bricks := BRICKS.x * BRICKS.y * BRICKS.z
	var drawn := _meshes(on)
	_check.call(
		drawn <= 2 and _meshes(old) == bricks and on.merged and not old.merged,
		(
			"a %d-brick island draws with %d MeshInstance3D merged (per brick: %d)"
			% [bricks, drawn, _meshes(old)]
		)
	)
	_check.call(
		_shapes(on) == _shapes(old) and _shapes(on).size() == bricks,
		"its %d boxes on the body's RID are the per-brick CollisionShape3D boxes" % bricks
	)
	await _break_both(old, on)


## Drives one staged break on both bodies, share by share (frozen, off the physics clock).
func _break_both(old: IslandBody, on: IslandBody) -> void:
	for body: IslandBody in [old, on]:
		body.freeze = true
		body.settled_now = true  # its own _physics_process stays out of it
		_tree.root.add_child(body)
		body._start_break(Vector3(0.0, -12.0, 0.0))
	var shares := 0
	var same := true
	while not on._stage.is_empty() and shares < 100:
		shares += 1
		old._step_stage(STEP)
		on._step_stage(STEP)
		await _tree.process_frame  # the old path's shapes leave with their nodes
		same = same and _shapes(on) == _shapes(old) and on.cell_count() == old.cell_count()
	var left := on.cell_count()
	_check.call(
		shares > 2 and same and old._stage.is_empty() and left > 0 and left < old.cells.size(),
		(
			"over %d shares of a staged break the RID boxes stay the old ones (%d cells left)"
			% [shares, left]
		)
	)
	_check.call(_meshes(on) <= 2, "the broken island still draws with at most 2 MeshInstance3D")
	old.queue_free()
	on.queue_free()
	await _tree.process_frame
	IslandMesh.reap(true)  # the remesh the break's end started


func _meshes(body: Node) -> int:
	return body.find_children("*", "MeshInstance3D", true, false).size()


## The body's shapes on the physics server: [transform, box half extents] each, in order.
func _shapes(body: IslandBody) -> Array:
	var out := []
	var rid := body.get_rid()
	for i: int in PhysicsServer3D.body_get_shape_count(rid):
		var data: Variant = PhysicsServer3D.shape_get_data(PhysicsServer3D.body_get_shape(rid, i))
		out.append([PhysicsServer3D.body_get_shape_transform(rid, i), data])
	return out


# ---- (b) IslandMesh: the faces drawn are a fresh mesh's ---------------------------------------


func _faces() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var site := CarveSite.new(1, Vector3(-4.0, 1.0, 6.0), Vector3i(16, 12, 12), 4)
	var src := _island(site, rng)
	var cells: PackedInt32Array = src[0]
	var bricks := CarveMesh.bricks(site, cells)
	var offset := Vector3(1.5, 4.0, -0.5)
	var frame := [offset, STRENGTH]
	var view := IslandMesh.new(site, STRENGTH)
	view.build_now(src, bricks, offset)
	var shown: Array = IslandMesh.build(site, src, bricks, frame)
	var ctx := [site, src, bricks, frame]
	_check.call(_ranges_are_bricks(ctx, shown), "each brick's range is its own faces")
	var order: Array = bricks.keys()
	for i: int in range(order.size() - 1, 0, -1):  # a seeded shuffle
		var j := rng.randi_range(0, i)
		var swap: Variant = order[i]
		order[i] = order[j]
		order[j] = swap
	var off: Array[int] = []
	var rounds := 0
	var stale := 0.0  # the largest share of faces drawn with an old shade
	while order.size() > 6:
		rounds += 1
		_drop(order, rng.randi_range(1, 3), [src, bricks, offset], view)
		var d := _diff(view, shown, ctx)
		if d.x != 0:
			off.append(rounds)
		stale = maxf(stale, float(d.y) / maxi(1, d.z))
		if rounds == 3:  # a remesh, a drop while it runs, then its swap
			view.remesh(src, bricks, offset)
			var now: PackedByteArray = src[2]
			var copy := [cells, src[1], now.duplicate()]
			var copied := IslandMesh.build(site, copy, bricks.duplicate(), frame)
			_drop(order, 2, [src, bricks, offset], view)
			view.finish()
			shown = copied
			if _diff(view, shown, ctx).x != 0:
				off.append(-rounds)
	_check.call(
		rounds > 5 and off.is_empty(),
		(
			(
				"after each of %d drops and a remesh the drawn faces are a fresh mesh's (off: %s;"
				+ " an old corner shade on at most %.1f%% of faces until the remesh)"
			)
			% [rounds, off, stale * 100.0]
		)
	)
	view.remesh(src, bricks, offset)
	view.finish()
	var last := _diff(view, IslandMesh.build(site, src, bricks, frame), ctx)
	_check.call(
		last == Vector3i(0, 0, last.z) and last.z > 0,
		"after the last remesh every face and shade is a fresh mesh's (%d faces)" % last.z
	)
	view.free()


## Drops `n` bricks from the front of `order` as IslandBody does (cells cleared, then dropped()).
func _drop(order: Array, n: int, state: Array, view: IslandMesh) -> void:
	var src: Array = state[0]
	var bricks: Dictionary = state[1]
	var offset: Vector3 = state[2]
	var cells: PackedInt32Array = src[0]
	var solid: PackedByteArray = src[2]
	var lists := {}
	for _i: int in n:
		var key: Vector3i = order.pop_front()
		var ks: PackedInt32Array = bricks[key]
		lists[key] = ks
		for k: int in ks:
			solid[cells[k]] = 0
		bricks.erase(key)
	src[2] = solid
	view.dropped(lists, src, bricks, offset)


## What `view` draws (`shown`'s faces in its ranges, plus its patch) against a fresh mesh, `ctx`
## [site, src, bricks, frame]: Vector3i(faces placed differently, faces shaded differently, faces).
func _diff(view: IslandMesh, shown: Array, ctx: Array) -> Vector3i:
	var site: CarveSite = ctx[0]
	var src: Array = ctx[1]
	var bricks: Dictionary = ctx[2]
	var frame: Array = ctx[3]
	var fresh: Array = IslandMesh.build(site, src, bricks, frame)
	var faces: CarveMesh.Faces = shown[0]
	var drawn := {}
	var ranges := view.ranges()
	for key: Vector3i in ranges:
		var span: Vector2i = ranges[key]
		_count(faces, span, site.res, drawn)
	var patch := view.patch_faces()
	_count(patch, Vector2i(0, patch.verts.size()), site.res, drawn)
	var want := {}
	var all: CarveMesh.Faces = fresh[0]
	_count(all, Vector2i(0, all.verts.size()), site.res, want)
	var placed := 0
	var shaded := 0
	for key: Array in want:
		var a: Array = want[key]
		var b: Array = drawn.get(key, [])
		if a.size() != b.size():
			placed += 1
		elif a != b:
			shaded += 1
	for key: Array in drawn:
		placed += 0 if want.has(key) else 1
	return Vector3i(placed, shaded, want.size())


## Lists the faces (6 vertices each) of `span` (first vertex, count) of `faces` into `out`, keyed
## by [lowest corner in half-cells, normal]: each face's 6 vertex colours.
func _count(faces: CarveMesh.Faces, span: Vector2i, res: int, out: Dictionary) -> void:
	for v: int in range(span.x, span.x + span.y, 6):
		var lo := faces.verts[v]
		for j: int in range(1, 6):
			lo = lo.min(faces.verts[v + j])
		var key := [Vector3i((lo * res * 2.0).round()), Vector3i(faces.normals[v].round())]
		var list: Array = out.get(key, [])
		list.append(faces.colors.slice(v, v + 6))
		out[key] = list


## Whether each brick's range in `built` holds exactly that brick's faces, meshed alone.
func _ranges_are_bricks(ctx: Array, built: Array) -> bool:
	var site: CarveSite = ctx[0]
	var src: Array = ctx[1]
	var bricks: Dictionary = ctx[2]
	var frame: Array = ctx[3]
	var offset: Vector3 = frame[0]
	var solid: PackedByteArray = src[2]
	var cells: PackedInt32Array = src[0]
	var mats: PackedByteArray = src[1]
	var faces: CarveMesh.Faces = built[0]
	var ranges: Dictionary = built[1]
	var total := 0
	for key: Vector3i in bricks:
		var span: Vector2i = ranges[key]
		var own := CarveMesh.Faces.new(site, solid, STRENGTH)
		var ks: PackedInt32Array = bricks[key]
		var idx := PackedInt32Array()
		var m := PackedByteArray()
		for k: int in ks:
			idx.append(cells[k])
			m.append(mats[k])
		CarveMesh.add_cells(own, idx, m, offset)
		if own.verts != faces.verts.slice(span.x, span.x + span.y):
			return false
		total += span.y
	return total == faces.verts.size() and total > 0


## A seeded island: a hollow block with floors and holes, so bricks are partial and touch.
func _island(site: CarveSite, rng: RandomNumberGenerator) -> Array:
	var cells := PackedInt32Array()
	var mats := PackedByteArray()
	var solid := PackedByteArray()
	solid.resize(site.count())
	for i: int in site.count():
		var c := site.cell(i)
		var edge := c.x == 0 or c.z == 0 or c.x == site.size.x - 1 or c.z == site.size.z - 1
		if (edge or c.y % 3 == 0 or (c.x + c.z) % 5 == 0) and rng.randf() > 0.15:
			cells.append(i)
			mats.append(rng.randi_range(1, 6))
			solid[i] = 1
	return [cells, mats, solid]
