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
## The voxel jitter's salt, the same for every part (build and repaint must agree).
const SALT := 5

## The colour of every voxel of each part (by part name) as vip_look() painted it, in the order the
## part draws them; empty on a gunship. Kept because a headless MultiMesh reads back nothing: this
## is the only place a test sees what the leader was painted.
var painted: Dictionary = {}
var _parts: VehicleParts
var _centre := Vector3.ZERO  # under the mast: the body's hinge level with the wheels
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
	_parts = VehicleParts.new(BASE, Num.f(_cfg["heli_height"]))
	_centre = _parts.pivot("body") * Vector3(1, 0, 1)
	_body = _parts.build("body", -_centre, SALT)
	add_child(_body)
	_main_rotor = _parts.hinge("main_rotor", self, _centre, SALT)
	_tail_rotor = _parts.hinge("tail_rotor", self, _centre, SALT)
	_gun = _parts.hinge("gun", self, _centre, SALT)
	_muzzle = Vector3(0, 0, _parts.front("gun") - _parts.pivot("gun").z)
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


## The leader's look (D-149): a white body with a gold band, gold rotors, no gun. Each part gets its
## own voxels painted from the part's packed buffer (the shared cache keeps the gunships' tan ones),
## and `painted` keeps the colours it gave them.
func vip_look(white: Color, gold: Color) -> void:
	_gun.visible = false
	var hinges := {"main_rotor": _main_rotor, "tail_rotor": _tail_rotor}
	for part: String in hinges:
		var hinge: Node3D = hinges[part]
		var mmi := hinge.get_child(0) as MultiMeshInstance3D  # hinge() holds the one voxel mesh
		var voxels := _parts.packed(part, -_parts.pivot(part), SALT)
		_repaint(mmi, part, _paint(voxels, gold, gold, 0.0))
	var body := _parts.packed("body", -_centre, SALT)
	_repaint(
		_body as MultiMeshInstance3D, "body", _paint(body, white, gold, Num.f(_cfg["vip_dark"]))
	)


## `mmi` takes its own MultiMesh of `buf` (a part's painted voxels), glowing from within; `painted`
## keeps their colours.
func _repaint(mmi: MultiMeshInstance3D, part: String, buf: PackedFloat32Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mmi.multimesh.mesh
	mm.instance_count = floori(buf.size() / float(VoxelBuilder.STRIDE))
	if mm.instance_count > 0:
		mm.buffer = buf
	mmi.multimesh = mm
	var mat := (mm.mesh as PrimitiveMesh).material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("glow", Num.f(_cfg["vip_glow"]))  # lit from within: reads at night
	mmi.material_override = mat
	var colours := PackedColorArray()
	for k: int in range(0, buf.size(), VoxelBuilder.STRIDE):
		colours.append(_colour_at(buf, k))
	painted[part] = colours


## A part's packed voxels (VoxelBuilder's buffer) painted: every voxel takes `base` (keeping its own
## light and shade), the band at the part's lower middle takes `band`, and voxels darker than `dark`
## (glass, skids) are left alone. Painted voxels glow (alpha 0).
func _paint(buf: PackedFloat32Array, base: Color, band: Color, dark: float) -> PackedFloat32Array:
	var stride := VoxelBuilder.STRIDE
	var count := floori(buf.size() / float(stride))
	var low := INF
	var high := -INF
	var shade := 0.0
	for k: int in range(0, buf.size(), stride):
		low = minf(low, buf[k + 7])  # the voxel's height: the transform's y translation
		high = maxf(high, buf[k + 7])
		shade += _colour_at(buf, k).get_luminance() / count
	var from := low + (high - low) * Num.f(_cfg["vip_band"][0])
	var to := low + (high - low) * Num.f(_cfg["vip_band"][1])
	var out := buf.duplicate()
	for k: int in range(0, buf.size(), stride):
		var old := _colour_at(buf, k)
		if old.get_luminance() < dark:
			continue
		var paint := band if buf[k + 7] >= from and buf[k + 7] <= to else base
		var lit := clampf(old.get_luminance() / maxf(0.01, shade), 0.8, 1.15)
		out[k + 12] = paint.r * lit
		out[k + 13] = paint.g * lit
		out[k + 14] = paint.b * lit
		out[k + 15] = 0.0  # 0: glows
	return out


static func _colour_at(buf: PackedFloat32Array, k: int) -> Color:
	return Color(buf[k + 12], buf[k + 13], buf[k + 14], buf[k + 15])


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
