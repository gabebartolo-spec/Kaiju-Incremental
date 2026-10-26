class_name FarFlash
extends MeshInstance3D
## A short flash far across the bay: a muzzle flash in a far street, or the orange burst of an
## explosion with a puff of smoke that climbs and thins. Billboard; frees itself when done.
## Presentation only (the title screen's scene).

var _life: float
var _age := 0.0
var _size: float
var _color: Color
var _rise: float
var _grow: float
var _bright := 1.0  # a flash's brightness share (PlayerSettings.flash_scale; 1 for smoke)


## spec: "color", "size", "life" (s) and optionally "rise" (how far it climbs over its life),
## "grow" (how many times bigger it ends) and "additive" (false: a smoke puff).
func _init(spec: Dictionary) -> void:
	_color = spec["color"]
	_size = Num.f(spec["size"])
	_life = Num.f(spec["life"])
	_rise = Num.f(spec.get("rise", 0.0))
	_grow = Num.f(spec.get("grow", 1.0))
	var additive: bool = spec.get("additive", true)
	_bright = PlayerSettings.flash_scale() if additive else 1.0  # Reduce flashing (D-259); smoke stays
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.disable_fog = true
	mat.albedo_texture = FarFire.soft_disc()
	mat.albedo_color = _color
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scale = Vector3.ONE * _size


func _process(delta: float) -> void:
	_age += delta
	var t := _age / _life
	if t >= 1.0:
		queue_free()
		return
	var mat := material_override as StandardMaterial3D
	# A flash holds its light, then dies: a fireball must be seen for its whole life.
	mat.albedo_color = Color(_color, _color.a * (1.0 - t * t) * _bright)
	scale = Vector3.ONE * _size * lerpf(1.0, _grow, t)
	position.y += _rise / _life * delta
