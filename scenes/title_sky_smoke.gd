class_name TitleSkySmoke
extends Node3D
## Heavy smoke banks filling the title's night sky (director 2026-10-22, a film poster's quality):
## a low bank lit orange from underneath by the fires and higher ones fading to near-black, a few
## dozen big soft puffs far behind the far shore, so there is no clean sky. Static cards that sway
## and change shape slowly in their shader (title_sky_smoke.gdshader), one draw call a layer and
## nothing to simulate, so they stand on the first frame. Presentation only; layers in tuning
## "title" "sky_smoke".

const SMOKE := preload("res://scenes/title_sky_smoke.gdshader")

static var _noise: ImageTexture

var _layers: Array
var _strength: float


## layers: each {"x": [lo, hi], "y": [lo, hi], "z", "depth", "amount", "size": [lo, hi], "colour",
## "alpha", "under", "under_colour", "drift"}; strength scales every layer's alpha (a variant can
## thin the cloud).
func _init(layers: Array, strength: float) -> void:
	_layers = layers
	_strength = strength


func _ready() -> void:
	var rng := Seeds.make("title_sky_smoke", 0)
	for layer: Dictionary in _layers:
		add_child(_bank(layer, rng))


func _bank(layer: Dictionary, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var x: Array = layer["x"]
	var y: Array = layer["y"]
	var size: Array = layer["size"]
	var count := Num.i(layer["amount"])
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var draw := ShaderMaterial.new()
	draw.shader = SMOKE
	draw.render_priority = -1
	draw.set_shader_parameter(
		"tint", Color(Color(str(layer["colour"])), Num.f(layer["alpha"]) * _strength)
	)
	draw.set_shader_parameter("under_colour", Color(str(layer["under_colour"])))
	draw.set_shader_parameter("under_amount", Num.f(layer["under"]))
	draw.set_shader_parameter("noise_tex", noise_texture())
	draw.set_shader_parameter("drift", Num.f(layer["drift"]))
	quad.material = draw
	var puffs := MultiMesh.new()
	puffs.transform_format = MultiMesh.TRANSFORM_3D
	puffs.mesh = quad
	puffs.instance_count = count
	for i: int in count:
		var puff := Vector3.ONE * rng.randf_range(Num.f(size[0]), Num.f(size[1]))
		var at := Vector3(
			rng.randf_range(Num.f(x[0]), Num.f(x[1])),
			rng.randf_range(Num.f(y[0]), Num.f(y[1])),
			Num.f(layer["z"]) + rng.randf_range(-1.0, 1.0) * Num.f(layer["depth"])
		)
		puffs.set_instance_transform(i, Transform3D(Basis.from_scale(puff), at))
	var node := MultiMeshInstance3D.new()
	node.multimesh = puffs
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-800, -50, -900), Vector3(1600, 600, 600))
	return node


## One soft seamless noise image shared by every layer's puffs.
static func noise_texture() -> ImageTexture:
	if _noise == null:
		var field := FastNoiseLite.new()
		field.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		field.frequency = 0.012
		field.fractal_octaves = 4
		field.seed = 7
		_noise = ImageTexture.create_from_image(field.get_seamless_image(256, 256))
	return _noise
