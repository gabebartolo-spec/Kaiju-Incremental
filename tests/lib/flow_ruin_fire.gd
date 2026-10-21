extends RefCounted
## The flow suite's "rubble never burns" check (director 2026-10-20, #111: "a destroyed building
## stays rubble, never a burning shell"; R 26.1). The beam's coat lights fires on a standing
## building; once every chunk of it is down, none of them burns, and the view lights no new fire
## on the collapse or on the ruin heap (it lit one on 18% of collapses from the presentation RNG
## and two on every ruin heap, burning until the 30-fire cap evicted them).

const SETTLE_FRAMES := 60  # the ruin heap is due on the next frame; a second is ample


static func run(tree: SceneTree, check: Callable, rampage: Rampage) -> void:
	var sim := rampage.sim
	var city := rampage._city
	var index := _standing(sim)
	check.call(index >= 0, "a standing building off the kaiju's body to burn and bring down")
	if index < 0:
		return
	var b := sim.buildings[index]
	var cells := _alive(b)
	rampage._powers._coated({"building": index, "cells": cells, "kind": "beam"})
	var lit := _burning(city, b)
	check.call(lit > 0, "the beam's coat lights fires on the standing building (%d)" % lit)
	for c: Vector3i in cells:
		b.frame.remove(c)
	city.chunks_broken(index, cells, rampage._kaiju_at)
	for _i: int in SETTLE_FRAMES:
		await tree.process_frame
	var left := _burning(city, b)
	check.call(
		b.frame.alive_count == 0 and left == 0,
		(
			"a collapsed building is rubble with no fire on it %d frames later (%d burning, was %d)"
			% [SETTLE_FRAMES, left, lit]
		)
	)


## The standing building farthest from the kaiju (its body over none of it), or -1.
static func _standing(sim: RampageSim) -> int:
	var index := -1
	var far := -1.0
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if not b.in_arena or b.landmark != "" or b.frame.alive_count == 0 or sim.body.over(i):
			continue
		var d := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		if d > far:
			far = d
			index = i
	return index


static func _alive(b: RampageSim.Building) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for y: int in b.frame.h:
		for x: int in b.frame.w:
			for z: int in b.frame.d:
				if b.frame.alive(Vector3i(x, y, z)):
					cells.append(Vector3i(x, y, z))
	return cells


## Fires burning over the building's footprint (a fire that is going out does not count).
static func _burning(city: CityView, b: RampageSim.Building) -> int:
	var n := 0
	for node: Node in city.get_children():
		if not node is Fire or node.is_queued_for_deletion():
			continue
		if node.has_method("is_out") and node.call("is_out"):
			continue
		var at := (node as Fire).position
		if absf(at.x - b.x) <= b.w * 0.5 + 1.0 and absf(at.z - b.z) <= b.d * 0.5 + 1.0:
			n += 1
	return n
