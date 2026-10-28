class_name SkylineRoofTank
extends RefCounted
## The rooftop tank on a far stand-in building (director 2026-10-27, D-352: the same mix as the
## playable buildings, one look across the game): about 3 roofs in 4 a white solar water heater
## (a white tank lying on its side over a dark panel on a silver frame), the rest a short wooden
## tower (a barrel taller than wide on legs, under a cap). Plain boxes; sizes are the voxel
## tank's cells over BuildingVoxels.RES, so a stand-in's tank is as big as a playable one's.

const WOOD := Color("6a5040")  # the barrel; the cap is a shade darker
const WHITE := Color("e6e8e4")  # the heater's tank (material "heater")
const GLASS := Color("1b2538")  # its panel (material "solar")
const CELL := 0.125  # one voxel cell in sim units (1 / BuildingVoxels.RES)


## The boxes of the tank standing at `base` (the middle of its foot on the roof): each is
## {"size": Vector3, "at": Vector3 centre, "color": Color}. `frame` colours the legs and frame.
static func boxes(base: Vector3, frame: Color) -> Array[Dictionary]:
	if RoofTank.wooden_at(base.x, base.z):
		return _tower(base, frame)
	return _heater(base, frame)


static func _tower(base: Vector3, frame: Color) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_part(base, Vector3(5, 3, 5), 0.0, frame))  # legs and platform
	out.append(_part(base, Vector3(5, 6, 5), 3.0, WOOD))  # the barrel
	out.append(_part(base, Vector3(7, 1, 7), 9.0, WOOD.darkened(0.25)))  # the cone roof's eave
	out.append(_part(base, Vector3(3, 2, 3), 10.0, WOOD.darkened(0.25)))  # and its point
	return out


static func _heater(base: Vector3, frame: Color) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_part(base, Vector3(9, 2, 7), 0.0, frame))  # the frame under the panel
	out.append(_part(base, Vector3(9, 2, 7), 2.0, GLASS))  # the dark panel
	out.append(_part(base + Vector3(0, 0, 3.0 * CELL), Vector3(7, 2, 2), 4.0, WHITE))  # the tank
	return out


## A box `size` cells across and `up` cells above the foot, as a stand-in's plain box.
static func _part(base: Vector3, size: Vector3, up: float, color: Color) -> Dictionary:
	var s := size * CELL
	return {"size": s, "at": base + Vector3(0, up * CELL + s.y * 0.5, 0), "color": color}
