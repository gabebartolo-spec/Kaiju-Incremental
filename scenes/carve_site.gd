class_name CarveSite
extends RefCounted
## One carved building as the physics view sees it: where its fine grid sits in the world, its
## size in cells and its colours by material id. The sim owns the grid (one byte per cell, 0
## empty, x fastest then z then y, RES cells per sim unit); the view only reads it.

var key: int
var origin: Vector3  # world position of cell (0, 0, 0)'s lower corner
var size: Vector3i  # cells along x, y, z
var res: int
var palette: Dictionary = {}  # material id (int) -> Color; missing ids use the fallback
var fallback := Color("9a948a")


func _init(p_key: int, p_origin: Vector3, p_size: Vector3i, p_res: int) -> void:
	key = p_key
	origin = p_origin
	size = p_size
	res = p_res


## The palette from data (tuning "carve_physics"): ids as strings, colours as hex.
func use_palette(cfg: Dictionary) -> void:
	var colors: Dictionary = cfg.get("colors", {})
	for id: String in colors:
		palette[id.to_int()] = Color(str(colors[id]))
	fallback = Color(str(cfg.get("color_fallback", "9a948a")))


func cell(i: int) -> Vector3i:
	var plan := size.x * size.z
	@warning_ignore("integer_division")
	return Vector3i(i % size.x, i / plan, (i / size.x) % size.z)


func index(c: Vector3i) -> int:
	return c.x + c.z * size.x + c.y * size.x * size.z


func inside(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < size.x and c.y < size.y and c.z < size.z


func count() -> int:
	return size.x * size.y * size.z


## World centre of a cell.
func world(c: Vector3i) -> Vector3:
	return origin + (Vector3(c) + Vector3.ONE * 0.5) / res


## A point in grid space (cells, as the sim's pivot) in the world.
func to_world(p: Vector3) -> Vector3:
	return origin + p / res


func color(m: int) -> Color:
	var out: Color = palette.get(m, fallback)
	return out


## The cells of a settle event as indices: the sim may hand cell indices or Vector3i cells.
func indices(cells: Variant) -> PackedInt32Array:
	if cells is PackedInt32Array:
		return cells
	var out := PackedInt32Array()
	var list: Array = cells
	for c: Vector3i in list:
		out.append(index(c))
	return out
