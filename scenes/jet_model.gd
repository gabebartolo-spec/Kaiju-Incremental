class_name JetModel
extends Node3D
## A military jet (D-072): modelled in Blender (assets/source/vehicles/build_jets.py) and
## voxelized by tools/blender/vox_jet.py at 2x real size (D-042), desert tan, facing -Z, the
## node's origin under its body. One part, nothing moves on it; nose() is where its guns fire
## from. Presentation only.

const BASE := "res://assets/vehicles/jet_"
## Body tan, for wreck debris.
const TAN := Color("b89c6a")

var _nose := Vector3.ZERO


## `kind` names its voxels (jet_<kind>.parts.json) and its drawn height (vehicles.jet_heights).
func _init(kind: String) -> void:
	var heights: Dictionary = Content.section("vehicles")["jet_heights"]
	var height := Num.f(heights[kind])
	var parts := VehicleParts.new(BASE + kind, height)
	var centre := parts.pivot("body") * Vector3(1, 0, 1)
	add_child(parts.build("body", -centre, 7))
	_nose = Vector3(0, height * 0.4, parts.front("body") - centre.z)


## Where its guns are now (world space): where a burst leaves.
func nose() -> Vector3:
	return to_global(_nose)
