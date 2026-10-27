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
var _strobe: Node3D  # the white anti-collision flash
var _clock := 0.0


## A new model, already in `parent`.
static func added_to(parent: Node) -> HelicopterModel:
	var heli := HelicopterModel.new()
	parent.add_child(heli)
	return heli


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


## The leader's look (D-149): a white body with a gold band, gold rotors, no gun. It recolours this
## model's own copy of the shared voxels (the cache keeps the gunships' tan ones).
func vip_look(white: Color, gold: Color) -> void:
	_gun.visible = false
	for part: Node3D in [_main_rotor, _tail_rotor]:
		_recolour(part, gold, gold, 0.0)
	_recolour(_body, white, gold, Num.f(_cfg["vip_dark"]))


## Every voxel of `root` takes `base` (keeping its own light and shade), the band at the model's
## lower middle takes `band`, and voxels darker than `dark` (glass, skids) are left alone.
func _recolour(root: Node3D, base: Color, band: Color, dark: float) -> void:
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
		var low := INF
		var high := -INF
		var shade := 0.0
		for i: int in mm.instance_count:
			var y := mm.get_instance_transform(i).origin.y
			low = minf(low, y)
			high = maxf(high, y)
			shade += mm.get_instance_color(i).get_luminance() / mm.instance_count
		var from := low + (high - low) * Num.f(_cfg["vip_band"][0])
		var to := low + (high - low) * Num.f(_cfg["vip_band"][1])
		for i: int in mm.instance_count:
			var old := mm.get_instance_color(i)
			if old.get_luminance() < dark:
				continue
			var y := mm.get_instance_transform(i).origin.y
			var paint := band if y >= from and y <= to else base
			var k := clampf(old.get_luminance() / maxf(0.01, shade), 0.8, 1.15)
			mm.set_instance_color(i, Color(paint.r * k, paint.g * k, paint.b * k, 0.0))  # 0: glows


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
	var out: Array[Node3D] = []
	for part: Node3D in [_body, _main_rotor, _tail_rotor, _gun]:
		var at := part.global_transform
		part.get_parent().remove_child(part)
		into.add_child(part)
		part.global_transform = at
		out.append(part)
	set_process(false)
	return out
