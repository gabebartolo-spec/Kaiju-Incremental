class_name CityGreenLots
extends RefCounted
## Green lots (D-075, director 2026-10-18: green lots at 8% of the city, answering D-065(b)):
## one block in city.green_lot_every [a, b] becomes a park, a lattice on the street grid (every
## a-th long block across, every b-th short block down, the rows staggered by half between
## columns), so parks spread evenly and no building stands far from one. [3, 4] greens one block
## in 12 (8.3%). Part of CityGen.map, split out to keep files small.
##
## The lattice reads only the street grid (which spans every district at every stage), never the
## stage's playable edge or its landmarks, so a block is green at every stage alike: an evolution
## never turns a park back into buildings. No RNG.


## Turns blocks green in `plan` (CityGen.map's): each keeps the use it had under "green" and
## becomes a "park", which the ground, the decor and the greenery already dress.
static func choose(plan: Dictionary, cfg: Dictionary) -> void:
	var every: Array = cfg.get("green_lot_every", [])
	if every.size() < 2:
		return
	var across := Num.i(every[0])
	var down := Num.i(every[1])
	var last := CityGen.districts(cfg).size()
	for block: Dictionary in plan["blocks"]:
		var use := str(block["use"])
		if block.has("site") or not (use == "built" or use == "outer"):
			continue  # a landmark's site, a park or plaza already, or a parking lot
		if Num.i(block["district"]) >= last or not block.has("cell"):
			continue
		var rect: Rect2 = block["rect"]
		var cell: Vector2i = block["cell"]
		var column := floori(float(cell.x) / across)
		var row := cell.y + (down >> 1) * (column & 1)  # stagger every other column by half
		if posmod(cell.x, across) == across >> 1 and posmod(row, down) == down >> 1:
			if minf(rect.size.x, rect.size.y) >= CityLots.MIN_SIDE:
				block["green"] = use
				block["use"] = "park"
