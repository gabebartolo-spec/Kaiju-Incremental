class_name FarBeast
extends Node3D
## The far kaiju of SkylineRampage, as an impostor: a real KaijuModel walks in a small world of
## its own (a SubViewport), filmed side-on from the player's camera direction, and the picture
## stands in the skyline on one camera-facing quad that hazes like the far towers
## (far_impostor.gdshader; FarHaze swaps in its _fogged twin with theirs). Its legs plant
## because the model really walks: its path is mirrored into the little world at 1/size scale.
## Presentation only.

## Its footfalls (KaijuModel.foot_planted), at the feet in the skyline.
signal foot_planted(side: String, strength: float, at: Vector3)

const SHADER := preload("res://scenes/far_impostor.gdshader")
const FRAME := 1.4  # the picture's height in model heights (room for a raised limb)
const FRAME_FOOT := 0.08  # share of the picture below the feet
const LENS_BACK := 60.0  # the little camera's distance from the model (orthographic)

## How tall the beast stands in the skyline (world units).
var height := 40.0
var _model: KaijuModel
var _view: SubViewport
var _lens: Camera3D
var _quad: MeshInstance3D
var _mat: ShaderMaterial
var _rim_lights: Array[DirectionalLight3D] = []


## cfg: tuning "skyline_rampage" (species: whose model walks there, height, picture_px: the
## picture's height in pixels, shade: how dark it stands against the haze, 1 = as lit).
func _init(cfg: Dictionary, haze: float) -> void:
	height = Num.f(cfg["height"])
	var species := str(cfg["species"])
	var px := Num.i(cfg["picture_px"])
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.size = Vector2i(px, px)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_add_lighting()
	var colors: Dictionary = Content.species_def(species)["colors"]
	var fire := Color(str(cfg["fire"]))  # the burning towers' light on its back and belly
	for yaw: float in [145.0, 215.0]:
		_rim_light(Vector3(25.0, yaw, 0.0), fire, Num.f(cfg["rim_energy"]))
	_rim_light(Vector3(30.0, 0.0, 0.0), fire, Num.f(cfg["rim_fill"]))
	_model = KaijuModel.new(species, colors, "adult")
	_view.add_child(_model)
	_model.foot_planted.connect(_planted)
	_lens = Camera3D.new()
	_lens.projection = Camera3D.PROJECTION_ORTHOGONAL
	_lens.size = KaijuModel.MODEL_HEIGHT * FRAME
	_lens.far = LENS_BACK * 2.0
	_lens.current = true
	_view.add_child(_lens)
	for light: DirectionalLight3D in _rim_lights:  # they turn with the little camera
		_view.remove_child(light)
		_lens.add_child(light)
	_add_screen(cfg, haze, px)


## The little world's environment and sun: the city's, so the beast is lit as the towers are.
func _add_lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var has_ambient := Content.look().has("ambient_color")
	env.ambient_light_color = Look.color("ambient_color" if has_ambient else "sky_horizon")
	env.ambient_light_energy = Look.value("ambient")
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_view.add_child(world_env)
	var sun := DirectionalLight3D.new()  # the city's sun, so the beast is lit as the towers are
	sun.rotation_degrees = Vector3(Look.value("sun_pitch"), -35, 0)
	sun.light_energy = Look.value("sun_energy")
	sun.light_color = Look.color("sun_color")
	_view.add_child(sun)


## The quad that shows the little world on the skyline: haze, shade and the fire's rim.
func _add_screen(cfg: Dictionary, haze: float, px: int) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("view", _view.get_texture())
	_mat.set_shader_parameter("haze", haze)
	_mat.set_shader_parameter("haze_color", Look.color("fog_color"))
	_mat.set_shader_parameter("shade", Num.f(cfg["shade"]))
	_mat.set_shader_parameter("rim_color", Color(str(cfg["fire"])))
	_mat.set_shader_parameter("rim", Num.f(cfg["rim_edge"]))
	_mat.set_shader_parameter("px", float(px))
	var quad := QuadMesh.new()
	quad.material = _mat
	_quad = MeshInstance3D.new()
	_quad.mesh = quad
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_quad)


## Walks the model one frame: `at` its feet in the skyline, `yaw` its facing (rotation.y),
## `eye` the player's camera. The little camera turns with the view, so the side shown is true.
func walk(delta: float, at: Vector3, yaw: float, eye: Vector3) -> void:
	var size := height / KaijuModel.MODEL_HEIGHT
	_model.position = Vector3(at.x, 0.0, at.z) / size
	_model.rotation.y = yaw
	_model.animate(delta, 1.0)
	var look := Vector3(at.x - eye.x, 0.0, at.z - eye.z).normalized()
	if look == Vector3.ZERO:
		look = Vector3.FORWARD
	var lift := KaijuModel.MODEL_HEIGHT * FRAME * (0.5 - FRAME_FOOT)
	var mid := _model.position + Vector3(0, lift, 0)
	_lens.position = mid - look * LENS_BACK
	_lens.look_at(mid)
	var frame := height * FRAME
	var centre := at + Vector3(0, frame * (0.5 - FRAME_FOOT), 0)
	var facing := Basis.looking_at(look)  # seen as the little camera sees it: front to the player
	_quad.global_transform = Transform3D(
		facing * Basis.from_scale(Vector3(frame, frame, 1.0)), centre
	)


## A warm light fixed to the little camera (`euler` from the camera's own axes), no shadows.
func _rim_light(euler: Vector3, color: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = euler
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = false
	_view.add_child(light)
	_rim_lights.append(light)


## The picture's material (CitySkyline's FarHaze keeps its haze with the far towers').
func material() -> ShaderMaterial:
	return _mat


## Measuring (capture tools): the picture drawn as flat magenta, hazeless.
func set_probe(on: bool) -> void:
	_mat.set_shader_parameter("probe", on)


func _planted(side: String, strength: float, at: Vector3) -> void:
	foot_planted.emit(side, strength, at * (height / KaijuModel.MODEL_HEIGHT))


## A heavy stomp (the model's squash), as a tower goes down.
func stomp() -> void:
	_model.stomp()
