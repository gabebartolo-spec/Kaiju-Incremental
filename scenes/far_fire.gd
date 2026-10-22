class_name FarFire
extends Node3D
## A fire seen from far across the bay (the title's burning district): the real Fire's voxel
## flames are a pixel or two at that range, so this is a soft orange glow with a hot core that
## flickers, and a column of dark smoke that rises, leans with the wind and fades. Billboards
## only; presentation only. Numbers: tuning "title" "fires" "far".

const FLAME := preload("res://scenes/far_flame.gdshader")
const WIND := Vector3(2.2, 0.0, 0.9)

static var _disc: GradientTexture2D

var _cfg: Dictionary
var _glow: MeshInstance3D
var _core: MeshInstance3D
var _smoke: Array[MeshInstance3D] = []
var _flames: Array[MeshInstance3D] = []
var _t := 0.0
var _seed := 0.0
var _lit: Color
var _dark: Color


func _init(cfg: Dictionary, seed_value: float) -> void:
	_cfg = cfg
	_seed = seed_value


func _ready() -> void:
	_lit = Color(str(_cfg["smoke_lit_color"]))
	_dark = Color(str(_cfg["smoke_color"]))
	_glow = _sprite(Color(str(_cfg["color"])), Num.f(_cfg["glow_size"]), true)
	_core = _sprite(Color(str(_cfg["core_color"])), Num.f(_cfg["core_size"]), true)
	for i: int in Num.i(_cfg["flame_count"]):
		_flames.append(_flame(i))
	for i: int in Num.i(_cfg["smoke_count"]):
		_smoke.append(_sprite(Color(str(_cfg["smoke_color"])), Num.f(_cfg["smoke_size"]), false))


func _process(delta: float) -> void:
	_t += delta
	var beat := sin(_t * Num.f(_cfg["flicker_hz"]) + _seed) * sin(_t * 2.3 + _seed * 3.0)
	var flicker := 0.8 + 0.2 * beat
	_glow.scale = Vector3.ONE * Num.f(_cfg["glow_size"]) * flicker
	_core.scale = Vector3.ONE * Num.f(_cfg["core_size"]) * (0.9 + 0.3 * (flicker - 0.8) * 5.0)
	for i: int in _flames.size():
		var phase := _seed * 2.0 + float(i) * 1.9
		var burn := (
			0.82 + 0.18 * sin(_t * Num.f(_cfg["flicker_hz"]) * 0.7 + phase) * sin(_t * 1.7 + phase)
		)
		var wide := Num.f(_cfg["flame_w"]) * (0.8 + 0.4 * fposmod(phase, 1.0))
		var tall := Num.f(_cfg["flame_h"]) * burn * (0.7 + 0.6 * fposmod(phase * 1.7, 1.0))
		_flames[i].scale = Vector3(wide, tall, 1.0)
		var spread := (float(i) - (_flames.size() - 1) * 0.5) * Num.f(_cfg["flame_w"]) * 0.7
		_flames[i].position = Vector3(spread, tall * 0.5, 0.0)
	var life := Num.f(_cfg["smoke_s"])
	var rise := Num.f(_cfg["smoke_rise"])
	var base := Num.f(_cfg["smoke_size"])
	for i: int in _smoke.size():
		var age := fposmod(_t / life + float(i) / _smoke.size() + _seed, 1.0)
		var puff := _smoke[i]
		puff.position = Vector3(0.0, age * rise, 0.0) + WIND * age * life * 0.5
		puff.scale = Vector3.ONE * base * (0.5 + age * 1.3)
		var mat := puff.material_override as StandardMaterial3D
		var fade := sin(age * PI)
		# Lit warm from the fire below, cooling to the night's grey as it climbs.
		var tint := _lit.lerp(_dark, clampf(age * 1.1, 0.0, 1.0))
		mat.albedo_color = Color(tint, Num.f(_cfg["smoke_alpha"]) * fade)


## One ragged flame: a quad with the flame shader, its seed its own so the tongues differ.
func _flame(index: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = FLAME
	mat.set_shader_parameter("outer_colour", Color(str(_cfg["flame_color"])))
	mat.set_shader_parameter("core_colour", Color(str(_cfg["flame_core"])))
	mat.set_shader_parameter("seed", _seed + float(index) * 3.7)
	mat.set_shader_parameter("speed", Num.f(_cfg["flame_speed"]))
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _sprite(color: Color, size: float, additive: bool) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.disable_fog = true
	mat.no_depth_test = false
	mat.albedo_color = color
	mat.albedo_texture = soft_disc()
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.scale = Vector3.ONE * size
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## A white disc that fades out smoothly toward its edge, shared by every sprite.
static func soft_disc() -> GradientTexture2D:
	if _disc != null:
		return _disc
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 0.4))
	_disc = GradientTexture2D.new()
	_disc.gradient = fade
	_disc.fill = GradientTexture2D.FILL_RADIAL
	_disc.fill_from = Vector2(0.5, 0.5)
	_disc.fill_to = Vector2(1.0, 0.5)
	_disc.width = 128
	_disc.height = 128
	return _disc
