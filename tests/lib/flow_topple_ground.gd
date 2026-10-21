extends RefCounted
## The flow suite's topple-landing checks (director 2026-10-21, comment #30: "the building sunk
## halfway into the ground, the bottom half of the building shattered but the top half just kind
## of slid away from the camera and didnt break / each section of the building needs to shatter
## as it hits the ground in sequence"). A tall tower toppled onto the open street, and one that
## breaks on the kaiju (the sim's "hit", folded over him), are driven frame by frame at 60 Hz
## through CityView and ToppleFx; on every frame every piece of it is measured from its chunks:
##  - no point of any piece is ever below the street;
##  - the pieces (floor bands) touch the ground in order from the base to the top;
##  - right after the last one lands, no piece is left intact (each shattering or gone).
## Seeded by design: a fixed building of the flow run's city, fixed times, no randomness read.

const ID := 900101
const DT := 1.0 / 60.0
const GROUND_EPS := 0.12  # a piece this close to the street touches it
const BELOW_EPS := 0.02
const HALF_CELL := 0.5  # a part's "pos" is its chunk's centre


static func check_all(check: Callable, rampage: Rampage) -> void:
	var picks := _tallest(rampage.sim, 2)
	_run(check, rampage, picks[0], ID, false)
	_run(check, rampage, picks[1], ID + 1, true)


## The `count` tallest ordinary buildings standing whole.
static func _tallest(sim: RampageSim, count: int) -> Array[int]:
	var order: Array[int] = []
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.landmark == "" and b.frame.h >= 8 and b.frame.alive_count > 0:
			order.append(i)
	order.sort_custom(
		func(a: int, b: int) -> bool: return sim.buildings[a].frame.h > sim.buildings[b].frame.h
	)
	return order.slice(0, count)


static func _run(check: Callable, rampage: Rampage, index: int, id: int, on_kaiju: bool) -> void:
	var sim := rampage.sim
	var city := rampage._city
	var b := sim.buildings[index]
	var cells: Array[Vector3i] = []
	for y: int in b.frame.h:
		for x: int in b.frame.w:
			for z: int in b.frame.d:
				if b.frame.alive(Vector3i(x, y, z)):
					cells.append(Vector3i(x, y, z))
	var dir := Vector2(-1, 0)
	var pivot := b.local_to_world(Vector3(0, 0, b.d * 0.5))
	var height := float(b.frame.h)
	var duration := sqrt(2.0 * height / Num.f(sim.city["fall_gravity"])) * 1.8
	(
		city
		. fall_start(
			{
				"id": id,
				"building": index,
				"cells": cells,
				"kind": "topple",
				"pivot": pivot,
				"dir": dir,
				"drop": 0.0,
				"duration": duration,
			}
		)
	)
	var from := Vector2(pivot.x, pivot.z)
	var land_at := duration * (0.6 if on_kaiju else 1.0)
	var landed := false
	var t := 0.0
	var lowest := INF
	var contact: Dictionary = {}  # piece id -> first time it touched the street
	var order: Dictionary = {}  # piece id -> its height up the tower (mean of its chunks)
	var intact := -1
	var check_at := INF
	while t < land_at + 2.0:
		t += DT
		if not landed and t >= land_at:
			landed = true
			var ctx := {"id": id, "building": index, "from": from, "dir": dir, "height": height}
			ctx.merge({"width": float(b.d), "lean": ToppleFx.tilt(_cfg(), t, duration)})
			city.fall_land(_landing(ctx, on_kaiju))
			var fold_end := Num.f(_cfg()["fold_s"]) if on_kaiju else 0.0
			check_at = t + fold_end + DT * 2.0
		elif not landed:
			city._animate_falls(DT)
		city._topple._process(DT)
		for tween: Tween in city.get_tree().get_processed_tweens():
			tween.custom_step(DT)
		var pieces := _pieces(city, pivot)
		for piece: Node3D in pieces:
			var low := _low(piece)
			lowest = minf(lowest, low)
			var key := piece.get_instance_id()
			if not order.has(key):
				order[key] = _height(piece)
			if low <= GROUND_EPS and not contact.has(key):
				contact[key] = t
		if intact < 0 and t >= check_at:
			intact = 0
			for piece: Node3D in pieces:
				if not piece.has_meta("breaking"):
					intact += 1
	var keys := order.keys()
	keys.sort_custom(func(a: int, c: int) -> bool: return order[a] < order[c])
	var times: Array[float] = []
	for key: int in keys:
		times.append(Num.f(contact.get(key, INF)))
	var rising := times.size() >= 2
	for k: int in range(1, times.size()):
		rising = rising and times[k] > times[k - 1] and times[k] < INF
	var what := "on the kaiju" if on_kaiju else "onto the street"
	check.call(
		lowest >= -BELOW_EPS,
		(
			"a %d-floor tower toppled %s never goes below the street (lowest %.2f)"
			% [height, what, lowest]
		)
	)
	check.call(
		rising, "its bands touch the ground in order from the base to the top (%s)" % [_fmt(times)]
	)
	check.call(intact == 0, "after it lands no band is left intact (%d)" % intact)


static func _cfg() -> Dictionary:
	return Content.section("topple_fx")


## The sim's fall_land for it (ctx: id, building, from, dir, height, width, lean): onto the
## street, or broken on the kaiju half way up (a "hit" with three large fold slabs).
static func _landing(ctx: Dictionary, on_kaiju: bool) -> Dictionary:
	var from: Vector2 = ctx["from"]
	var dir: Vector2 = ctx["dir"]
	var height := Num.f(ctx["height"])
	var event := {
		"type": "fall_land",
		"id": ctx["id"],
		"kind": "topple",
		"building": ctx["building"],
		"from": from,
		"to": from + dir * height,
		"width": ctx["width"],
		"slabs": [],
	}
	if not on_kaiju:
		return event
	var crack := height * 0.5
	var lean := Num.f(ctx["lean"])
	var at := Vector3(from.x, 0, from.y) + FallMotion.topple_turn(dir, lean) * (Vector3.UP * crack)
	var s := crack * sin(lean)
	var side := Vector2(0, 1)
	var pieces: Array = []
	for k: int in 3:
		var pos := from + dir * (s + 2.0 + 3.0 * k) + side * 3.0
		pieces.append(
			{
				"id": 900000 + k,
				"from": Vector2(at.x, at.z),
				"pos": pos,
				"dims": Vector3(2.0, 1.1, 3.0),
				"yaw": 0.0,
				"base": 0.0
			}
		)
	event["to"] = from + dir * s
	event["hit"] = {
		"at": at, "crack": crack, "s": s, "side": side, "pieces": pieces, "large": pieces.size()
	}
	return event


## The pieces of this fall now (every lifted or split piece shares its pivot), drawn.
static func _pieces(city: CityView, pivot: Vector3) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var stack: Array[Node] = [city]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if not (node is Node3D) or not node.has_meta("parts") or not node.has_meta("pivot"):
			continue
		var piece := node as Node3D
		var at: Vector3 = piece.get_meta("pivot")
		if at.is_equal_approx(pivot) and piece.is_visible_in_tree():
			if not piece.is_queued_for_deletion():
				out.append(piece)
	return out


## The lowest world height of any of its chunks (each a cell box about its centre).
static func _low(piece: Node3D) -> float:
	var xf := piece.global_transform
	var b := xf.basis
	var half := HALF_CELL * (absf(b.x.y) + absf(b.y.y) + absf(b.z.y))
	var pivot: Vector3 = piece.get_meta("pivot")
	var low := INF
	for part: Dictionary in piece.get_meta("parts", []):
		var pos: Vector3 = part["pos"]
		low = minf(low, (xf * (pos - pivot)).y - half)
	return low


static func _height(piece: Node3D) -> float:
	var pivot: Vector3 = piece.get_meta("pivot")
	var sum := 0.0
	var parts: Array = piece.get_meta("parts", [])
	for part: Dictionary in parts:
		var pos: Vector3 = part["pos"]
		sum += pos.y - pivot.y
	return sum / maxf(1.0, parts.size())


static func _fmt(times: Array[float]) -> String:
	var out: PackedStringArray = []
	for x: float in times:
		out.append("%.2f" % x)
	return ", ".join(out)
