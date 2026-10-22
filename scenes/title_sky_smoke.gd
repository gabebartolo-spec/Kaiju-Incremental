class_name TitleSkySmoke
extends Node3D
## Heavy smoke clouds filling the title's night sky (director 2026-10-22, a film poster's quality):
## a low bank lit orange from the fires under it and a high one fading to near-black, slow drifting
## puffs far behind the far shore, so there is no clean sky. The same soft puffs as the fires'
## smoke (far_smoke.gdshader). Presentation only; layers in tuning "title" "sky_smoke".

const SMOKE := preload("res://scenes/far_smoke.gdshader")

var _layers: Array
var _strength: float


## layers: each {"x": [lo, hi], "y": [lo, hi], "z", "amount", "size", "colour", "alpha"};
## strength scales every layer's alpha (a variant can thin the cloud).
func _init(layers: Array, strength: float) -> void:
	_layers = layers
	_strength = strength


func _ready() -> void:
	for layer: Dictionary in _layers:
		add_child(_bank(layer))


func _bank(layer: Dictionary) -> GPUParticles3D:
	var x: Array = layer["x"]
	var y: Array = layer["y"]
	var size: Array = layer["size"]
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(
		(Num.f(x[1]) - Num.f(x[0])) * 0.5, (Num.f(y[1]) - Num.f(y[0])) * 0.5, Num.f(layer["depth"])
	)
	mat.gravity = Vector3(Num.f(layer["drift"]), 0.0, 0.0)
	mat.scale_min = Num.f(size[0])
	mat.scale_max = Num.f(size[1])
	var colour := Color(str(layer["colour"]))
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(
		[
			Color(colour, 0.0),
			Color(colour, Num.f(layer["alpha"]) * _strength),
			Color(colour, Num.f(layer["alpha"]) * _strength),
			Color(colour, 0.0)
		]
	)
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	mat.color_ramp = tex
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var draw := ShaderMaterial.new()
	draw.shader = SMOKE
	quad.material = draw
	var bank := GPUParticles3D.new()
	bank.process_material = mat
	bank.draw_pass_1 = quad
	bank.amount = Num.i(layer["amount"])
	bank.lifetime = Num.f(layer["life_s"])
	bank.preprocess = Num.f(layer["life_s"])
	bank.randomness = 1.0
	bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bank.visibility_aabb = AABB(Vector3(-600, -50, -600), Vector3(1200, 600, 1200))
	bank.position = Vector3(
		(Num.f(x[0]) + Num.f(x[1])) * 0.5, (Num.f(y[0]) + Num.f(y[1])) * 0.5, Num.f(layer["z"])
	)
	return bank
