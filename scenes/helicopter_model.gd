class_name HelicopterModel
extends Node3D
## The attack helicopter (D-297, D-309): a Tripo model cut into body, rotors and chin gun
## (assets/vehicles/heli*), voxelized per part with the texture's own colours, facing -Z, the node's
## origin under the mast, level with the wheels. The main and tail rotors spin about their real
## hubs; the chin gun aims at aim()'s target and fire() returns its muzzle. The leader's helicopter
## is its own white-and-gold model (VIP_BASE). Presentation only.

const BASE := "res://assets/vehicles/heli"
## The leader's helicopter (D-149): its own Tripo model, white with gold trim.
const VIP_BASE := "res://assets/vehicles/vip_heli"
## Body tan (the model's mean colour), for wreck debris.
const TAN := Color("816847")
## Below this sine of the angle to straight down, look_at() has no stable up: keep the last aim.
const MIN_TILT := 0.05

var _body: Node3D
var _main_rotor: Node3D
var _tail_rotor: Node3D
var _gun: Node3D
var _cfg: Dictionary
var _muzzle := Vector3.ZERO  # in the gun's space
var _strobe: Node3D  # the white anti-collision flash
var _clock := 0.0


## A new model, already in `parent`.
static func added_to(parent: Node) -> HelicopterModel:
	var heli := HelicopterModel.new()
	parent.add_child(heli)
	return heli


## Builds both models' voxels once now (the gunship's and the leader's own), so a first spawn
## reuses them.
static func warm() -> void:
	HelicopterModel.new().free()
	HelicopterModel.new(VIP_BASE).free()


## `base` is the parts file's path without ".parts.json": BASE for a gunship, VIP_BASE for the
## leader.
func _init(base := BASE) -> void:
	_cfg = Content.section("vehicles")
	var parts := VehicleParts.new(base, Num.f(_cfg["heli_height"]))
	var centre := parts.pivot("body") * Vector3(1, 0, 1)
	_body = parts.build("body", -centre, 5)
	add_child(_body)
	_main_rotor = parts.hinge("main_rotor", self, centre, 5)
	_tail_rotor = parts.hinge("tail_rotor", self, centre, 5)
	_gun = parts.hinge("gun", self, centre, 5)
	_muzzle = Vector3(0, 0, parts.front("gun") - parts.pivot("gun").z)
	_clock = float(get_instance_id() % 997) * 0.37  # each helicopter flashes on its own beat
	_add_lights((_body as MultiMeshInstance3D).get_aabb())
	for part: Node in find_children("*", "MultiMeshInstance3D", true, false):
		var mat := (part as MultiMeshInstance3D).material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("self_light", Num.f(_cfg["heli_lights"]["self_light"]))


func _process(delta: float) -> void:
	_clock += delta
	var lights: Dictionary = _cfg["heli_lights"]
	_strobe.visible = fposmod(_clock, Num.f(lights["strobe_period"])) < Num.f(lights["strobe_on"])
	_main_rotor.rotation.y += delta * Num.f(_cfg["main_rotor_spin"])
	_tail_rotor.rotation.x += delta * Num.f(_cfg["tail_rotor_spin"])


## Night flying lights: a red lamp on the left and a green on the right, a white strobe on the tail
## and a faint pale lamp under the belly, so the silhouette reads against the lit windows. Emissive
## spheres only (the city's real lights are pooled for gl_compatibility), `body` is the hull's box.
func _add_lights(body: AABB) -> void:
	var lights: Dictionary = _cfg["heli_lights"]
	var top := body.position.y + body.size.y * Num.f(lights["mast"])
	var side := body.size.x * 0.5 * Num.f(lights["wing"])
	var mid := body.get_center()
	_lamp(Vector3(-side, top, mid.z), Color(str(lights["red"])), Num.f(lights["nav_energy"]))
	_lamp(Vector3(side, top, mid.z), Color(str(lights["green"])), Num.f(lights["nav_energy"]))
	_strobe = _lamp(
		Vector3(mid.x, top, body.end.z), Color(str(lights["white"])), Num.f(lights["strobe_energy"])
	)
	_lamp(
		Vector3(mid.x, body.position.y, mid.z),
		Color(str(lights["belly"])),
		Num.f(lights["belly_energy"]),
		Num.f(lights["belly_size"])
	)


## One emissive lamp ball at `at` (bloom does the glow), `size` 0 for the nav lamp size.
func _lamp(at: Vector3, color: Color, energy: float, size := 0.0) -> Node3D:
	var lights: Dictionary = _cfg["heli_lights"]
	var ball := SphereMesh.new()
	ball.radius = size if size > 0.0 else Num.f(lights["size"])
	ball.height = ball.radius * 2.0
	ball.material = CityView.glow(color, energy)
	var bulb := MeshInstance3D.new()
	bulb.mesh = ball
	bulb.position = at
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulb)
	return bulb


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


## The leader's look (D-149): no gun, and every voxel but the dark ones (glass, skids) lit from
## within so it reads at night. The white and gold are the VIP_BASE model's own texture. It lights
## this model's own copy of the voxels (the cache is shared with every other leader).
func vip_look() -> void:
	_gun.visible = false
	for part: Node3D in [_main_rotor, _tail_rotor]:
		_light(part, 0.0)
	_light(_body, Num.f(_cfg["vip_dark"]))


## Every voxel of `root` glows at vip_glow in its own colour; voxels darker than `dark` are left
## alone.
func _light(root: Node3D, dark: float) -> void:
	var parts: Array[Node] = root.find_children("*", "MultiMeshInstance3D", true, false)
	parts.append(root)  # the body is itself a voxel mesh
	for part: Node in parts:
		var mmi := part as MultiMeshInstance3D
		if mmi == null:
			continue
		var mm := _copy(mmi.multimesh)
		mmi.multimesh = mm
		var mat := (mm.mesh as PrimitiveMesh).material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("glow", Num.f(_cfg["vip_glow"]))  # lit from within: reads at night
		mmi.material_override = mat
		for i: int in mm.instance_count:
			var paint := mm.get_instance_color(i)
			if paint.get_luminance() >= dark:
				mm.set_instance_color(i, Color(paint.r, paint.g, paint.b, 0.0))  # 0: glows


## A copy of a shared voxel multimesh that can take its own colours.
func _copy(from: MultiMesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = from.transform_format
	mm.use_colors = true
	mm.mesh = from.mesh
	mm.instance_count = from.instance_count
	for i: int in from.instance_count:
		mm.set_instance_transform(i, from.get_instance_transform(i))
		mm.set_instance_color(i, from.get_instance_color(i))
	return mm


## Takes the body, both rotors and the gun off the helicopter into `into` (world transforms kept)
## and returns them: a wreck's pieces to throw. The helicopter is left empty.
func break_up(into: Node3D) -> Array[Node3D]:
	VehicleParts.set_opacity(self, 1.0)  # it was fading as a screen door: pieces are solid
	var out: Array[Node3D] = []
	for part: Node3D in [_body, _main_rotor, _tail_rotor, _gun]:
		var at := part.global_transform
		part.get_parent().remove_child(part)
		into.add_child(part)
		part.global_transform = at
		out.append(part)
	set_process(false)
	return out
