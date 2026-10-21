extends RefCounted
## The flow suite's topple-landing checks (director 2026-10-21, comment #30: "the building sunk
## halfway into the ground, the bottom half of the building shattered but the top half just kind
## of slid away from the camera and didnt break / each section of the building needs to shatter
## as it hits the ground in sequence"). A tall tower toppled onto the open street, and one that
## breaks on the kaiju (the sim's "hit", folded over him), are driven frame by frame at 60 Hz
## through CityView and ToppleFx; on every frame every piece of it is measured from its chunks:
##  - no point of any piece is ever below the street;
##  - the pieces (floor bands) touch the ground in order from the base to the top;
##  - right after the last one lands, no piece is left intact (each shattering or gone);
##  - a band never shrinks (its scale stays above MIN_SCALE) before it starts to burst into its own
##    cubes (ToppleFx.cubes counts them), which then leave it over shatter_release_s: it bursts,
##    it is not scaled away;
##  - the slabs the sim leaves on the street appear as the band lying over them shatters
##    (within SLAB_LAG of its first touch), not all at once after the last one.
## Seeded by design: a fixed building of the flow run's city, fixed times, no randomness read.

const ID := 900101
const SLABS := 5
const DT := 1.0 / 60.0
const GROUND_EPS := 0.12  # a piece this close to the street touches it
const BELOW_EPS := 0.02
const MIN_SCALE := 0.9
const MIN_CUBES := 20  # a band breaks into at least this many cubes between its bands
const SLAB_LAG := 0.1  # a band's slabs show this soon after it touches the street
const SLAB_ID := 910000
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
	var cubes_before: int = city._topple.cubes
	var smallest := INF  # the smallest scale any live band reached
	var span: Dictionary = {}  # piece id -> its height range up the tower
	var broke: Dictionary = {}  # piece id -> when it began to shatter
	var shown: Dictionary = {}  # slab id -> when it left the held set (appeared)
	var held := false
	var check_at := INF
	while t < land_at + 2.0:
		t += DT
		if not landed and t >= land_at:
			landed = true
			var ctx := {"id": id, "building": index, "from": from, "dir": dir, "height": height}
			ctx.merge({"width": float(b.d), "lean": ToppleFx.tilt(_cfg(), t, duration)})
			city.fall_land(_landing(ctx, on_kaiju))
			var tail := Num.f(_cfg()["band_gap_s"]) * (Num.i(_cfg()["band_max"]) - 1)
			var fold_end := Num.f(_cfg()["fold_s"]) if on_kaiju else tail
			check_at = t + fold_end + DT * 2.0
		elif not landed:
			city._animate_falls(DT)
		city._topple._process(DT)
		if landed:
			var waiting: Dictionary = city._topple._rubble._hidden
			for k: int in SLABS:
				held = held or waiting.has(SLAB_ID + k)
				if held and not waiting.has(SLAB_ID + k) and not shown.has(SLAB_ID + k):
					shown[SLAB_ID + k] = t
		for tween: Tween in city.get_tree().get_processed_tweens():
			tween.custom_step(DT)
		var pieces := _pieces(city, pivot)
		for piece: Node3D in pieces:
			var low := _low(piece)
			lowest = minf(lowest, low)
			var scale := piece.global_transform.basis.get_scale().abs()
			if not piece.has_meta("breaking"):  # once it bursts it shortens as its cubes leave
				smallest = minf(smallest, minf(scale.x, minf(scale.y, scale.z)))
			var key := piece.get_instance_id()
			if not order.has(key):
				order[key] = _height(piece)
				span[key] = _range(piece)
			if low <= GROUND_EPS and not contact.has(key):
				contact[key] = t
			if piece.has_meta("breaking") and not broke.has(key):
				broke[key] = t
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
	check.call(
		smallest >= MIN_SCALE, "no band shrinks before it bursts (smallest scale %.2f)" % smallest
	)
	var cubes: int = city._topple.cubes - cubes_before
	check.call(cubes >= MIN_CUBES * keys.size(), "each band bursts into cubes (%d)" % cubes)
	if not on_kaiju:
		var breaks: Array[float] = []
		for key: int in keys:
			breaks.append(Num.f(broke.get(key, INF)))
		var in_order := breaks.size() >= 2 and breaks[-1] < INF
		for k: int in range(1, breaks.size()):
			in_order = in_order and breaks[k] > breaks[k - 1]
		check.call(in_order, "its bands shatter in order from the base (%s)" % [_fmt(breaks)])
		_check_slabs(check, [shown, span, broke], height)


## Each slab the street got shows within SLAB_LAG of its band shattering on the street (the band
## whose height range up the tower holds its distance along the fall, else the nearest).
## seen: [slab id -> when it appeared, piece id -> height range, piece id -> when it began to shatter].
static func _check_slabs(check: Callable, seen: Array, height: float) -> void:
	var shown: Dictionary = seen[0]
	var span: Dictionary = seen[1]
	var broke: Dictionary = seen[2]
	var worst := 0.0
	var missing := 0
	for k: int in SLABS:
		var along := _slab_along(k, height)
		var best := INF
		var band := -1
		for key: int in span:
			var range: Vector2 = span[key]
			var gap := maxf(range.x - along, along - range.y)
			if gap < best:
				best = gap
				band = key
		if not shown.has(SLAB_ID + k) or not broke.has(band):
			missing += 1
			continue
		worst = maxf(worst, absf(Num.f(shown[SLAB_ID + k]) - Num.f(broke[band])))
	check.call(
		missing == 0 and worst <= SLAB_LAG,
		"each slab shows as its band shatters (%d missing, worst lag %.2f s)" % [missing, worst]
	)


static func _slab_along(k: int, height: float) -> float:
	return height * (0.12 + 0.17 * k)


static func _slabs(from: Vector2, dir: Vector2, height: float) -> Array:
	var out: Array = []
	for k: int in SLABS:
		var pos := from + dir * _slab_along(k, height) + Vector2(dir.y, -dir.x) * 1.0
		var dims := Vector3(2.0, 1.1, 3.0)
		out.append(
			{"id": SLAB_ID + k, "from": from, "pos": pos, "dims": dims, "yaw": 0.0, "base": 0.0}
		)
	return out


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
		event["slabs"] = _slabs(from, dir, height)
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


## The pieces of this fall now (every lifted or split piece shares its pivot), also those that
## burst this frame (hidden, or queued to be freed).
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
		if at.is_equal_approx(pivot):  # a burst band is hidden or freed on the frame it bursts
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


## The heights (up the tower, from its pivot) its chunks cover.
static func _range(piece: Node3D) -> Vector2:
	var pivot: Vector3 = piece.get_meta("pivot")
	var out := Vector2(INF, -INF)
	for part: Dictionary in piece.get_meta("parts", []):
		var pos: Vector3 = part["pos"]
		out = Vector2(minf(out.x, pos.y - pivot.y - HALF_CELL), maxf(out.y, pos.y - pivot.y + HALF_CELL))
	return out


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
