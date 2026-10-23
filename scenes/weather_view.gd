class_name WeatherView
extends Node3D
## The look of the run's weather (Content.weather_id(), D-155; ROADMAP M1 weather), built once
## when the city loads. One view for every weather: each weather's layer in data/looks.json
## "weather" "layers" says what it lays over the time of day's look, and this reads it. Clear has
## no layer and builds nothing. Rain (and the thunderstorm, which is rain plus its own later
## darkness) gives:
##  - falling streaks (rain.gdshader) and tiny ground splashes (rain_splash.gdshader): world-space
##    GPUParticles3D in a volume that follows the camera, leaning with the run's wind
##    (Fire.WIND), counts x the graphics preset's particles ratio, thinned round the camera, the
##    screen centre and in front of the kaiju like smoke (D-018, view_clear.gdshaderinc);
##  - wet streets: the ground slabs' `wet` uniform (ground_slab.gdshader);
##  - a duller sky: the look's ambient, sun and fog multiplied down and the sky and fog colours
##    pulled toward their own grey, over whatever the time of day is, so a later layer can sit on it.
## Presentation only. Numbers: data/looks.json weather.layers, data/tuning.json rain.

const RAIN_SHADER := preload("res://scenes/rain.gdshader")
const SPLASH_SHADER := preload("res://scenes/rain_splash.gdshader")
const SPLASH_SIZE_SPREAD := Vector2(0.7, 1.3)

var layer: Dictionary = {}
var streaks: GPUParticles3D
var splashes: GPUParticles3D
var _cfg: Dictionary = {}
var _volume := Vector3.ZERO


## Builds the current weather's view under `city` (a CityView, after its ground and environment
## exist). Returns it, or null when the weather has no layer (clear): nothing is added then.
static func attach(city: Node3D) -> WeatherView:
	var found := layer_of(Content.weather_id())
	if found.is_empty():
		return null
	var view := WeatherView.new()
	view.layer = found
	city.add_child(view)
	return view


## The layer of weather `id` from data ('like' resolved); empty when it has none.
static func layer_of(id: String) -> Dictionary:
	var layers: Dictionary = Content.weather_table().get("layers", {})
	var found: Variant = layers.get(id, {})
	if not found is Dictionary:
		return {}
	var src: Dictionary = found
	var out: Dictionary = src.duplicate()
	if out.has("like"):
		var base := layer_of(str(out["like"]))
		base.merge(out, true)
		base.erase("like")
		return base
	return out


func _ready() -> void:
	_cfg = Content.section("rain")
	var parent := get_parent()
	_dull_the_sky(parent)
	_wet_the_ground(parent)
	if layer.get("rain", false) == true:
		_build_rain()


func _process(_delta: float) -> void:
	if streaks == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var forward := -camera.global_transform.basis.z
	var flat := Vector3(forward.x, 0.0, forward.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var centre := camera.global_position + flat * Num.f(_cfg["ahead"])
	streaks.global_position = Vector3(centre.x, _volume.y, centre.z)
	splashes.global_position = Vector3(centre.x, Num.f(_cfg["splash_y"]), centre.z)


## The ground slabs' wet uniform (CityGround.WET_GROUP), set once; other weathers leave it 0.
func _wet_the_ground(parent: Node) -> void:
	var wet := Num.f(layer.get("wet", 0.0))
	if wet <= 0.0:
		return
	for node: Node in parent.get_tree().get_nodes_in_group(CityGround.WET_GROUP):
		var mmi := node as MultiMeshInstance3D
		var mat := mmi.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		mat.set_shader_parameter("wet", wet)


## The layer's multipliers and greying on the city's WorldEnvironment and sun.
func _dull_the_sky(parent: Node) -> void:
	var grey := Num.f(layer.get("sky_grey", 0.0))
	var dim := Num.f(layer.get("sky_dim", 1.0))
	for node: Node in parent.get_tree().get_nodes_in_group(GraphicsPresets.GROUP):
		if node is DirectionalLight3D:
			(node as DirectionalLight3D).light_energy *= Num.f(layer.get("sun_mul", 1.0))
		elif node is WorldEnvironment:
			var env := (node as WorldEnvironment).environment
			env.ambient_light_energy *= Num.f(layer.get("ambient_mul", 1.0))
			env.fog_density *= Num.f(layer.get("fog_mul", 1.0))
			env.fog_light_color = _dulled(env.fog_light_color, grey, dim)
			var sky := env.sky.sky_material as ProceduralSkyMaterial
			if sky != null:
				sky.sky_top_color = _dulled(sky.sky_top_color, grey, dim)
				sky.sky_horizon_color = _dulled(sky.sky_horizon_color, grey, dim)
				sky.ground_horizon_color = _dulled(sky.ground_horizon_color, grey, dim)
				sky.ground_bottom_color = _dulled(sky.ground_bottom_color, grey, dim)


## `c` pulled `grey` of the way to its own luminance, then dimmed.
static func _dulled(c: Color, grey: float, dim: float) -> Color:
	var l := c.get_luminance()
	var out := c.lerp(Color(l, l, l), grey) * dim
	out.a = c.a
	return out


## The streak colour: the fog grey lifted toward white, held under max_channel so rain never
## blooms.
func streak_color() -> Color:
	var fog := Look.color("fog_color")
	var c := fog.lerp(Color.WHITE, Num.f(_cfg["tint_white"]))
	var top := maxf(c.r, maxf(c.g, c.b))
	var cap := Num.f(_cfg["max_channel"])
	if top > cap:
		c = Color(c.r * cap / top, c.g * cap / top, c.b * cap / top)
	return c


func _build_rain() -> void:
	var ratio := GraphicsPresets.cap("particles")
	var vol: Array = _cfg["volume"]
	_volume = Vector3(Num.f(vol[0]), Num.f(vol[1]), Num.f(vol[2]))
	var speed := Num.f(_cfg["fall_speed"])
	var jitter := Num.f(_cfg["speed_jitter"])
	var wind := Fire.WIND * Num.f(_cfg["wind_gain"])
	var velocity := Vector3(wind.x, -speed, wind.z)
	# Every streak lives long enough to reach the ground, so none fades out in mid-air in view.
	var seconds := _volume.y / speed * (1.0 + jitter) * 1.05
	streaks = GPUParticles3D.new()
	streaks.name = "RainStreaks"
	streaks.amount = maxi(1, roundi(Num.f(_cfg["streaks"]) * ratio))
	streaks.lifetime = seconds
	streaks.preprocess = seconds  # a full volume from the first frame
	streaks.fixed_fps = 0
	streaks.local_coords = false
	streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streaks.custom_aabb = AABB(
		Vector3(-_volume.x * 0.5 - 30.0, -_volume.y * 1.3, -_volume.z * 0.5 - 30.0),
		Vector3(_volume.x + 60.0, _volume.y * 1.4, _volume.z + 60.0)
	)
	var flow := ParticleProcessMaterial.new()
	flow.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	flow.emission_box_extents = Vector3(_volume.x * 0.5, 0.5, _volume.z * 0.5)
	flow.direction = velocity.normalized()
	flow.spread = 0.0
	flow.gravity = Vector3.ZERO
	flow.initial_velocity_min = velocity.length() * (1.0 - jitter)
	flow.initial_velocity_max = velocity.length() * (1.0 + jitter)
	streaks.process_material = flow
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = RAIN_SHADER
	var tint := streak_color()
	mat.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, Num.f(_cfg["alpha"])))
	mat.set_shader_parameter("fall_dir", velocity.normalized())
	mat.set_shader_parameter("streak_len", Num.f(_cfg["length"]))
	mat.set_shader_parameter("streak_width", Num.f(_cfg["width"]))
	mat.set_shader_parameter("min_px", Num.f(_cfg["min_px"]))
	for key: String in ["fade_in", "fade_out", "far_begin", "far_end"]:
		mat.set_shader_parameter(key, Num.f(_cfg[key]))
	var table: Dictionary = _cfg["clear"]
	_clearing(mat, table)
	quad.material = mat
	streaks.draw_pass_1 = quad
	add_child(streaks)
	_build_splashes(ratio, tint)


func _build_splashes(ratio: float, tint: Color) -> void:
	var area: Array = _cfg["splash_volume"]
	var seconds := Num.f(_cfg["splash_seconds"])
	splashes = GPUParticles3D.new()
	splashes.name = "RainSplashes"
	splashes.amount = maxi(1, roundi(Num.f(_cfg["splashes"]) * ratio))
	splashes.lifetime = seconds
	splashes.preprocess = seconds
	splashes.fixed_fps = 0
	splashes.local_coords = false
	splashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flow := ParticleProcessMaterial.new()
	flow.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	flow.emission_box_extents = Vector3(Num.f(area[0]) * 0.5, 0.0, Num.f(area[1]) * 0.5)
	flow.gravity = Vector3.ZERO
	flow.scale_min = SPLASH_SIZE_SPREAD.x
	flow.scale_max = SPLASH_SIZE_SPREAD.y
	splashes.process_material = flow
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * Num.f(_cfg["splash_size"])
	quad.orientation = PlaneMesh.FACE_Y
	var mat := ShaderMaterial.new()
	mat.shader = SPLASH_SHADER
	mat.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, Num.f(_cfg["splash_alpha"])))
	var table: Dictionary = _cfg["splash_clear"]
	_clearing(mat, table)
	quad.material = mat
	splashes.draw_pass_1 = quad
	add_child(splashes)


## Puts a clearing table (near_clear, near_full, centre_keep, centre_radius, focus_clear,
## focus_full) on a shader that includes view_clear.gdshaderinc.
static func _clearing(mat: ShaderMaterial, table: Dictionary) -> void:
	for key: String in table:
		mat.set_shader_parameter(key, Num.f(table[key]))
