class_name FarFire
extends Node3D
## A fire seen from far across the bay (the title's burning towers): ragged flames pouring out of
## a window or off a roof and licking up the wall, with a column of billowing smoke above. Both
## are GPUParticles3D emitters in the way of the in-game Fire (same flame colours, smoke leaning
## with the wind), scaled up so they read at 230 m: the real Fire's cubes are a pixel or two at
## that range. The flames are soft quads torn into jagged tongues by noise (far_flame.gdshader),
## the smoke soft noisy puffs lit orange just above the fire, greying and thinning as they climb
## (far_smoke.gdshader). Presentation only. Numbers: tuning "title" "fires" "far" and "window".

const FLAME := preload("res://scenes/far_flame.gdshader")
const SMOKE := preload("res://scenes/far_smoke.gdshader")
## How strong the window's own light is on the wall around it (the soft glow's alpha).
const GLOW_ALPHA := 0.3

static var _disc: GradientTexture2D

var _cfg: Dictionary
var _glow: MeshInstance3D
var _t := 0.0
var _seed := 0.0


func _init(cfg: Dictionary, seed_value: float) -> void:
	_cfg = cfg
	_seed = seed_value


func _ready() -> void:
	_glow = _glow_sprite()
	add_child(_glow)
	var flame_speed: Array = _cfg["flame_speed"]
	var tongue_speed: Array = _cfg["tongue_speed"]
	add_child(_flames(Num.i(_cfg["flame_amount"]), 0.0, flame_speed))
	add_child(_flames(Num.i(_cfg["tongue_amount"]), 1.0, tongue_speed))
	if Num.i(_cfg["smoke_amount"]) > 0:
		add_child(_smoke())


func _process(delta: float) -> void:
	_t += delta
	var beat := sin(_t * Num.f(_cfg["flicker_hz"]) + _seed) * sin(_t * 2.3 + _seed * 3.0)
	_glow.scale = Vector3.ONE * Num.f(_cfg["glow_size"]) * (0.8 + 0.2 * beat)


## The flames: many small ragged tongues, born in the opening, thrown up the wall. `out` (0..1)
## leans their throw toward the camera: the few that streak past the sill.
func _flames(amount: int, out: float, speed: Array) -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	var box: Array = _cfg["flame_box"]
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(Num.f(box[0]) * 0.5, Num.f(box[1]) * 0.5, 0.4)
	mat.direction = Vector3(0.0, 1.0, 0.1 + out * 0.9)
	mat.spread = Num.f(_cfg["flame_spread"])
	mat.gravity = Vector3(0.0, Num.f(_cfg["flame_up"]), 0.0)
	mat.initial_velocity_min = Num.f(speed[0])
	mat.initial_velocity_max = Num.f(speed[1])
	var scale_span: Array = _cfg["flame_scale"]
	mat.scale_min = Num.f(scale_span[0])
	mat.scale_max = Num.f(scale_span[1])
	mat.scale_curve = _curve(1.0, 0.25)
	var ramp: Array = _cfg["flame_ramp"]
	var ramp_at: Array = _cfg["flame_ramp_at"]
	mat.color_ramp = _ramp(ramp, ramp_at)
	var quad := QuadMesh.new()
	quad.size = Vector2(Num.f(_cfg["flame_w"]), Num.f(_cfg["flame_h"]))
	quad.center_offset = Vector3(0.0, quad.size.y * 0.5, 0.0)
	var draw := ShaderMaterial.new()
	draw.shader = FLAME
	quad.material = draw
	var p := _system(mat, quad, amount, Num.f(_cfg["flame_life_s"]))
	p.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 80, 80))
	return p


## The smoke column: billowing irregular puffs that rise, swell, lean with the wind and fade.
func _smoke() -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	var box: Array = _cfg["flame_box"]
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(Num.f(box[0]) * 0.5, 1.0, 1.0)
	mat.direction = Vector3.UP
	mat.spread = 9.0
	var wind: Array = _cfg["smoke_wind"]
	mat.gravity = Vector3(Num.f(wind[0]), Num.f(wind[1]), Num.f(wind[2]))
	var speed: Array = _cfg["smoke_speed"]
	mat.initial_velocity_min = Num.f(speed[0])
	mat.initial_velocity_max = Num.f(speed[1])
	var size: Array = _cfg["smoke_size"]
	mat.scale_min = Num.f(size[0])
	mat.scale_max = Num.f(size[1])
	mat.scale_curve = _curve(0.5, Num.f(_cfg["smoke_grow"]))
	var ramp: Array = _cfg["smoke_ramp"]
	var ramp_at: Array = _cfg["smoke_ramp_at"]
	mat.color_ramp = _ramp(ramp, ramp_at)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var draw := ShaderMaterial.new()
	draw.shader = SMOKE
	quad.material = draw
	var p := _system(mat, quad, Num.i(_cfg["smoke_amount"]), Num.f(_cfg["smoke_life_s"]))
	p.position.y = Num.f(box[1]) * 0.6
	p.visibility_aabb = AABB(Vector3(-120, -10, -120), Vector3(240, 260, 240))
	return p


func _system(mat: ParticleProcessMaterial, mesh: Mesh, amount: int, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	p.preprocess = life  # already burning when the title appears
	p.randomness = 1.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _curve(from: float, to: float) -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0, from))
	curve.add_point(Vector2(1, to))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


## A colour ramp from [hex, alpha] stops at the given offsets.
func _ramp(stops: Array, offsets: Array) -> GradientTexture1D:
	var ramp := Gradient.new()
	var colors := PackedColorArray()
	var at := PackedFloat32Array()
	for i: int in stops.size():
		var stop: Array = stops[i]
		colors.append(Color(str(stop[0]), Num.f(stop[1])))
		at.append(Num.f(offsets[i]))
	ramp.colors = colors
	ramp.offsets = at
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	return tex


## The window's own light on the wall around it.
func _glow_sprite() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	mat.albedo_color = Color(Color(str(_cfg["glow_color"])), GLOW_ALPHA)
	mat.albedo_texture = soft_disc()
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.scale = Vector3.ONE * Num.f(_cfg["glow_size"])
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
