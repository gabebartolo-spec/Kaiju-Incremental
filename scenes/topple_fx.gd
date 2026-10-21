class_name ToppleFx
extends Node3D
## A toppling tower's weight (PR #89 motion review), inside the sim's fall time so nothing lags
## the sim: its base shudders and crumbles, it leans slowly, then gravity takes it; on landing the
## slab breaks up over a few frames (debris in waves, a burst of pale dust at the far end) instead
## of swapping to rubble at once, the sim's slabs slide to rest (RubbleView) and the heap slumps
## down into place. A tower that broke on the kaiju (the sim's "hit", comments #24 #25) cracks
## at the contact: the part below comes down in front of him, the part above folds over him and
## slides off his side, the impact edge crumbles. Every timing and size is the "topple_fx"
## tuning. Presentation only. Part of CityView.

var _city: CityView
var _cfg: Dictionary
var _rng: RandomNumberGenerator
var _breaking: Array[Dictionary] = []
var _rubble: RubbleView


func _init(city: CityView, rng: RandomNumberGenerator) -> void:
	_city = city
	_rng = rng
	_cfg = Content.section("topple_fx")
	_rubble = RubbleView.new(city, _cfg, rng)


## The piece's tilt (radians) t seconds into a fall the sim times at `duration` (the sim's own
## curve, FallContact.tilt, so where the sim says a tower met the kaiju is where it is drawn).
static func tilt(cfg: Dictionary, t: float, duration: float) -> float:
	return FallContact.tilt(cfg, t, duration)


## Poses a falling topple (CityView's fall record) for this frame; its base crumbles while it
## shudders.
func pose(f: Dictionary, delta: float) -> void:
	var node: Node3D = f["node"]
	var t := Num.f(f["t"])
	var duration := Num.f(f["duration"])
	var dir: Vector2 = f["dir"]
	node.basis = FallMotion.topple_turn(dir, tilt(_cfg, t, duration))
	var shudder := minf(Num.f(_cfg["shudder_s"]), duration * Num.f(_cfg["shudder_max_share"]))
	if t > shudder or not node.has_meta("pivot"):  # a landmark's burst crumbles on its own
		return
	var due := Num.f(f.get("crumble", 0.0)) - delta
	if due > 0.0:
		f["crumble"] = due
		return
	f["crumble"] = due + Num.f(_cfg["crumble_every"])
	var base: Array = node.get_meta("base_parts", [])
	if base.is_empty():
		var pivot: Vector3 = node.get_meta("pivot")
		for part: Dictionary in node.get_meta("parts", []):
			var pos: Vector3 = part["pos"]
			if pos.y < pivot.y + Num.f(_cfg["crumble_floors"]):
				base.append(part)
		node.set_meta("base_parts", base)
	if base.is_empty():
		return
	for n: int in Num.i(_cfg["crumble_debris"]):
		var part: Dictionary = base[_rng.randi_range(0, base.size() - 1)]
		var pos: Vector3 = part["pos"]
		var color: Color = part["color"]
		_city.debris(pos, color, Vector3.UP * 0.3)
	var at: Dictionary = base[_rng.randi_range(0, base.size() - 1)]
	var puff: Vector3 = at["pos"]
	_city.fx.dust(puff, Num.f(_cfg["crumble_dust"]))


## A topple landed (the sim's fall_land): the slab breaks up over breakup_s instead of vanishing,
## pale dust bursts at the far end and along the strip, and the heap built off-thread slumps
## into place with a few big chunks sliding to rest on it.
## fall: CityView's fall record (its "t", "dir", "cells"); view: the building's.
func land(node: Node3D, event: Dictionary, view: BuildingView, fall: Dictionary) -> void:
	var voxels := view.voxels
	var from: Vector2 = event["from"]
	var to: Vector2 = event["to"]
	var width := Num.f(event["width"])
	var a := Vector3(from.x, 0, from.y)
	var b := Vector3(to.x, 0, to.y)
	var lift := Vector3(0, Num.f(_cfg["dust_lift"]), 0)
	var dust := Color(str(_cfg["dust_color"]))
	var impact := Num.f(_cfg["contact_dust" if event.has("hit") else "impact_dust"])
	_city.fx.dust(b + lift, impact, dust)  # on the kaiju: only a puff where it met him
	_city.fx.dust(a.lerp(b, 0.6) + lift, impact * 0.7, dust)
	_city.fx.dust_line(a, b, width, dust)
	if event.has("hit"):
		_fold(node, event, view, fall)
	else:
		_break_up(node, Num.f(_cfg["breakup_s"]), Num.f(_cfg["impact_debris"]))
	var cfg := _cfg
	var settle := func(mmi: MultiMeshInstance3D) -> void: _settle(mmi)
	_city.ruins().build(
		func() -> MultiMeshInstance3D: return Ruin.strip(voxels, a, b, width, cfg), settle
	)
	var slabs: Array = event.get("slabs", [])
	_rubble.add(slabs, voxels, true)


## The sim broke a slab (RubbleSlabs): RubbleView shows it.
func slab_break(event: Dictionary, voxels: BuildingVoxels) -> void:
	_rubble.smash(event, voxels)


## A tower broke on the kaiju: it cracks at the contact (hit "crack", up its own axis). Below the
## crack it keeps turning and comes down in front of him over fold_lower_s, then breaks up; above
## it the tower folds on over the contact (hinged there) while it slides off his side and drops,
## over fold_s, and breaks up where the sim's fold slabs lie, which show then. The contact edge
## sheds edge_debris at once, a puff of dust there, and the small edge slabs tumble out.
func _fold(node: Node3D, event: Dictionary, view: BuildingView, fall: Dictionary) -> void:
	var hit: Dictionary = event["hit"]
	var crack := Num.f(hit["crack"])
	var at: Vector3 = hit["at"]
	var side: Vector2 = hit["side"]
	var dir: Vector2 = fall["dir"]
	var lean := tilt(_cfg, Num.f(fall["t"]), Num.f(fall["duration"]))
	var pivot: Vector3 = node.get_meta("pivot")
	var cells: Array[Vector3i] = fall["cells"]
	var upper: Array[Vector3i] = []
	for c: Vector3i in cells:
		if c.y + 0.5 - pivot.y >= crack:
			upper.append(c)
	_edge(node, crack, hit)
	var lower := node
	var top: Node3D = null
	if upper.size() == cells.size():
		top = node
		lower = null
	elif not upper.is_empty():
		top = view.split_piece(node, upper, crack)
		node.get_parent().add_child(top)
		top.global_transform = node.global_transform
	if lower != null:
		var turn := func(a: float) -> void: lower.basis = FallMotion.topple_turn(dir, a)
		var tween := lower.create_tween()
		tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_method(turn, lean, PI * 0.5, Num.f(_cfg["fold_lower_s"]))
		var lower_debris := (
			Num.f(_cfg["impact_debris"]) * (1.0 - float(upper.size()) / cells.size())
		)
		var down := func() -> void: _break_up(lower, Num.f(_cfg["breakup_s"]), lower_debris)
		tween.tween_callback(down)
	var pieces: Array = hit["pieces"]
	var large := Num.i(hit["large"])
	var voxels := view.voxels
	_rubble.add(pieces.slice(large), voxels, false)
	_rubble.add(pieces.slice(0, large), voxels, false, true)
	if top == null:
		return
	var ids: Array = []
	var clear := 0.0
	for slab: Dictionary in pieces.slice(0, large):
		ids.append(slab["id"])
		var p: Vector2 = slab["pos"]
		clear = maxf(clear, (p - Vector2(at.x, at.z)).dot(side))
	var fold := {"at": at, "dir": dir, "side": side, "turn": PI * 0.5 - lean, "clear": clear}
	fold["ids"] = ids
	_hinge(top, fold)


## Hinges the part above the crack at the contact (fold "at") and folds it: it turns on by
## "turn" plus fold_over_deg (gravity's ease) about the fall "dir"'s axis, slides "clear" off
## his "side" and drops to the street over fold_s; then it breaks up and the fold slabs "ids"
## show.
func _hinge(top: Node3D, fold_at: Dictionary) -> void:
	var at: Vector3 = fold_at["at"]
	var dir: Vector2 = fold_at["dir"]
	var side: Vector2 = fold_at["side"]
	var ids: Array = fold_at["ids"]
	var hinge := Node3D.new()
	_city.add_child(hinge)
	hinge.global_position = at
	var xf := top.global_transform
	top.get_parent().remove_child(top)
	hinge.add_child(top)
	top.global_transform = xf
	var axis := Vector3(dir.y, 0, -dir.x)
	axis = FallMotion.STILL_AXIS if axis.is_zero_approx() else axis.normalized()
	var total := Num.f(fold_at["turn"]) + deg_to_rad(Num.f(_cfg["fold_over_deg"]))
	var slide := Vector3(side.x, 0, side.y) * Num.f(fold_at["clear"])
	var drop := at.y - Num.f(_cfg["fold_ground"])
	var fold := func(k: float) -> void:
		var g := k * k
		var spin := lerpf(k, g, Num.f(_cfg["fold_gravity"]))  # it keeps the speed it fell at
		hinge.transform = Transform3D(
			Basis(axis, total * spin), at + slide * k + Vector3.DOWN * drop * g
		)
	var seconds := Num.f(_cfg["fold_s"])
	var tween := hinge.create_tween()
	tween.tween_method(fold, 0.0, 1.0, seconds)
	var land := func() -> void:
		_break_up(top, Num.f(_cfg["breakup_s"]), Num.f(_cfg["fold_debris"]))
		_city.fx.dust(top.global_position, Num.f(_cfg["contact_dust"]))
		_rubble.reveal(ids)
	tween.tween_callback(land)
	tween.tween_interval(Num.f(_cfg["breakup_s"]) + 0.1)
	tween.tween_callback(hinge.queue_free)


## The impact edge: debris from the piece's parts near the crack, thrown off his side (hit
## "side"), and a puff of dust where it met him (hit "at").
func _edge(node: Node3D, crack: float, hit: Dictionary) -> void:
	var pivot: Vector3 = node.get_meta("pivot")
	var at: Vector3 = hit["at"]
	var side: Vector2 = hit["side"]
	var near: Array = []
	for part: Dictionary in node.get_meta("parts", []):
		var pos: Vector3 = part["pos"]
		if absf(pos.y - pivot.y - crack) < Num.f(_cfg["edge_band"]):
			near.append(part)
	var away := Vector3(side.x, Num.f(_cfg["gravel_up"]), side.y)
	if not near.is_empty():
		for n: int in Num.i(_cfg["edge_debris"]):
			var part: Dictionary = near[_rng.randi_range(0, near.size() - 1)]
			var pos: Vector3 = part["pos"]
			var color: Color = part["color"]
			_city.debris(node.global_transform * (pos - pivot), color, away)
	_city.fx.dust(at, Num.f(_cfg["contact_dust"]))


## A dropped part landed (the sim's fall_land): it crumbles down into the street over
## drop_crumble_s with debris in waves instead of vanishing on the landing frame (PR #89 review,
## capture 39277970463 frames 505-506).
func crumble(node: Node3D) -> void:
	_break_up(node, Num.f(_cfg["drop_crumble_s"]), Num.f(_cfg["drop_crumble_debris"]))


func _break_up(node: Node3D, span: float, debris: float) -> void:
	_breaking.append(
		{"node": node, "t": 0.0, "basis": node.global_transform, "span": span, "debris": debris}
	)


func _process(delta: float) -> void:
	for i: int in range(_breaking.size() - 1, -1, -1):
		var br: Dictionary = _breaking[i]
		var node: Node3D = br["node"]
		var span := Num.f(br["span"])
		var per_s := Num.f(br["debris"]) / span
		br["t"] = Num.f(br["t"]) + delta
		var k := clampf(Num.f(br["t"]) / span, 0.0, 1.0)
		if not is_instance_valid(node) or k >= 1.0:
			if is_instance_valid(node):
				node.queue_free()
			_breaking.remove_at(i)
			continue
		# The slab crushes flat into the street (world Y squashed towards the ground).
		var flat := lerpf(1.0, Num.f(_cfg["breakup_flatten"]), k)
		var rest: Transform3D = br["basis"]
		node.global_transform = (
			Transform3D(Basis.from_scale(Vector3(1, flat, 1)), Vector3.ZERO) * rest
		)
		var parts: Array = node.get_meta("parts", [])
		if parts.is_empty():
			continue
		var pivot: Vector3 = node.get_meta("pivot")
		for n: int in roundi(per_s * delta):
			var part: Dictionary = parts[_rng.randi_range(0, parts.size() - 1)]
			var pos: Vector3 = part["pos"]
			var color: Color = part["color"]
			_city.debris(rest * (pos - pivot), color, Vector3.UP)


## The heap slumps: built taller than it rests, it settles down over settle_s.
func _settle(mmi: MultiMeshInstance3D) -> void:
	mmi.scale = Vector3(1, Num.f(_cfg["settle_heap"]), 1)
	var tween := mmi.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(mmi, "scale:y", 1.0, Num.f(_cfg["settle_s"]))
