class_name Collapse
extends RefCounted
## What happens after a building loses support: parts that drop straight down, towers that
## topple over an edge, and what they smash when they land (the floors below, or a strip of
## street, buildings and tanks). A part that meets the kaiju's body on the way down breaks on
## him (comments #24, FallContact): a topple cracks where it touched, the part below the crack
## comes down in front of him and the rest folds over and slides off his side as a few large
## slabs; a drop lands on him and crumbles. What lands leaves slabs the kaiju can break (D-110,
## RubbleSlabs). Part of RampageSim; split out to keep files small.

var sim: RampageSim
## Buildings that toppled over sideways (each counted once) and the tallest of them, in floors:
## the results screen's biggest collapse.
var toppled := 0
var tallest_topple := 0
## The slabs lying on the street.
var slabs: RubbleSlabs
## False: a falling part passes through the kaiju (the sim suite's fixture for the old game).
var breaks_on_kaiju := true
var _toppled_ids: Dictionary = {}
var _tilt: Dictionary  # the "topple_fx" lean curve (FallContact.tilt)
var _rubble: Dictionary
var _across: Dictionary = {}  # fall id -> half width across a topple, for contact tests
var _feet: Dictionary = {}  # fall id -> its chunks' world centres, for a drop's contact tests


## tuning: the rampage's tuning ("rubble", "topple_fx"; either missing turns its part off).
func _init(p_sim: RampageSim, tuning: Dictionary = {}, rng: RandomNumberGenerator = null) -> void:
	sim = p_sim
	_tilt = tuning.get("topple_fx", {})
	_rubble = tuning.get("rubble", {})
	slabs = RubbleSlabs.new(sim, _rubble, rng if rng != null else RandomNumberGenerator.new())


## Turns every part of building `index` that lost support into a Fall. A carved building's
## parts (Carving.settle) also carry their fine cells, which the fall_start event passes on.
func settle(index: int) -> void:
	var b := sim.buildings[index]
	var g := Num.f(sim.city["fall_gravity"])
	var parts := sim.carving.settle(index) if sim.carving.promoted(index) else b.frame.settle()
	for part: Dictionary in parts:
		var rule_dir: Vector2i = part["dir"]
		var f := RampageSim.Fall.new()
		f.id = sim.next_fall_id
		sim.next_fall_id += 1
		f.building = index
		f.cells = part["cells"]
		f.kind = str(part["kind"])
		var lowest := 9999
		var highest := 0
		for c: Vector3i in f.cells:
			lowest = mini(lowest, c.y)
			highest = maxi(highest, c.y)
		f.height = highest - lowest + 1
		var low := float(lowest)
		var carved := part.has("index")
		if carved:  # its size from its fine cells
			low = Num.f(part["low"])
			f.height = Num.f(part["height"])
			f.width = Num.f(part["width"])
		var gutted: bool = (
			part.get("gutted", false) if carved else _gutted(b, f.cells, lowest, int(f.height))
		)
		if f.kind == "drop" and b.landmark == "" and gutted:
			f.kind = "topple"  # its whole base went at once: it goes over, it never pops
		if f.kind == "topple":
			if not f.cells.is_empty() and not _toppled_ids.has(index):
				_toppled_ids[index] = true
				toppled += 1
			var dir: Vector2i = part["dir"]
			var pivot: Vector3 = part["pivot"]
			# D-099: it falls by its own physics, toward the side that was cut away (the support
			# rule's dir), onto the kaiju if that is the side. A gutted drop has no rule dir: its
			# whole base went, and the chew came from the kaiju's side, so it goes that way.
			if dir == Vector2i.ZERO:
				var base: Rect2 = part["base"] if carved else _base(f.cells, lowest)
				var centre := b.local_to_world(
					Vector3(base.get_center().x, low, base.get_center().y)
				)
				dir = _toward(Vector2(centre.x, centre.z) - sim.kaiju_pos)
				pivot = _edge(base, low, dir)
				if carved:
					f.width = base.size.y if dir.x != 0 else base.size.x
			f.dir = Vector2(dir)
			f.pivot = b.local_to_world(pivot)
			f.duration = sqrt(2.0 * f.height / g) * 1.8
		else:
			f.drop = Num.f(part["drop"]) if part.has("drop") else _drop_distance(b, f, low)
			f.pivot = b.local_to_world(Vector3(b.w * 0.5, low, b.d * 0.5))
			f.duration = sqrt(2.0 * f.drop / g)
		sim.falls.append(f)
		var event := {
			"type": "fall_start",
			"id": f.id,
			"building": index,
			"cells": f.cells,
			"kind": f.kind,
			"pivot": f.pivot,
			"dir": f.dir,
			"cut_dir": Vector2(rule_dir),
			"drop": f.drop,
			"duration": f.duration,
		}
		if carved:
			event["index"] = part["index"]
			event["mats"] = part["mats"]
		sim.events.append(event)


## A part with nothing under it that is taller than it is deep (its narrower side at its lowest
## floor): a tower whose base the kaiju ate in one go. It topples instead of dropping a few floors
## and vanishing whole (PR #89 review, capture 39277970463 frames 505-506).
static func _gutted(
	b: RampageSim.Building, cells: Array[Vector3i], lowest: int, height: int
) -> bool:
	var lo := Vector2i(9999, 9999)
	var hi := Vector2i(-1, -1)
	for c: Vector3i in cells:
		if c.y != lowest:
			continue
		if b.frame.top_below(c.x, c.z, c.y) >= 0:
			return false
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.z))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.z))
	return height > mini(hi.x - lo.x, hi.y - lo.y) + 1


## The footprint (local x, z) of a part's lowest floor.
static func _base(cells: Array[Vector3i], lowest: int) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Vector3i in cells:
		if c.y == lowest:
			lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.z))
			hi = Vector2(maxf(hi.x, c.x + 1), maxf(hi.y, c.z + 1))
	return Rect2(lo, hi - lo)


## The level direction (one of the four, like Structure's) from the tower's base to the kaiju;
## north when the kaiju stands on the base's centre.
static func _toward(to_base: Vector2) -> Vector2i:
	if to_base.is_zero_approx():
		return Vector2i(0, -1)
	if absf(to_base.x) > absf(to_base.y):
		return Vector2i(-signi(roundi(to_base.x * 100.0)), 0)
	return Vector2i(0, -signi(roundi(to_base.y * 100.0)))


## The pivot edge (local frame) a part tips over going `dir`: the far side of its base (the
## footprint of its lowest floor, at height `low`), centred across the fall.
static func _edge(base: Rect2, low: float, dir: Vector2i) -> Vector3:
	var lo := base.position
	var hi := base.end
	var mid := base.get_center()
	return Vector3(
		hi.x if dir.x > 0 else (lo.x if dir.x < 0 else mid.x),
		low,
		hi.y if dir.y > 0 else (lo.y if dir.y < 0 else mid.y)
	)


## How far a loose part drops before it meets what still stands below it (or the ground).
func _drop_distance(b: RampageSim.Building, f: RampageSim.Fall, lowest: float) -> float:
	var drop := lowest
	for c: Vector3i in f.cells:
		var below := b.frame.top_below(c.x, c.z, c.y)
		drop = minf(drop, c.y - below - 1)
	return maxf(0.5, drop)


func step(dt: float) -> void:
	var discs: Array = []
	if breaks_on_kaiju and sim.body != null and sim.body.active() and not sim.airborne:
		discs = sim.body.world_discs(sim.kaiju_pos, sim.body.heading)
	var landed: Array[RampageSim.Fall] = []
	for f: RampageSim.Fall in sim.falls:
		f.t += dt
		if f.t >= f.duration or (not discs.is_empty() and _meets(f, discs)):
			landed.append(f)
	for f: RampageSim.Fall in landed:
		sim.falls.erase(f)
		_land(f)
		_across.erase(f.id)
		_feet.erase(f.id)
	sim.carving.warm()  # one stage of getting the next building ready for its first hit


## A falling part hits: its chunks become rubble (a bonus for toppled towers) and it smashes
## what it lands on: the floors below a drop, or a strip of street and buildings for a topple.
func _land(f: RampageSim.Fall) -> void:
	var b := sim.buildings[f.building]
	var bonus := Num.f(sim.city["topple_bonus"]) if f.kind == "topple" else 1.0
	sim.pay(b, f.cells.size(), bonus)
	var impact := Num.f(sim.city["impact_damage"])
	var event := {"type": "fall_land", "id": f.id, "kind": f.kind, "building": f.building}
	# A carved scrap (less than a chunk's worth, "scrap"): it lands, and smashes nothing.
	var scrap := f.cells.is_empty()
	event["scrap"] = scrap
	if f.kind == "topple":
		var start := Vector2(f.pivot.x, f.pivot.z)
		var half_width := _half_width(f)
		# What comes down in line: all of it, or up to his body when it broke on the kaiju.
		var reach := f.height if f.hit.is_empty() else Num.f(f.hit["s"])
		var finish := start + f.dir * reach
		event["from"] = start
		event["to"] = finish
		event["width"] = half_width * 2.0
		sim.events.append(event)
		if not scrap:
			tallest_topple = maxi(tallest_topple, roundi(f.height))
			_crush_strip(start, finish, half_width, f.building)
			event["slabs"] = _strip_slabs(f, [start, finish, half_width], reach)
			if not f.hit.is_empty():
				event["hit"] = _fold(f, half_width)
	else:
		if not f.hit.is_empty():
			event["hit"] = {"at": f.hit["at"]}
		sim.events.append(event)
		if scrap or not f.hit.is_empty():  # it broke on the kaiju, not on the floors below
			return
		var hit: Array[Vector3i] = []
		for c: Vector3i in f.cells:
			var below := b.frame.top_below(c.x, c.z, c.y)
			if below >= 0 and not hit.has(Vector3i(c.x, below, c.z)):
				hit.append(Vector3i(c.x, below, c.z))
		sim.damage_chunks(f.building, hit, impact)


## Whether a falling part meets the kaiju's body now (FallContact); records where in f.hit.
func _meets(f: RampageSim.Fall, discs: Array) -> bool:
	if f.cells.is_empty():
		return false  # a carved scrap smashes nothing
	if f.kind == "topple":
		var lean := FallContact.tilt(_tilt, f.t, f.duration)
		f.hit = FallContact.topple(f, lean, _half_width(f), discs)
	else:
		if not _feet.has(f.id):
			var b := sim.buildings[f.building]
			var feet: Array[Vector3] = []
			for c: Vector3i in f.cells:
				feet.append(b.chunk_world(c))
			_feet[f.id] = feet
		var k := f.t / f.duration
		var at: Array[Vector3] = _feet[f.id]
		f.hit = FallContact.drop(f.pivot.y - f.drop * k * k, f.height, at, discs)
	return not f.hit.is_empty()


## Half a topple's width across its fall, plus half a chunk (cached per fall).
func _half_width(f: RampageSim.Fall) -> float:
	if not _across.has(f.id):
		var b := sim.buildings[f.building]
		var across := Vector2(-f.dir.y, f.dir.x)
		var width := f.width if f.width >= 0.0 else _width_across(b, f.cells, across)
		_across[f.id] = width * 0.5 + 0.5
	return Num.f(_across[f.id])


## The slabs a topple leaves along the strip it came down on: "slabs" of them for a whole
## tower, fewer when it broke on the kaiju and only `reach` of it came down in line.
## A landmark leaves none (its sections burst, LandmarkBurst).
## line: [start, finish, half_width].
func _strip_slabs(f: RampageSim.Fall, line: Array, reach: float) -> Array[Dictionary]:
	if not slabs.on() or sim.buildings[f.building].landmark != "" or reach < 1.0:
		return []
	var count := maxi(1, roundi(Num.f(_rubble["slabs"]) * reach / maxf(1.0, f.height)))
	var discs: Array = []
	if not f.hit.is_empty():
		discs = sim.body.world_discs(sim.kaiju_pos, sim.body.heading)
	return slabs.strip(f.building, line, count, discs)


## A topple broke on the kaiju: what was above the crack folds over him and slides off his side
## (the side of the tower's centre line he stood on, else by the fall's id) as up to
## fold_pieces large slabs, and the impact edge leaves edge_pieces small ones beside him. What
## they land on is smashed. Returns the event's "hit": {"at", "crack", "s", "side" (unit,
## across the fall), "pieces" (slab dicts, the large ones first), "large" (how many)}.
func _fold(f: RampageSim.Fall, half_width: float) -> Dictionary:
	var hit := f.hit
	var crack := Num.f(hit["crack"])
	var at: Vector3 = hit["at"]
	var sign := Num.f(hit["side"])
	if sign == 0.0:
		sign = 1.0 if f.id % 2 == 0 else -1.0
	var side := Vector2(-f.dir.y, f.dir.x) * sign
	var out := {"at": at, "crack": crack, "s": hit["s"], "side": side, "pieces": [], "large": 0}
	var rest := f.height - crack
	if not slabs.on() or rest < 1.0 or sim.buildings[f.building].landmark != "":
		return out
	var contact := Vector2(at.x, at.z)
	var radius := Num.f(hit["radius"])
	var clear := radius + half_width + Num.f(_rubble["fold_clear"])
	var most := Num.f(_rubble["fold_max"])
	var n := clampi(ceili(rest / Num.f(_rubble["fold_length"])), 1, Num.i(_rubble["fold_pieces"]))
	var size := minf(half_width * 2.0, most)
	var piece := rest / n
	var reach := Num.f(_rubble["fold_reach"])
	var pieces: Array[Dictionary] = []
	var lo := contact + side * clear
	var yaw := atan2(f.dir.x, f.dir.y)  # its length along the fall
	var discs := sim.body.world_discs(sim.kaiju_pos, sim.body.heading)
	var step := Num.f(_rubble["clear_step"])
	var tries := ceili(sim.body.length() / step) + 1
	for k: int in n:
		var dims := Vector3(size, size * Num.f(_rubble["depth"]), minf(piece, most))
		var to := lo + f.dir * piece * (k + 0.5) * reach
		to = RubbleSlabs.clear_of(to, dims, yaw, side, discs, step, tries)
		pieces.append(slabs.place(f.building, [contact, to], dims, yaw))
	_crush_strip(lo, lo + f.dir * rest * reach, size * 0.5, f.building)
	var edge: Array = _rubble["edge_size"]
	var small := Vector3(Num.f(edge[0]), Num.f(edge[1]), Num.f(edge[0]))
	for k: int in Num.i(_rubble["edge_pieces"]):
		var to := contact + side * (radius + small.x) + f.dir * (k - 1) * small.x
		to = RubbleSlabs.clear_of(to, small, yaw + k, side, discs, step, tries)
		pieces.append(slabs.place(f.building, [contact, to], small, yaw + k))
	out["pieces"] = pieces
	out["large"] = n
	return out


func _width_across(b: RampageSim.Building, cells: Array[Vector3i], across: Vector2) -> float:
	var lo := INF
	var hi := -INF
	for c: Vector3i in cells:
		var p := b.chunk_world(c)
		var t := Vector2(p.x, p.z).dot(across)
		lo = minf(lo, t)
		hi = maxf(hi, t)
	return hi - lo + 1.0


## Everything inside the strip a toppled tower lands on is smashed: chunks of other buildings
## up to a few floors high, and tanks.
func _crush_strip(start: Vector2, finish: Vector2, half_width: float, own: int) -> void:
	var impact := Num.f(sim.city["impact_damage"])
	var along := (finish - start).normalized()
	var length := start.distance_to(finish)
	var in_strip := func(p: Vector2, r: float) -> bool:
		var rel := p - start
		var t := rel.dot(along)
		var side := absf(rel.dot(Vector2(-along.y, along.x)))
		return t >= -r and t <= length + r and side <= half_width + r
	for i: int in sim.buildings.size():
		if i == own:
			continue
		var b := sim.buildings[i]
		var near: bool = in_strip.call(Vector2(b.x, b.z), Vector2(b.w, b.d).length() * 0.5)
		if not near:
			continue
		var cells: Array[Vector3i] = []
		for y: int in mini(ceili(half_width * 2.0) + 1, b.height):
			for x: int in b.w:
				for z: int in b.d:
					var c := Vector3i(x, y, z)
					var p := b.chunk_world(c)
					var struck: bool = in_strip.call(Vector2(p.x, p.z), 0.5)
					if b.frame.alive(c) and struck:
						cells.append(c)
		sim.damage_chunks(i, cells, impact)
	for tank: RampageSim.Tank in sim.tanks:
		var struck: bool = in_strip.call(tank.pos, 0.6)
		if struck:
			tank.hp = 0.0
	sim.army_units.clear_dead()
