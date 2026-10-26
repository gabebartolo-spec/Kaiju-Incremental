class_name ToppleFx
extends Node3D
## A toppling tower's weight (PR #89 motion review), inside the sim's fall time so nothing lags
## the sim: its base shudders and crumbles, it leans slowly, then gravity takes it; on landing the
## slab breaks up over a few frames (debris in waves, a burst of pale dust at the far end) instead
## of swapping to rubble at once, a few big chunks slide to rest and the heap slumps down into
## place. Every timing and size is the "topple_fx" tuning. Presentation only. Part of CityView.

var _city: CityView
var _cfg: Dictionary
var _rng: RandomNumberGenerator
var _breaking: Array[Dictionary] = []


func _init(city: CityView, rng: RandomNumberGenerator) -> void:
	_city = city
	_rng = rng
	_cfg = Content.section("topple_fx")


## The piece's tilt (radians) t seconds into a fall the sim times at `duration`: a shudder that
## creeps to lean_deg, then a slow lean that accelerates (sinh, like a tipping column) to 90 deg
## exactly when the sim lands it.
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
func land(node: Node3D, event: Dictionary, voxels: BuildingVoxels) -> void:
	var from: Vector2 = event["from"]
	var to: Vector2 = event["to"]
	var width := Num.f(event["width"])
	var a := Vector3(from.x, 0, from.y)
	var b := Vector3(to.x, 0, to.y)
	var lift := Vector3(0, Num.f(_cfg["dust_lift"]), 0)
	var dust := Color(str(_cfg["dust_color"]))
	_city.fx.dust(b + lift, Num.f(_cfg["impact_dust"]), dust)
	_city.fx.dust(a.lerp(b, 0.6) + lift, Num.f(_cfg["impact_dust"]) * 0.7, dust)
	_city.fx.dust_line(a, b, width, dust)
	_break_up(node, Num.f(_cfg["breakup_s"]), Num.f(_cfg["impact_debris"]))
	var cfg := _cfg
	var settle := func(mmi: MultiMeshInstance3D) -> void: _settle(mmi)
	_city.ruins().build(
		func() -> Dictionary: return Ruin.strip_plan(voxels, a, b, width, cfg), settle
	)
	_chunks(voxels, a, b, width)


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


## A few big wall chunks thrown along the strip that slide on and settle, tilted, half sunk.
func _chunks(voxels: BuildingVoxels, a: Vector3, b: Vector3, width: float) -> void:
	var along := (b - a).normalized()
	var side := Vector3(-along.z, 0, along.x)
	var sizes: Array = _cfg["chunk_size"]
	for n: int in Num.i(_cfg["chunks"]):
		var size := _rng.randf_range(Num.f(sizes[0]), Num.f(sizes[1]))
		var dims := Vector3(size, size * 0.55, size * _rng.randf_range(0.7, 1.3))
		var salt := _rng.randi() % Ruin.SALTS
		var t := _rng.randf_range(0.35, 1.0)
		var at := a.lerp(b, t) + side * _rng.randf_range(-0.4, 0.4) * width
		var slide := along * Num.f(_cfg["chunk_slide"]) * _rng.randf_range(0.4, 1.0)
		var turn := Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf(), _rng.randf_range(-0.6, 0.6))
		var rest := at + slide + Vector3(0, Num.f(_cfg["heap_top"]) + size * 0.1, 0)
		var start := at + Vector3(0, size, 0)
		var place := func(chunk: MultiMeshInstance3D) -> void: _slide(chunk, start, turn, rest)
		# Thousands of voxels each: laid out on a worker like the strip (b2-3: 7 chunks on the
		# landing frame took up to 250 ms), every random draw made here, in the same order.
		_city.ruins().build(func() -> Dictionary: return Ruin.chunk_plan(voxels, dims, salt), place)


## A thrown chunk, once built: it starts at `start`, turned by `turn`, and slides to rest,
## tilting flatter.
func _slide(chunk: MultiMeshInstance3D, start: Vector3, turn: Vector3, rest: Vector3) -> void:
	chunk.position = start
	chunk.rotation = turn
	var tween := chunk.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(chunk, "position", rest, Num.f(_cfg["settle_s"]))
	tween.parallel().tween_property(
		chunk, "rotation:x", chunk.rotation.x * 0.3, Num.f(_cfg["settle_s"])
	)
	tween.parallel().tween_property(
		chunk, "rotation:z", chunk.rotation.z * 0.3, Num.f(_cfg["settle_s"])
	)
