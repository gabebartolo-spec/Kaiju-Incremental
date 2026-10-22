class_name HazardVoxels
extends BuildingVoxels
## A red-barrel site's voxels (director comments #19): HazardShape's model (fuel silo, fireworks
## factory, chem lab) in place of a generated facade, on the same grid, so BuildingMesher draws and
## breaks it chunk by chunk like any building and the carved grid (HazardCells) is the same cells.
## A face is drawn where a voxel meets the open air outside the model (found by flooding the air in
## from the model's box), never inside a tank or a shed, so a standing site costs its skin only.
## The hazard colours are fixed (bright warning paint reads in any light); lamps, the chem glow and
## the sign's starbursts glow at night like lit windows (alpha 0).

const COLORS := {
	"hz_pad": Color("8d8b85"),
	"hz_steel": Color("d9d7cf"),
	"hz_yellow": Color("f2c21b"),
	"hz_black": Color("222224"),
	"hz_red": Color("c8312a"),
	"hz_lamp": Color(1.0, 0.18, 0.12, 0.0),
	"hz_brick": Color("7a3b2e"),
	"hz_blue": Color("2f62c9"),
	"hz_green": Color("3fae49"),
	"hz_white": Color("e6e9e3"),
	"hz_glow": Color(0.42, 1.0, 0.36, 0.0),
	"hz_drum": Color("2d5ca3"),
}

var _faces: Dictionary = {}


func _init(p_building: RampageSim.Building, base: Color) -> void:
	super(p_building, base, {}, false)
	for key: String in COLORS:
		palette[key] = COLORS[key]
	var shape := HazardShape.cells(b, RES)
	for cell: Vector3i in shape:
		vox.put(cell, str(shape[cell]))
	_faces = open_faces(vox.cells)


func face_mask(cell: Vector3i) -> int:
	return Num.i(_faces.get(cell, 0))


## Cell -> the faces (one bit per BuildingMesher.NEIGHBOURS entry) that meet outside air: air
## reached by a flood from the edge of the cells' box (one cell of margin), never the ground.
static func open_faces(cells: Dictionary) -> Dictionary:
	var air := _outside_air(cells)
	var out := {}
	for c: Vector3i in cells:
		var mask := 0
		for k: int in BuildingMesher.NEIGHBOURS.size():
			if air.has(c + BuildingMesher.NEIGHBOURS[k]):
				mask |= 1 << k
		if mask != 0:
			out[c] = mask
	return out


## The air cells (a set) a flood reaches from the corner of the cells' box plus one cell of margin.
static func _outside_air(cells: Dictionary) -> Dictionary:
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := -lo
	for c: Vector3i in cells:
		lo = lo.min(c)
		hi = hi.max(c)
	lo -= Vector3i.ONE
	hi += Vector3i.ONE
	lo.y = maxi(lo.y, 0)
	var air := {lo: true}
	var todo: Array[Vector3i] = [lo]
	while not todo.is_empty():
		var c: Vector3i = todo.pop_back()
		for d: Vector3i in BuildingMesher.NEIGHBOURS:
			var n := c + d
			if n.clamp(lo, hi) != n or air.has(n) or cells.has(n):
				continue
			air[n] = true
			todo.append(n)
	return air
