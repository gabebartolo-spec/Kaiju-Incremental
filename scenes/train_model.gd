class_name TrainModel
extends RefCounted
## The railway's voxel models in the city's look (D-163): a metro car (a locomotive with a cab,
## windscreen and headlamps, or a carriage), and the viaduct with its station. Every surface carries
## detail: panel seams, a livery stripe, framed windows, doors and roof gear on the cars; seams,
## weathering streaks, sleepers, rails and parapets on the viaduct; the look's colour noise on
## top. Builders only (RailView owns the nodes). Sizes: tuning "rail"; colours: "rail_look".

const CAR_VOXEL := 0.125
const DECK_VOXEL := 0.25


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


## One deck span from z0 to z1 at track centre x (the lab's space is the world): a deck slab with
## parapets, ballast, sleepers and two rails per track (the bents under it are columns, below).
## last: the span ends the line, so its far end cell is drawn too (spans meet at a shared edge).
static func span(
	x: float, z0: float, z1: float, last: bool, cfg: Dictionary
) -> MultiMeshInstance3D:
	var vox := VoxelBuilder.new()
	var deck := roundi(Num.f(cfg["deck_y"]) / DECK_VOXEL)
	var half := roundi(Num.f(cfg["deck_width"]) * 0.5 / DECK_VOXEL)
	var cx := roundi(x / DECK_VOXEL)
	var tcell := roundi(Num.f(cfg["track_gap"]) * 0.5 / DECK_VOXEL)
	var end := roundi(z1 / DECK_VOXEL) + (1 if last else 0)
	for z: int in range(roundi(z0 / DECK_VOXEL), end):
		for dx: int in range(-half, half + 1):
			_deck_column(vox, Vector3i(cx + dx, deck, z), Vector3i(dx, half, tcell), z)
	return vox.build({}, DECK_VOXEL, 1.3, Vector3.ZERO)


## One column of a bent (a pillar part) at world x, z: from the ground up to under the deck, capped.
static func column(x: float, z: float, cfg: Dictionary) -> MultiMeshInstance3D:
	var vox := VoxelBuilder.new()
	var deck := roundi(Num.f(cfg["deck_y"]) / DECK_VOXEL)
	_bent(vox, Vector3i(roundi(x / DECK_VOXEL), deck, roundi(z / DECK_VOXEL)))
	return vox.build({}, DECK_VOXEL, 1.3, Vector3.ZERO)


## One across-the-deck column of cells at `top` (the deck's top cell): the slab (concrete with
## seams and streaks), parapets at the edges, ballast with sleepers and steel rails between.
## at: (dx across the deck, half its half width, the tracks' offset), in cells.
static func _deck_column(vox: VoxelBuilder, top: Vector3i, at: Vector3i, z: int) -> void:
	var dx := at.x
	var half := at.y
	var streak := absi(hash(Vector2i(dx, z / 3))) % 5 == 0
	var slab := _c("concrete").darkened(0.12 if streak else 0.0)
	if posmod(z, 16) == 0:
		slab = _c("seam_concrete")
	vox.put_color(top + Vector3i(0, -1, 0), slab)
	vox.put_color(top, slab)
	if absi(dx) == half:
		vox.put_color(top + Vector3i(0, 1, 0), _c("parapet"))
		vox.put_color(top + Vector3i(0, 2, 0), _c("parapet"))
		return
	var track := absi(absi(dx) - at.z)
	var sleeper := posmod(z, 3) == 0
	if track <= 1:
		var rail := track == 1
		vox.put_color(
			top + Vector3i(0, 1, 0),
			_c("rail") if rail else (_c("sleeper") if sleeper else _c("ballast"))
		)


## A column from the ground up to under the deck, with a cap.
static func _bent(vox: VoxelBuilder, top: Vector3i) -> void:
	for y: int in range(0, top.y - 1):
		var col := _c("column") if y % 6 != 0 else _c("seam_concrete")
		vox.put_color(Vector3i(top.x, y, top.z), col)
		vox.put_color(Vector3i(top.x, y, top.z + 1), col.darkened(0.08))
	for d: int in range(-1, 2):
		vox.put_color(Vector3i(top.x + d, top.y - 2, top.z), _c("parapet"))


## The station's middle cell on the deck's top, for its middle (x, z).
static func _station_at(mid: Vector2, cfg: Dictionary) -> Vector3i:
	var deck := roundi(Num.f(cfg["deck_y"]) / DECK_VOXEL)
	return Vector3i(roundi(mid.x / DECK_VOXEL), deck, roundi(mid.y / DECK_VOXEL))


## The station's size in cells: (deck half width, half length, platform width).
static func _station_size(length: float, cfg: Dictionary) -> Vector3i:
	return Vector3i(
		roundi(Num.f(cfg["deck_width"]) * 0.5 / DECK_VOXEL),
		roundi(length * 0.5 / DECK_VOXEL),
		roundi(Num.f(look()["platform"]) / DECK_VOXEL)
	)


## One platform segment of the station (a station part): `side`'s paving with a yellow edge by the
## track, its canopy and posts, from z0 to z1. The station's middle is at (x, z), `length` long.
static func platform(
	side: int, span_z: Vector2, mid: Vector2, length: float, cfg: Dictionary
) -> MultiMeshInstance3D:
	var vox := VoxelBuilder.new()
	var zr := Vector2i(roundi(span_z.x / DECK_VOXEL), roundi(span_z.y / DECK_VOXEL))
	_platform(vox, side, _station_at(mid, cfg), _station_size(length, cfg), zr)
	return vox.build({}, DECK_VOXEL, 1.3, Vector3.ZERO)


## One side's glowing sign under the canopy and its stairs down to the street (a stairs part).
static func stairs(side: int, mid: Vector2, length: float, cfg: Dictionary) -> MultiMeshInstance3D:
	var vox := VoxelBuilder.new()
	_sign_and_stairs(vox, side, _station_at(mid, cfg), _station_size(length, cfg))
	return vox.build({}, DECK_VOXEL, 1.3, Vector3.ZERO)


## One side's platform (paving with a yellow edge by the track), its canopy and posts, over the
## cell range `zr` (from, to exclusive). at: the station's middle on the deck's top; dims: (deck
## half width, half length, platform width).
static func _platform(
	vox: VoxelBuilder, side: int, at: Vector3i, dims: Vector3i, zr: Vector2i
) -> void:
	for zz: int in range(maxi(zr.x, at.z - dims.y), mini(zr.y, at.z + dims.y + 1)):
		for w: int in dims.z:
			var px := at.x + side * (dims.x + 1 + w)
			var pave := _c("platform") if posmod(zz + w, 4) != 0 else _c("seam_concrete")
			vox.put_color(Vector3i(px, at.y, zz), _c("platform_edge") if w == 0 else pave)
			var rib := posmod(zz, 5) == 0
			vox.put_color(Vector3i(px, at.y + 9, zz), _c("canopy_rib") if rib else _c("canopy"))
		if posmod(zz - at.z, 8) == 0:
			for y: int in range(at.y + 1, at.y + 9):
				vox.put_color(Vector3i(at.x + side * (dims.x + dims.z), y, zz), _c("column"))


## One side's glowing sign under the canopy and its stairs down to the street.
static func _sign_and_stairs(vox: VoxelBuilder, side: int, at: Vector3i, dims: Vector3i) -> void:
	var out := at.x + side * (dims.x + dims.z + 1)
	for y: int in range(at.y + 6, at.y + 8):
		for zz: int in range(at.z - 3, at.z + 4):
			vox.put_color(Vector3i(out, y, zz), Color(_c("sign"), 0.0))
	for step: int in at.y:
		for w: int in 3:
			vox.put_color(Vector3i(out + side * w, step, at.z + dims.y - step), _c("stair"))
