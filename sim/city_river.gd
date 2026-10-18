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
## plan["river_spawn"]: on the city's north-south axis (x 0), in the river block across it or
## the nearest one, at least SPAWN_INSET in from its ends.
const SPAWN_INSET := 2.0


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
	var off := INF  # how far the chosen block lies from the axis
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
		var gap := absf(clampf(0.0, rect.position.x, rect.end.x))
		if gap < off:
			off = gap
			var x := clampf(0.0, rect.position.x + SPAWN_INSET, rect.end.x - SPAWN_INSET)
			spawn = Vector2(x, rect.get_center().y)
	if spawn.x < INF:
		plan["river"] = band
		plan["river_spawn"] = spawn


## How far south the playable city reaches (z): past the river and the row of blocks beyond
## it, so the kaiju rises with real, breakable buildings on both banks and the skyline's
## stand-ins start out of the game camera's view (lead, playtest 2026-10-19: "smaller
## buildings south of the spawn position dont seem destructible"). Without a river, or once
## the city has grown past both rows: the city's half-extent.
static func south(zs: Array[float], cfg: Dictionary) -> float:
	var half := CityGen.half_extent(cfg)
	if not cfg.get("river", false):
		return half
	var edge := CityGen.districts(cfg)[0]
	for j: int in zs.size() - 2:
		if is_equal_approx(zs[j], edge):
			return maxf(half, zs[j + 2])
	return half
