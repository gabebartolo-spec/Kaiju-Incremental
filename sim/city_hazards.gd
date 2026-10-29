class_name CityHazards
extends RefCounted
## The city's "red barrels" (director comments #19): a few low buildings in play become fuel
## silos, fireworks factories or chemical labs (cfg.hazards; Explosives sets them off). They sit
## toward the playable edge, the industrial fringe and the docks, never by the kaiju's rise from
## the river (spawn_clear), and keep min_spacing apart. Each keeps its lot's size: only
## entry["hazard"] is added. Pure: its own seeded numbers (map_seed and the stage), so every other
## building is drawn exactly as before.


## Adds the river's quay `sheds` (the docks, welcome however central) to `out` (CityGen.generate's
## buildings) and tags hazards in it for the stage in `cfg`.
static func tag(
	out: Array[Dictionary], plan: Dictionary, cfg: Dictionary, sheds: Array[Dictionary]
) -> void:
	var quay_from := out.size()
	out.append_array(sheds)
	var h: Dictionary = cfg.get("hazards", {})
	if h.is_empty():
		return
	var half := Num.f(cfg["half"])
	# The stage's own ring: a point just inside its edge.
	var ring := CityGen.district_of(Rect2(-half + 0.01, -half + 0.01, 0.0, 0.0), cfg)
	var counts: Array = h["count"]
	var want := Num.i(counts[mini(ring, counts.size() - 1)])
	var kinds: Array = h["kinds"]
	if want <= 0 or kinds.is_empty():
		return
	var spawn: Vector2 = plan.get("rise_spawn", Vector2(INF, INF))
	var edge := half * Num.f(h["edge_share"])
	var candidates: Array[int] = []
	for i: int in out.size():
		var e := out[i]
		var at := Vector2(Num.f(e["x"]), Num.f(e["z"]))
		if e.has("landmark") or e.has("model") or Num.i(e["h"]) > Num.i(h["max_height"]):
			continue
		if maxf(absf(at.x), absf(at.y)) > half:
			continue  # stands in play: a lot straddling the edge has its middle out of reach
		if maxf(absf(at.x), absf(at.y)) < edge and i < quay_from:
			continue
		if spawn.x != INF and at.distance_to(spawn) < Num.f(h["spawn_clear"]):
			continue
		candidates.append(i)
	var rng := Seeds.make("hazards", Num.i(cfg.get("map_seed", 0)) * 8 + ring)
	_shuffle(candidates, rng)
	var placed: Array[Vector2] = []
	var next := rng.randi_range(0, kinds.size() - 1)
	for i: int in candidates:
		if placed.size() >= want:
			break
		var at := Vector2(Num.f(out[i]["x"]), Num.f(out[i]["z"]))
		if placed.any(func(p: Vector2) -> bool: return p.distance_to(at) < Num.f(h["min_spacing"])):
			continue
		out[i]["hazard"] = str(kinds[next % kinds.size()])
		next += 1
		placed.append(at)


static func _shuffle(list: Array[int], rng: RandomNumberGenerator) -> void:
	for i: int in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := list[i]
		list[i] = list[j]
		list[j] = t
