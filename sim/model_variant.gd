class_name ModelVariant
extends RefCounted
## A placed copy of a pool building (data/city_buildings.json, D-256): its baked model turned by
## `facing` quarter turns, mirrored across x when `mirror`, and `stretch` floors taller (the row's
## stretch_floor repeated). Cells are building-local (RES cells per sim unit, as the bake wrote
## them); the same mapping serves the sim's grid (LandmarkCells) and the view (LandmarkVoxels), so
## the two never drift apart. Pure: no scene, no RNG.

## A face's bit (bake.py STEPS: -x, +x, +y, -y, -z, +z) after a mirror across x, and after one
## quarter turn (x, z) -> (d - 1 - z, x): -x faces -z, +x faces +z, -z faces +x, +z faces -x.
const MIRROR_BIT: Array[int] = [1, 0, 2, 3, 4, 5]
const TURN_BIT: Array[int] = [4, 5, 2, 3, 1, 0]


## The pool row of model `id` (data/city_buildings.json), or {}.
static func row_of(id: String) -> Dictionary:
	var pool: Dictionary = Content.city_buildings().get("pool", {})
	var row: Dictionary = pool.get(id, {})
	return row


## The variant of a layout entry: {"facing", "mirror", "stretch"} (defaults for a bare model).
static func of(entry: Dictionary) -> Dictionary:
	return {
		"facing": posmod(Num.i(entry.get("facing", 0)), 4),
		"mirror": entry.get("mirror", false) == true,
		"stretch": maxi(0, Num.i(entry.get("stretch", 0))),
	}


## Footprint and floors of the placed copy: Vector3i(w, h, d) in sim units.
static func size(row: Dictionary, v: Dictionary) -> Vector3i:
	var w := Num.i(row["w"])
	var d := Num.i(row["d"])
	var h := Num.i(row["h"]) + stretch_of(row, v)
	return Vector3i(d, h, w) if Num.i(v["facing"]) % 2 == 1 else Vector3i(w, h, d)


## The floors the copy really adds: none when the model has no floor that repeats.
static func stretch_of(row: Dictionary, v: Dictionary) -> int:
	return Num.i(v["stretch"]) if Num.i(row.get("stretch_floor", -1)) >= 0 else 0


## Maps baked cells (x, y, z triples) to the copy's: {"xyz": PackedInt32Array, "src": the baked
## cell index each output cell came from (a stretched floor's cells appear once per copy)}.
static func cells(xyz: PackedInt32Array, row: Dictionary, v: Dictionary, res: int) -> Dictionary:
	var w := Num.i(row["w"]) * res
	var d := Num.i(row["d"]) * res
	var extra := stretch_of(row, v)
	var band_lo := Num.i(row.get("stretch_floor", -1)) * res
	var band_hi := band_lo + res
	var out := PackedInt32Array()
	var src := PackedInt32Array()
	for i: int in xyz.size() / 3:
		var c := Vector3i(xyz[i * 3], xyz[i * 3 + 1], xyz[i * 3 + 2])
		var copies := 1
		if extra > 0:
			if c.y >= band_hi:
				c.y += extra * res
			elif c.y >= band_lo:
				copies += extra
		for k: int in copies:
			var p := place(Vector3i(c.x, c.y + k * res, c.z), w, d, v)
			out.append_array(PackedInt32Array([p.x, p.y, p.z]))
			src.append(i)
	return {"xyz": out, "src": src}


## One cell (already stretched) through the mirror and the quarter turns; w, d in cells.
static func place(c: Vector3i, w: int, d: int, v: Dictionary) -> Vector3i:
	var p := c
	if v["mirror"] == true:
		p.x = w - 1 - p.x
	var cw := w
	var cd := d
	for _t: int in Num.i(v["facing"]):
		p = Vector3i(cd - 1 - p.z, p.y, p.x)
		var keep := cw
		cw = cd
		cd = keep
	return p


## A cell's open-face bits through the same mirror and turns.
static func flags(m: int, v: Dictionary) -> int:
	var out := m
	if v["mirror"] == true:
		out = _remap(out, MIRROR_BIT)
	for _t: int in Num.i(v["facing"]):
		out = _remap(out, TURN_BIT)
	return out


## The copy's structural chunks, one string per floor (x fastest, then z), as the bake writes them.
static func chunks(row: Dictionary, v: Dictionary) -> Array:
	var w := Num.i(row["w"])
	var d := Num.i(row["d"])
	var layers: Array = row["chunks"]
	var extra := stretch_of(row, v)
	var band := Num.i(row.get("stretch_floor", -1))
	var floors: Array[String] = []
	for y: int in layers.size():
		floors.append(str(layers[y]))
		if y == band:
			for _k: int in extra:
				floors.append(str(layers[y]))
	var dims := size(row, v)
	var out: Array = []
	for layer: String in floors:
		var cells_out := PackedByteArray()
		cells_out.resize(dims.x * dims.z)
		cells_out.fill(48)  # "0"
		for z: int in d:
			for x: int in w:
				if layer[z * w + x] == "1":
					var p := place(Vector3i(x, 0, z), w, d, v)
					cells_out[p.z * dims.x + p.x] = 49  # "1"
		out.append(cells_out.get_string_from_ascii())
	return out


static func _remap(m: int, to: Array[int]) -> int:
	var out := 0
	for k: int in 6:
		if m & (1 << k):
			out |= 1 << to[k]
	return out
