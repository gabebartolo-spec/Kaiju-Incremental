class_name CoatWear
extends RefCounted
## The coatings (beam fire, ink: SpeciesPowers.coats) eat what they cover each step, and wear off
## when their time runs out or the chunk is gone. Part of SpeciesPowers; split out to keep files
## small. Pure.


## One step of every coat in `coats` (SpeciesPowers.coats, edited in place) over `dt` seconds.
static func step(sim: RampageSim, coats: Dictionary, dt: float) -> void:
	if coats.is_empty():
		return
	var by_building: Dictionary = {}
	var done: Array[int] = []
	for key: int in coats:
		var entry: Dictionary = coats[key]
		var b := sim.buildings[Num.i(entry["b"])]
		var c: Vector3i = entry["c"]
		entry["t"] = Num.f(entry["t"]) - dt
		if Num.f(entry["t"]) <= 0.0 or not b.frame.alive(c):
			done.append(key)
			continue
		var list: Array = by_building.get(entry["b"], [])
		list.append(entry)
		by_building[entry["b"]] = list
	for key: int in done:
		coats.erase(key)
	for index: int in by_building:
		var cells: Array[Vector3i] = []
		var amounts := PackedFloat32Array()
		for entry: Dictionary in by_building[index]:
			cells.append(entry["c"])
			amounts.append(Num.f(entry["dps"]) * dt)
		sim.damage_cells(index, cells, amounts)
