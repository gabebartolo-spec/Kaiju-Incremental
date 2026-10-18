class_name CityRiver
extends RefCounted
## The river the kaiju rises from at the start of every run (D-083, director 2026-10-19: "a
## city caught unaware - have our reptilian emerge from a river to start each run"). It is the
## row of blocks just south of the first district's ring avenue, across the whole street grid,
## so it lies in the same place at every stage: past the young city's edge, then through the
## grown city. Its blocks hold water and no buildings; the streets across it are its bridges.
## Part of CityGen.map, split out to keep files small.


## Turns the river's row of blocks into "river" in `plan` (CityGen.map's) and records the
## river's band (z from, z to) as plan["river"] and the kaiju's rise point as
## plan["river_spawn"]: the middle of the river block nearest the city's north-south axis.
static func mark(plan: Dictionary, zs: Array[float], cfg: Dictionary) -> void:
	if not cfg.get("river", false):
		return
	var edge := CityGen.districts(cfg)[0]
	var row := -1
	for j: int in zs.size() - 1:
		if is_equal_approx(zs[j], edge):
			row = j
	if row < 0:
		return
	var band := Vector2(INF, -INF)
	var spawn := Vector2(INF, INF)
	for block: Dictionary in plan["blocks"]:
		if block.has("site") or not block.has("cell"):
			continue
		var cell: Vector2i = block["cell"]
		if cell.y != row:
			continue
		var rect: Rect2 = block["rect"]
		block["was"] = block["use"]  # CityGen.generate still draws its lots, and drops them
		block["use"] = "river"
		band = Vector2(minf(band.x, rect.position.y), maxf(band.y, rect.end.y))
		if absf(rect.get_center().x) < absf(spawn.x):
			spawn = rect.get_center()
	if spawn.x < INF:
		plan["river"] = band
		plan["river_spawn"] = spawn


## Where the kaiju rises in this city (CityGen.map's plan["river_spawn"]), or INF when the
## city has no river.
static func spawn(cfg: Dictionary) -> Vector2:
	var plan := CityGen.map(cfg)
	return plan.get("river_spawn", Vector2(INF, INF))
