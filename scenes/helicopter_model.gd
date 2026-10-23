class_name HelicopterModel
extends Node3D
## The attack helicopter (D-042): modelled in Blender (assets/source/vehicles/build_heli.py) and
## voxelized per part (tools/blender/voxelize_parts.py) at 2x real size, desert tan, facing -Z,
## the node's origin under the mast, level with the wheels. The main and tail rotors spin about
## their real hubs; the chin gun aims at aim()'s target and fire() returns its muzzle.
## Presentation only.

const BASE := "res://assets/vehicles/heli"
## Body tan, for wreck debris.
const TAN := Color("b89c6a")
## Below this sine of the angle to straight down, look_at() has no stable up: keep the last aim.
const MIN_TILT := 0.05

var _body: Node3D
var _main_rotor: Node3D
var _tail_rotor: Node3D
var _gun: Node3D
var _cfg: Dictionary
var _muzzle := Vector3.ZERO  # in the gun's space
var _shed := false  # the rotors have been sheared off (shed_rotors)


func _init() -> void:
	_cfg = Content.section("vehicles")
	var parts := VehicleParts.new(BASE, Num.f(_cfg["heli_height"]))
	var centre := parts.pivot("body") * Vector3(1, 0, 1)
	_body = parts.build("body", -centre, 5)
	add_child(_body)
	_main_rotor = parts.hinge("main_rotor", self, centre, 5)
	_tail_rotor = parts.hinge("tail_rotor", self, centre, 5)
	_gun = parts.hinge("gun", self, centre, 5)
	_muzzle = Vector3(0, 0, parts.front("gun") - parts.pivot("gun").z)


func _process(delta: float) -> void:
	if _shed:
		return
	_main_rotor.rotation.y += delta * Num.f(_cfg["main_rotor_spin"])
	_tail_rotor.rotation.x += delta * Num.f(_cfg["tail_rotor_spin"])


## Points the chin gun at `target` (world space).
func aim(target: Vector3) -> void:
	if not _gun.is_inside_tree():
		return
	var to := target - _gun.global_position
	if to.length() > 0.01 and Vector2(to.x, to.z).length() > to.length() * MIN_TILT:
		_gun.look_at(target)


## Where the chin gun's muzzle is now (world space): where a burst leaves.
func fire() -> Vector3:
	return _gun.to_global(_muzzle)


## Shears both rotors off the hull (a wreck's first blow) into `into`, world transforms kept, and
## returns [main, tail] to throw: a dying helicopter never turns a plus sign in the air.
func shed_rotors(into: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for part: Node3D in [_main_rotor, _tail_rotor]:
		var at := part.global_transform
		part.get_parent().remove_child(part)
		into.add_child(part)
		part.global_transform = at
		out.append(part)
	_shed = true
	return out


## Takes the body, both rotors and the gun off the helicopter into `into` (world transforms kept)
## and returns them (hull, main rotor, tail rotor, gun; null for a rotor already shed): a wreck's
## pieces to throw. The helicopter is left empty.
func break_up(into: Node3D) -> Array[Node3D]:
	VehicleParts.set_opacity(self, 1.0)  # it was fading as a screen door: pieces are solid
	var out: Array[Node3D] = []
	for part: Node3D in [_body, _main_rotor, _tail_rotor, _gun]:
		if _shed and (part == _main_rotor or part == _tail_rotor):
			out.append(null)  # already thrown (shed_rotors): the slot stays so the indices hold
			continue
		var at := part.global_transform
		part.get_parent().remove_child(part)
		into.add_child(part)
		part.global_transform = at
		out.append(part)
	set_process(false)
	return out
