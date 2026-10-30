class_name TrafficMeshes
extends RefCounted
## The voxel meshes of Traffic's cars (split out to keep files small): one per paint, and the
## police cruiser twice, its light bar lit red, then blue.

const LIGHT_GLOW := 2.5  # police light bars


static func palette() -> Dictionary:
	var palette := {
		"glass": Color("2b3640"),
		"wheel": Color("1a1a1a"),
		"ivory": Color("b8b2a0"),
		"tail": Color("6a1a1a"),
		"police": Color("d8d8d2"),
		"police_low": Color("1c1e22"),
		"bar": Color("2a2a2a"),
		"red": Color("4a1414"),
		"blue": Color("14204a"),
		"red_lit": Color(1.0, 0.12, 0.08, 0.0),
		"blue_lit": Color(0.15, 0.3, 1.0, 0.0),
	}
	var paints := CityDecor.car_colors()
	for i: int in paints.size():
		palette["car%d" % i] = paints[i]
	return palette


static func cars(palette: Dictionary) -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	for i: int in CityDecor.car_colors().size():
		var v := VoxelBuilder.new()
		v.salt = 40 + i
		CityDecor.car(v, "car%d" % i, false)
		out.append(_bake(v, palette))
	return out


static func police(palette: Dictionary) -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	for lit: int in 2:  # light bar: red lit, then blue lit
		var v := VoxelBuilder.new()
		v.salt = 50
		CityDecor.car(v, "police", false)
		v.repaint(
			func(cell: Vector3i, key: String) -> String:
				return "police_low" if key == "police" and cell.y == 0 else key
		)
		v.put(Vector3i(-1, 3, 0), "red_lit" if lit == 0 else "red")
		v.put(Vector3i(0, 3, 0), "bar")
		v.put(Vector3i(1, 3, 0), "blue" if lit == 0 else "blue_lit")
		out.append(_bake(v, palette))
	return out


static func _bake(v: VoxelBuilder, palette: Dictionary) -> ArrayMesh:
	# Car cells span z -3..2: shift half a cell so the car's middle sits on its position.
	var voxel := CityDecor.PROP_VOXEL
	v.detail = true  # the city's surface family (flat surfaces P3)
	return v.bake(palette, voxel, Vector3(0, 0, voxel * 0.5), LIGHT_GLOW)
