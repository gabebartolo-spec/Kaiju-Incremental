class_name Collapse
extends RefCounted
## What happens after a building loses support: parts that drop straight down, towers that
## topple over an edge, and what they smash when they land (the floors below, or a strip of
## street, buildings and tanks). Part of RampageSim; split out to keep files small.

var sim: RampageSim
## Buildings that toppled over sideways (each counted once) and the tallest of them, in floors:
## the results screen's biggest collapse.
var toppled := 0
var tallest_topple := 0
var _toppled_ids: Dictionary = {}
## b2-5 (D-386): the odds a topple goes toward its cut side, to either side of it, or away from
## it (tuning destruction.fall_dirs), drawn from the run's own stream so a replay matches.
var _odds := PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
var _rng: RandomNumberGenerator


func _init(p_sim: RampageSim, tuning: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	_rng = rng
	var dirs: Dictionary = tuning.get("destruction", {}).get("fall_dirs", {})
	if not dirs.is_empty():
		var side := Num.f(dirs["side"])
		_odds = PackedFloat32Array([Num.f(dirs["cut"]), side, side, Num.f(dirs["away"])])


## Buildings in the arena with every chunk gone (the thanks screen's "buildings destroyed").
func destroyed_buildings() -> int:
	var n := 0
	for b: RampageSim.Building in sim.buildings:
		if b.in_arena and b.frame.alive_count == 0:  # the sim's own ruin rule (the chunk mirror)
			n += 1
	return n


## A regrown tower may topple (and count) again.
func forget_topple(index: int) -> void:
	_toppled_ids.erase(index)


## Turns every part of building `index` that lost support into a Fall. A carved building's
## parts (Carving.settle) also carry their fine cells, which the fall_start event passes on.
func settle(index: int) -> void:
	var b := sim.buildings[index]
	var g := Num.f(sim.city["fall_gravity"])
	var parts := sim.carving.settle(index) if sim.carving.promoted(index) else b.frame.settle()
	for part: Dictionary in parts:
		var f := _start_fall(index, b, part, g)
		sim.falls.append(f)
		sim.events.append(_fall_event(f, part, index))


## One falling part of a building: its cells, kind and size, and how it will move (a topple turns
## on a pivot, a drop falls straight down).
func _start_fall(index: int, b: RampageSim.Building, part: Dictionary, g: float) -> RampageSim.Fall:
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
		_aim_topple(f, b, part, low)
		f.duration = sqrt(2.0 * f.height / g) * 1.8
	else:
		f.drop = Num.f(part["drop"]) if part.has("drop") else _drop_distance(b, f, low)
		f.pivot = b.local_to_world(Vector3(b.w * 0.5, low, b.d * 0.5))
		f.duration = sqrt(2.0 * f.drop / g)
	return f


## Sets a toppling part's direction and pivot.
func _aim_topple(f: RampageSim.Fall, b: RampageSim.Building, part: Dictionary, low: float) -> void:
	var dir: Vector2i = part["dir"]
	var pivot: Vector3 = part["pivot"]
	# D-099: its cut side is the side that was cut away (the support rule's dir). A gutted drop
	# has no rule dir: its whole base went, and the chew came from the kaiju's side. b2-5
	# (D-386): a landmark falls to its cut side; any other part draws cut, side or away.
	var cut := dir
	var carved := part.has("index")
	var base: Rect2 = part["base"] if carved else _base(f.cells, roundi(low))
	if cut == Vector2i.ZERO:
		var centre := b.local_to_world(Vector3(base.get_center().x, low, base.get_center().y))
		cut = _toward(Vector2(centre.x, centre.z) - sim.kaiju_pos)
	dir = cut if b.landmark != "" else _vary(cut)
	if dir != part["dir"]:
		pivot = _edge(base, low, dir)
		if carved:
			f.width = base.size.y if dir.x != 0 else base.size.x
	f.dir = Vector2(dir)
	f.pivot = b.local_to_world(pivot)


## The fall_start event of a part.
func _fall_event(f: RampageSim.Fall, part: Dictionary, index: int) -> Dictionary:
	var rule_dir: Vector2i = part["dir"]
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
	if part.has("index"):
		event["index"] = part["index"]
		event["mats"] = part["mats"]
		event["under"] = part.get("under", false)  # what held it at the settle
		event["support"] = part.get("support", -1)
	if f.kind == "topple":  # where it will land, so the street knows who is under it
		var strip := _strip(f)
		event["to"] = strip[1]
		event["width"] = Num.f(strip[2]) * 2.0
	return event


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


## b2-5 (D-386): a topple's direction drawn from `cut` by the odds: cut, its left, its right or
## away (one draw per topple, in the order the sim starts them).
func _vary(cut: Vector2i) -> Vector2i:
	var roll := _rng.randf()
	var options: Array[Vector2i] = [cut, Vector2i(-cut.y, cut.x), Vector2i(cut.y, -cut.x), -cut]
	for k: int in options.size():
		roll -= _odds[k]
		if roll < 0.0:
			return options[k]
	return cut


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
	var landed: Array[RampageSim.Fall] = []
	for f: RampageSim.Fall in sim.falls:
		f.t += dt
		if f.t >= f.duration:
			landed.append(f)
	for f: RampageSim.Fall in landed:
		sim.falls.erase(f)
		_land(f)
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
		var strip := _strip(f)
		var start: Vector2 = strip[0]
		var finish: Vector2 = strip[1]
		var half_width := Num.f(strip[2])
		event["from"] = start
		event["to"] = finish
		event["width"] = half_width * 2.0
		sim.events.append(event)
		if not scrap:
			tallest_topple = maxi(tallest_topple, roundi(f.height))
			_crush_strip(start, finish, half_width, f.building)
	else:
		sim.events.append(event)
		if scrap:
			return
		var hit: Array[Vector3i] = []
		for c: Vector3i in f.cells:
			var below := b.frame.top_below(c.x, c.z, c.y)
			if below >= 0 and not hit.has(Vector3i(c.x, below, c.z)):
				hit.append(Vector3i(c.x, below, c.z))
		sim.damage_chunks(f.building, hit, impact)


## A topple's landing strip: [from, to, half width] (street level, world).
func _strip(f: RampageSim.Fall) -> Array:
	var start := Vector2(f.pivot.x, f.pivot.z)
	var across := Vector2(-f.dir.y, f.dir.x)
	var b := sim.buildings[f.building]
	var width := f.width if f.width >= 0.0 else _width_across(b, f.cells, across)
	return [start, start + f.dir * f.height, width * 0.5 + 0.5]


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
		var cells := _strip_cells(b, in_strip, half_width)
		sim.damage_chunks(i, cells, impact)
	for tank: RampageSim.Tank in sim.tanks:
		var struck: bool = in_strip.call(tank.pos, 0.6)
		if struck:
			tank.hp = 0.0
	sim.army_units.clear_dead()


## The standing chunks of b a few floors up that lie inside the strip (in_strip: Callable(p, r)).
func _strip_cells(b: RampageSim.Building, in_strip: Callable, half_width: float) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for y: int in mini(ceili(half_width * 2.0) + 1, b.height):
		for x: int in b.w:
			for z: int in b.d:
				var c := Vector3i(x, y, z)
				var p := b.chunk_world(c)
				var struck: bool = in_strip.call(Vector2(p.x, p.z), 0.5)
				if b.frame.alive(c) and struck:
					cells.append(c)
	return cells
