class_name Structures
extends RefCounted
## Every structure in the play area, in one list (standing rule since 2026-10-20, roadmap
## 2026-10-20-build2-playtest #6: "ALL buildings in the play area must be destroyable"; the
## director 2026-10-25 on the railway: "Yes, all of it"). The city's buildings are listed here;
## any other system that puts structures in the world declares `func structures() -> Array[Dictionary]`
## (each {id, kind, pos: Vector2, alive}) and `func destroy_structure(id: int) -> bool` (it breaks the
## structure through the same path a blow does) and is held, directly or through another part, by
## the sim: sources() finds it by walking the sim's parts, with no list to keep. tests/run_structures_tests.gd
## fails a part that declares structures() and is not reached, and any listed structure inside the
## arena that cannot be destroyed. Pure.

const BUILDINGS := "buildings"


## The parts under `sim` that declare structures(), each once.
static func sources(sim: RampageSim) -> Array[Object]:
	var out: Array[Object] = []
	_walk(sim, {}, out)
	return out


static func _walk(part: RefCounted, seen: Dictionary, out: Array[Object]) -> void:
	seen[part.get_instance_id()] = true
	for prop: Dictionary in part.get_property_list():
		var usage: int = prop["usage"]
		if prop["type"] != TYPE_OBJECT or usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var value: Variant = part.get(str(prop["name"]))
		if not value is RefCounted:
			continue
		var next: RefCounted = value
		if seen.has(next.get_instance_id()):
			continue
		if next.has_method("structures"):
			out.append(next)
		_walk(next, seen, out)


## Every structure: {source, id, kind, pos, alive}. The city's buildings first, then each part's.
static func all(sim: RampageSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		out.append(
			{
				"source": BUILDINGS,
				"id": i,
				"kind": "building",
				"pos": Vector2(b.x, b.z),
				"alive": b.frame.alive_count > 0,
			}
		)
	for src: Object in sources(sim):
		var list: Array = src.call("structures")
		for entry: Dictionary in list:
			var e := entry.duplicate()
			e["source"] = src.get_script().resource_path
			out.append(e)
	return out


## Whether the structure stands inside the play area (a building the arena counts; others by
## where they stand).
static func in_play_area(sim: RampageSim, entry: Dictionary) -> bool:
	if str(entry["source"]) == BUILDINGS:
		return sim.buildings[Num.i(entry["id"])].in_arena
	var pos: Vector2 = entry["pos"]
	return absf(pos.x) <= sim.arena_half and absf(pos.y) <= sim.arena_half


## Destroys a structure through its own break path; returns whether it is gone.
static func destroy(sim: RampageSim, entry: Dictionary) -> bool:
	if str(entry["source"]) != BUILDINGS:
		for src: Object in sources(sim):
			if src.get_script().resource_path == str(entry["source"]):
				var gone: bool = src.call("destroy_structure", Num.i(entry["id"]))
				return gone
		return false
	var index := Num.i(entry["id"])
	var b := sim.buildings[index]
	var cells: Array[Vector3i] = []
	for x: int in b.w:
		for z: int in b.d:
			for y: int in b.height:
				var c := Vector3i(x, y, z)
				if b.frame.alive(c):
					cells.append(c)
	sim.damage_chunks(index, cells, INF)
	return b.frame.alive_count == 0


## Whether the structure still stands (read afresh from the sim).
static func alive(sim: RampageSim, entry: Dictionary) -> bool:
	if str(entry["source"]) == BUILDINGS:
		return sim.buildings[Num.i(entry["id"])].frame.alive_count > 0
	for src: Object in sources(sim):
		if src.get_script().resource_path != str(entry["source"]):
			continue
		var list: Array = src.call("structures")
		var now: Dictionary = list[Num.i(entry["id"])]
		var up: bool = now["alive"]
		return up
	return false
