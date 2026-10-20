class_name GlassFrame
extends RefCounted
## A glass building's structural frame (D-094 WP3). Its curtain wall is all fixtures, which carry
## nothing, so columns one cell inside the glass (at each corner and every column_bay cells,
## ground to roof) and a beam behind the transom row ground the slabs, the roof and the
## transoms through structure. One layout for BuildingCells and BuildingVoxels.

const SIDES: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]


## Building-local cell -> material name ("pillar" or "frame") for a w x d cell footprint, h cells
## tall, res cells per floor.
static func cells(w: int, d: int, h: int, res: int) -> Dictionary:
	var bay := maxi(1, Num.i(Content.section("destruction").get("column_bay", 0)))
	var out := {}
	for side: Vector2i in SIDES:
		var length := d if side.x != 0 else w
		for p: int in range(1, length - 1):
			var column := p == 1 or p == length - 2 or p % bay == 0
			for y: int in h:
				if column or (y >= res and y % res == 4):
					var cell := Vector3i(1, y, p)  # layer 1 of the -x face
					if side.x > 0:
						cell = Vector3i(w - 2, y, p)
					elif side.y < 0:
						cell = Vector3i(p, y, 1)
					elif side.y > 0:
						cell = Vector3i(p, y, d - 2)
					out[cell] = "pillar" if column else "frame"
	return out
