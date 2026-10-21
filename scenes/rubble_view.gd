class_name RubbleView
extends RefCounted
## Draws the sim's slabs (RubbleSlabs, D-110): each is a chunk of its building's rubble voxels
## (Ruin.chunk, built on a worker) that slides to rest where the sim put it, tilted and half
## sunk. When the sim breaks one ("slab_break"), it does not vanish (comments #25): its pieces
## are knocked out of it and tumble to where the sim put them, gravel sprays off the side that
## was hit, a small puff of dust, and the slab itself goes only once its pieces are in the
## world (a slab that breaks into gravel alone crumbles down over crumble_s). Cosmetic; every
## position and size is the sim's. Tuning: data/tuning.json "topple_fx". Part of CityView.

var _city: CityView
var _cfg: Dictionary
var _nodes: Dictionary = {}  # slab id -> MultiMeshInstance3D once built
var _waiting: Dictionary = {}  # slab id -> its slab_break event, broken before it was built
var _hidden: Dictionary = {}  # slab id -> true while it waits for a fold to end (reveal())
var _held: Dictionary = {}  # slab id -> true while its move waits for reveal()
var _tweens: Dictionary = {}  # slab id -> its paused move tween, once built
var _parent: Dictionary = {}  # piece id -> the broken slab it replaces once it is out
var _rng: RandomNumberGenerator


func _init(city: CityView, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	_city = city
	_cfg = cfg
	_rng = rng


## Builds and places the sim's slab dicts. `sliding`: they slide in from "from" (a landing
## strip); else they are knocked out of a breaking slab or fold and tumble there over piece_s.
## `hidden`: they stay out of sight until reveal() (a fold still on its way down). `held`
## (with hidden): their move waits too, so reveal() breaks them out of their band (the tween
## runs from the reveal, not from when the chunk was built).
func add(
	slabs: Array, voxels: BuildingVoxels, sliding: bool, hidden := false, held := false
) -> void:
	for slab: Dictionary in slabs:
		var id := Num.i(slab["id"])
		var dims: Vector3 = slab["dims"]
		var salt := id % Ruin.SALTS
		if hidden:
			_hidden[id] = true
		if held:
			_held[id] = true
		var place := func(chunk: MultiMeshInstance3D) -> void: _place(chunk, slab, sliding)
		_city.ruins().build(
			func() -> MultiMeshInstance3D: return Ruin.chunk(voxels, dims, salt), place
		)


## Shows slabs add() kept hidden (their fold reached the ground), each from where it lies.
func reveal(ids: Array) -> void:
	for raw: Variant in ids:
		var id := Num.i(raw)
		_hidden.erase(id)
		_held.erase(id)
		var node: MultiMeshInstance3D = _nodes.get(id)
		if node != null:
			node.visible = true
		var move: Tween = _tweens.get(id)
		if move != null and move.is_valid():
			move.play()
		_tweens.erase(id)
		if node != null and _waiting.has(id):  # broken while it was still coming down: seen
			var event: Dictionary = _waiting[id]  # lying there for reveal_hold_s, then it breaks
			_waiting.erase(id)
			var tween := node.create_tween()
			tween.tween_interval(Num.f(_cfg["reveal_hold_s"]))
			tween.tween_callback(func() -> void: smash(event, null))


func _rest(slab: Dictionary) -> Transform3D:
	return rest_pose(slab, _cfg)


## The slab's rest pose (cfg: the "topple_fx" tuning): its yaw, a tilt of its own (seeded by its
## id), sunk slab_sit into what it rests on but never below the street (comment #26).
static func rest_pose(slab: Dictionary, cfg: Dictionary) -> Transform3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["slab", Num.i(slab["id"])])
	var tilt := Num.f(cfg["slab_tilt"])
	var turn := Vector3(
		rng.randf_range(-tilt, tilt), Num.f(slab["yaw"]), rng.randf_range(-tilt, tilt)
	)
	var dims: Vector3 = slab["dims"]
	var pos: Vector2 = slab["pos"]
	var basis := Basis.from_euler(turn)
	var y := Num.f(slab["base"]) + dims.y * Num.f(cfg["slab_sit"])
	var low := span_y(Transform3D(basis, Vector3(0, y, 0)), dims).x
	return Transform3D(basis, Vector3(pos.x, y - minf(low, 0.0), pos.y))


## The lowest and highest world heights (x, y) of a box of `dims` centred on xf's origin.
static func span_y(xf: Transform3D, dims: Vector3) -> Vector2:
	var b := xf.basis
	var half := absf(b.x.y) * dims.x * 0.5 + absf(b.y.y) * dims.y * 0.5 + absf(b.z.y) * dims.z * 0.5
	return Vector2(xf.origin.y - half, xf.origin.y + half)


## Where a slab that breaks into gravel alone ends its crumble (cfg: "topple_fx"): squashed to
## crumble_flat of its height where it lies, its bottom kept on what it rests on (comment #26).
static func crumbled(xf: Transform3D, dims: Vector3, cfg: Dictionary) -> Transform3D:
	var low := span_y(xf, dims).x
	var squashed := xf.basis * Basis.from_scale(Vector3(1.0, Num.f(cfg["crumble_flat"]), 1.0))
	var lift := low - span_y(Transform3D(squashed, xf.origin), dims).x
	return Transform3D(squashed, xf.origin + Vector3(0, lift, 0))


func _place(chunk: MultiMeshInstance3D, slab: Dictionary, sliding: bool) -> void:
	var id := Num.i(slab["id"])
	_nodes[id] = chunk
	chunk.visible = not _hidden.has(id)
	var rest := _rest(slab)
	var from: Vector2 = slab["from"]
	var dims: Vector3 = slab["dims"]
	var lift := dims.x if sliding else dims.y + Num.f(_cfg["piece_lift"])
	chunk.position = Vector3(from.x, rest.origin.y + lift, from.y)
	var start := rest.basis.get_euler()
	var spin := Num.f(_cfg["piece_spin"])
	if not sliding:  # knocked out: it tumbles over as it goes
		start += Vector3(spin, 0.0, -spin) * (1.0 if id % 2 == 0 else -1.0)
	else:
		start = Vector3(start.x / 0.3, start.y, start.z / 0.3)  # flattens as it settles
	chunk.rotation = start
	var seconds := Num.f(_cfg["settle_s"]) if sliding else Num.f(_cfg["piece_s"])
	var tween := chunk.create_tween()
	if _held.has(id):
		tween.pause()
		_tweens[id] = tween
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(chunk, "position", rest.origin, seconds)
	tween.parallel().tween_property(chunk, "rotation", rest.basis.get_euler(), seconds)
	var broke: MultiMeshInstance3D = _parent.get(id)
	_parent.erase(id)
	if broke != null and is_instance_valid(broke) and not broke.has_meta("going"):
		broke.set_meta("going", true)  # its first piece is out: it goes now, a beat later
		var out := broke.create_tween()
		out.tween_interval(Num.f(_cfg["piece_hold"]))
		out.tween_property(broke, "scale", Vector3.ONE * 0.6, Num.f(_cfg["crumble_s"]) * 0.5)
		out.tween_callback(broke.queue_free)
	if _waiting.has(id):
		var event: Dictionary = _waiting[id]
		_waiting.erase(id)
		tween.tween_callback(func() -> void: smash(event, null))


## The sim broke a slab: its pieces are knocked out (they replace it once built), gravel
## sprays out along the push, a puff of dust; with no pieces it crumbles down over crumble_s.
## voxels: its building's (null: the pieces' look comes from the event's earlier add()).
func smash(event: Dictionary, voxels: BuildingVoxels) -> void:
	var id := Num.i(event["id"])
	var node: MultiMeshInstance3D = _nodes.get(id)
	if node == null or not is_instance_valid(node) or _hidden.has(id):
		_waiting[id] = event  # still building: it breaks once placed
		if voxels != null and not event.has("voxels"):
			event["voxels"] = voxels
		return
	_nodes.erase(id)
	var look := voxels
	if look == null and event.has("voxels"):
		look = event["voxels"]
	var pieces: Array = event["pieces"]
	var at := node.global_position
	var push: Vector2 = event["push"]
	var away := Vector3(push.x, Num.f(_cfg["gravel_up"]), push.y)
	var color := Color(str(_cfg["rubble_tint"]))
	for n: int in Num.i(event["gravel"]):
		var aabb := node.get_aabb()
		var k := Vector3(_rng.randf(), _rng.randf(), _rng.randf())
		var local := aabb.position + aabb.size * k
		_city.debris(node.global_transform * local, color, away)
	_city.fx.dust(at, Num.f(_cfg["gravel_dust"]) * (0.5 + node.get_aabb().size.x * 0.25))
	if pieces.is_empty() or look == null:
		_crumble(node)
		return
	# The slab stays until its first piece is out of it (built on a worker), then goes a beat
	# later: the overlap reads as a crack, never a gap.
	for piece: Dictionary in pieces:
		_parent[Num.i(piece["id"])] = node
	add(pieces, look, false)


## Crumbles a slab down where it lies (crumbled) over crumble_s, then frees it.
func _crumble(node: MultiMeshInstance3D) -> void:
	var seconds := Num.f(_cfg["crumble_s"])
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	var end := crumbled(node.transform, node.get_aabb().size, _cfg)
	tween.tween_property(node, "transform", end, seconds)
	tween.tween_callback(node.queue_free)
