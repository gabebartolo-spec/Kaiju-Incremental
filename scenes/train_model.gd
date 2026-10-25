class_name TrainModel
extends RefCounted
## The trains' voxel models in the city's look (D-163): a metro car (a locomotive with a cab,
## windscreen and headlamps, or a carriage). Every surface carries detail: panel seams, a livery
## stripe, framed windows, doors and roof gear; the look's colour noise on top. The viaduct and
## station are city buildings (RailLayout, RailVoxels). Builders only (RailView owns the nodes).
## Sizes: tuning "rail"; colours: "rail_look".

const CAR_VOXEL := 0.125


static func look() -> Dictionary:
	return Content.section("rail_look")


static func _c(key: String) -> Color:
	var colors: Dictionary = look()["colors"]
	return Color(str(colors[key]))


## One car, centred on its middle at its floor, facing +z: a box body with detail.
static func car(loco: bool, length: float) -> MultiMeshInstance3D:
	var vox := VoxelBuilder.new()
	var nl := roundi(length / CAR_VOXEL)
	var size: Array = look()["car_size"]
	var nw := roundi(Num.f(size[0]) / CAR_VOXEL)
	var nh := roundi(Num.f(size[1]) / CAR_VOXEL)
	for z: int in nl:
		for y: int in nh:
			for x: int in nw:
				var edge := x == 0 or x == nw - 1 or y == 0 or y == nh - 1 or z == 0 or z == nl - 1
				if edge:
					vox.put_color(
						Vector3i(x - nw / 2, y + 2, z - nl / 2),
						_car_cell(x, y, z, nw, nh, nl, loco)
					)
	_bogies(vox, nw, nl)
	return vox.build({}, CAR_VOXEL, 1.3, Vector3.ZERO)


## A car body cell: the roof, the window band (framed glass), the livery stripe under it, doors,
## the skirt; a locomotive's front is its cab with a windscreen and two glowing headlamps.
static func _car_cell(x: int, y: int, z: int, nw: int, nh: int, nl: int, loco: bool) -> Color:
	if y == nh - 1:
		return _c("roof") if (x + z) % 7 != 0 else _c("roof_gear")
	if loco and z == nl - 1:
		return _cab_cell(x, y, nw, nh)
	return _side_cell(y, z, nh)


## A side or end cell: the window band, doors, the livery stripe, the skirt, panel seams.
static func _side_cell(y: int, z: int, nh: int) -> Color:
	var door := posmod(z, 16) in [6, 7, 8, 9]
	if door and y >= 2 and y <= nh - 2:
		return _c("door") if posmod(z, 16) in [7, 8] else _c("door_frame")
	if y >= nh - 5 and y <= nh - 2:
		return _c("glass") if posmod(z, 6) != 0 else _c("body")
	if y == nh - 6 or y == nh - 7:
		return _c("stripe")
	if y <= 1:
		return _c("skirt")
	return _c("body") if posmod(z, 10) != 0 else _c("seam")


static func _cab_cell(x: int, y: int, nw: int, nh: int) -> Color:
	if y >= nh - 5 and y <= nh - 2 and x > 0 and x < nw - 1:
		return _c("glass")
	if y == 3 and (x == 1 or x == nw - 2):
		return Color(_c("headlamp"), 0.0)
	return _c("stripe") if y == nh - 6 or y == nh - 7 else _c("body")


## Two dark bogies under the car with wheels.
static func _bogies(vox: VoxelBuilder, nw: int, nl: int) -> void:
	for centre: int in [-nl / 3, nl / 3]:
		for z: int in range(centre - 4, centre + 5):
			for x: int in range(-nw / 2 + 1, nw / 2 - 1):
				var wheel := (
					(z == centre - 3 or z == centre + 3) and (x == -nw / 2 + 1 or x == nw / 2 - 2)
				)
				vox.put_color(Vector3i(x, 1, z), _c("wheel") if wheel else _c("bogie"))
				if wheel:
					vox.put_color(Vector3i(x, 0, z), _c("wheel"))
