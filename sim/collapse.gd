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


func _init(p_sim: RampageSim) -> void:
	sim = p_sim


## Turns every part of building `index` that lost support into a Fall. A carved building's
## parts (Carving.settle) also carry their fine cells, which the fall_start event passes on.
func settle(index: int) -> void:
	var b := sim.buildings[index]
	var g := Num.f(sim.city["fall_gravity"])
	var parts := sim.carving.settle(index) if sim.carving.promoted(index) else b.frame.settle()
	for part: Dictionary in parts:
		var f := RampageSim.Fall.new()
		f.id = sim.next_fall_id
		sim.next_fall_id += 1
		f.building = index
		f.cells = part["cells"]
		f.kind = str(part["kind"])
		var lowest := 9999.0
		var highest := 0
		for c: Vector3i in f.cells:
			lowest = minf(lowest, c.y)
			highest = maxi(highest, c.y)
		f.height = highest - lowest + 1
		if part.has("index"):  # carved: its size from its fine cells
			lowest = Num.f(part["low"])
			f.height = Num.f(part["height"])
			f.width = Num.f(part["width"])
		if f.kind == "topple":
			if not f.cells.is_empty() and not _toppled_ids.has(index):
				_toppled_ids[index] = true
				toppled += 1
			var dir: Vector2i = part["dir"]
			f.dir = Vector2(dir)
			var pivot: Vector3 = part["pivot"]
			f.pivot = b.local_to_world(pivot)
			f.duration = sqrt(2.0 * f.height / g) * 1.8
		else:
			f.drop = Num.f(part["drop"]) if part.has("drop") else _drop_distance(b, f, lowest)
			f.pivot = b.local_to_world(Vector3(b.w * 0.5, lowest, b.d * 0.5))
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
			"drop": f.drop,
			"duration": f.duration,
		}
		if part.has("index"):
			event["index"] = part["index"]
			event["mats"] = part["mats"]
		sim.events.append(event)


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
		var finish := start + f.dir * f.height
		var across := Vector2(-f.dir.y, f.dir.x)
		var width := f.width if f.width >= 0.0 else _width_across(b, f.cells, across)
		var half_width := width * 0.5 + 0.5
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
