class_name TankModel
extends Node3D
## A voxel main battle tank, about 2.4 units long, facing -Z: tracks with road wheels, a sloped
## hull, a turret with hatch and a long barrel. Presentation only.

const VOXEL := 0.2
const PALETTE := {
	"hull": Color("5b6440"),
	"hull_dark": Color("454c31"),
	"track": Color("26261f"),
	"wheel": Color("3a3a32"),
	"turret": Color("66704a"),
	"barrel": Color("3a4028"),
	"hatch": Color("4c5436"),
	"star": Color("c8c2a8"),
}


func _init() -> void:
	var v := VoxelBuilder.new()
	for side: int in [-1, 1]:  # tracks with road wheels
		var x := side * 4
		v.box(Vector3i(x, 0, -6), Vector3i(x + side, 2, 5), "track")
		for z: int in range(-5, 5, 2):
			v.put(Vector3i(x + side * 2, 1, z), "wheel")
	v.box(Vector3i(-3, 1, -6), Vector3i(3, 3, 5), "hull")  # hull
	v.box(Vector3i(-3, 3, -6), Vector3i(3, 3, -5), "hull_dark")  # sloped glacis
	v.box(Vector3i(-4, 4, -4), Vector3i(4, 4, 5), "hull_dark")  # deck
	v.box(Vector3i(-2, 5, -2), Vector3i(2, 6, 3), "turret")  # turret
	v.box(Vector3i(-1, 7, 0), Vector3i(0, 7, 1), "hatch")
	v.put(Vector3i(2, 6, 1), "star")
	v.box(Vector3i(0, 5, -3), Vector3i(0, 5, -11), "barrel")  # barrel
	v.put(Vector3i(0, 5, -12), "hull_dark")  # muzzle
	v.salt = 3
	add_child(v.build(PALETTE, VOXEL, 0.0, Vector3.ZERO))
