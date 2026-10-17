class_name HelicopterModel
extends Node3D
## A placeholder voxel attack helicopter, about 3 units long, facing -Z: cabin, tail boom,
## skids and a spinning main rotor. The real Tripo model replaces it later (D-037).
## Presentation only.

const VOXEL := 0.2
const PALETTE := {
	"body": Color("4f5a3a"),
	"dark": Color("343b27"),
	"glass": Color("9fc4d0"),
	"skid": Color("26261f"),
	"rotor": Color("1e1e1a"),
}

var _rotor: Node3D


func _init() -> void:
	var v := VoxelBuilder.new()
	v.box(Vector3i(-2, 0, -5), Vector3i(2, 3, 2), "body")  # cabin
	v.box(Vector3i(-1, 2, -7), Vector3i(1, 3, -6), "glass")  # canopy
	v.box(Vector3i(-1, 1, -6), Vector3i(1, 1, -6), "dark")  # chin gun
	v.box(Vector3i(0, 2, 3), Vector3i(0, 3, 12), "dark")  # tail boom
	v.box(Vector3i(0, 3, 11), Vector3i(0, 6, 12), "body")  # fin
	for side: int in [-1, 1]:  # skids
		v.box(Vector3i(side * 3, -2, -4), Vector3i(side * 3, -2, 2), "skid")
		v.put(Vector3i(side * 2, -1, -2), "skid")
		v.put(Vector3i(side * 2, -1, 1), "skid")
	v.box(Vector3i(0, 4, -1), Vector3i(0, 4, 0), "dark")  # mast
	v.salt = 5
	add_child(v.build(PALETTE, VOXEL, 0.0, Vector3.ZERO))
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 1.05, -0.1)
	add_child(_rotor)
	var blades := VoxelBuilder.new()
	blades.box(Vector3i(-12, 0, 0), Vector3i(12, 0, 0), "rotor")
	blades.box(Vector3i(0, 0, -12), Vector3i(0, 0, 12), "rotor")
	_rotor.add_child(blades.build(PALETTE, VOXEL, 0.0, Vector3.ZERO))


func _process(delta: float) -> void:
	_rotor.rotation.y += delta * 28.0
