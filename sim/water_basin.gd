extends RefCounted
## One body of water for WaterSim (the bay, the river): a grid of columns, each a bed, its water,
## the kaiju's body standing in it and four outflows.

var origin: Vector2  # world (x, z) of cell (0, 0)'s corner
var cell := 1.0
var nx := 0
var nz := 0
var rest := 0.0  # the still surface (world y)
var floor_y := PackedFloat32Array()  # each column's bed (world y)
var depth := PackedFloat32Array()  # its water (m)
var body := PackedFloat32Array()  # metres of the kaiju's body standing in it
var flow := PackedFloat32Array()  # 4 per column: outflow right, left, down (+z), up (-z), m^2/s
var active := Rect2i()  # the stepped columns (empty: all at rest)
var open := false  # row 0 is open sea (the bay's mouth): a wave runs out of it


func _init(p_origin: Vector2, p_cell: float, p_n: Vector2i, p_rest: float) -> void:
	origin = p_origin
	cell = p_cell
	nx = p_n.x
	nz = p_n.y
	rest = p_rest
	floor_y.resize(nx * nz)
	depth.resize(nx * nz)
	body.resize(nx * nz)
	flow.resize(nx * nz * 4)


## The surface's height over the still water at column k (under the bed when dry).
func lift(k: int) -> float:
	return floor_y[k] + depth[k] + body[k] - rest


func at(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell), floori((p.y - origin.y) / cell))


func centre(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func size() -> Vector2:
	return Vector2(nx, nz) * cell


func wake(rect: Rect2i) -> void:
	var r := rect.intersection(Rect2i(0, 0, nx, nz))
	if r.has_area():
		active = r if not active.has_area() else active.merge(r)
