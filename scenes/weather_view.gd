class_name WeatherView
extends Node3D
## The look of the run's weather (Content.weather_id(), D-155; ROADMAP M1 weather), built once
## when the city loads. One view for every weather: each weather's layer in data/looks.json
## "weather" "layers" says what it lays over the time of day's look, and this reads it. Clear has
## no layer and builds nothing. Rain (and the thunderstorm, which is rain plus its own later
## darkness) gives:
##  - falling streaks (rain.gdshader, three depth layers: near, mid, far) and ground splashes
##    (rain_splash.gdshader): world-space GPUParticles3D in volumes that follow the camera,
##    leaning with the run's wind (Fire.WIND), counts x the graphics preset's particles ratio,
##    thinned round the camera, the screen centre and in front of the kaiju like smoke (D-018,
##    view_clear.gdshaderinc);
##  - wet streets: the ground slabs' `wet` uniform and the sky they mirror (ground_slab.gdshader),
##    and a stretched glowing smear under each streetlight (rain_smear.gdshader) for the lamp
##    reflections (no screen-space reflections);
##  - a duller sky and a heavier veil: the look's ambient, sun and fog multiplied down and the
##    sky and fog colours pulled toward their own grey, over whatever the time of day is, so a
##    later layer can sit on it.
## Presentation only. Numbers: data/looks.json weather.layers, data/tuning.json rain.

const RAIN_SHADER := preload("res://scenes/rain.gdshader")
const SPLASH_SHADER := preload("res://scenes/rain_splash.gdshader")
const SMEAR_SHADER := preload("res://scenes/rain_smear.gdshader")
const SPLASH_SIZE_SPREAD := Vector2(0.45, 1.3)

var layer: Dictionary = {}
var streaks: GPUParticles3D  # the near layer; `layers` holds all three
var layers: Array[GPUParticles3D] = []
var splashes: GPUParticles3D
var smears: MultiMeshInstance3D
var _cfg: Dictionary = {}
var _ahead: Array[float] = []
var _tops: Array[float] = []
var _smear_mat: ShaderMaterial
var _smear_wait := 0.0


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
	var layers_table: Dictionary = Content.weather_table().get("layers", {})
	var found: Variant = layers_table.get(id, {})
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


func _process(delta: float) -> void:
	if streaks == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var forward := -camera.global_transform.basis.z
	var flat := Vector3(forward.x, 0.0, forward.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	for i: int in layers.size():
		var centre := camera.global_position + flat * _ahead[i]
		layers[i].global_position = Vector3(centre.x, _tops[i], centre.z)
	var around := camera.global_position + flat * Num.f(_cfg["ahead"])
	splashes.global_position = Vector3(around.x, Num.f(_cfg["splash_y"]), around.z)
	if _smear_mat != null:
		_smear_mat.set_shader_parameter("toward_camera", Vector2(-flat.x, -flat.z))
		_smear_wait -= delta
		if _smear_wait <= 0.0:
			var smear: Dictionary = _cfg["smear"]
			_smear_wait = Num.f(smear["every_s"])
			_place_smears(camera.global_position)


## The ground slabs' wet uniform (CityGround.WET_GROUP), set once; other weathers leave it 0.
func _wet_the_ground(parent: Node) -> void:
	var wet := Num.f(layer.get("wet", 0.0))
	if wet <= 0.0:
		return
	var sheen := _sheen_colour()
	for node: Node in parent.get_tree().get_nodes_in_group(CityGround.WET_GROUP):
		var mmi := node as MultiMeshInstance3D
		var mat := mmi.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		mat.set_shader_parameter("wet", wet)
		mat.set_shader_parameter("sheen_color", sheen)


## The sky colour the wet road gives back: the horizon colour, after the dulling.
func _sheen_colour() -> Color:
	for node: Node in get_tree().get_nodes_in_group(GraphicsPresets.GROUP):
		if node is WorldEnvironment:
			var env := (node as WorldEnvironment).environment
			if env.sky != null:
				var sky := env.sky.sky_material as ProceduralSkyMaterial
				if sky != null:
					return sky.sky_horizon_color
	return Color.BLACK


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
	var tint := streak_color()
	var rows: Array = _cfg["layers"]
	for row_any: Variant in rows:
		var row: Dictionary = row_any
		layers.append(_build_layer(row, ratio, tint))
	streaks = layers[0]
	_build_splashes(ratio, tint)
	if Num.f(layer.get("wet", 0.0)) > 0.0:
		_build_smears()


## One depth layer of streaks: `row` (data/tuning.json rain.layers) over the shared fall.
func _build_layer(row: Dictionary, ratio: float, tint: Color) -> GPUParticles3D:
	var vol: Array = row["volume"]
	var volume := Vector3(Num.f(vol[0]), Num.f(vol[1]), Num.f(vol[2]))
	var speed := Num.f(_cfg["fall_speed"]) * Num.f(row["speed_mul"])
	var jitter := Num.f(_cfg["speed_jitter"])
	var wind := Fire.WIND * Num.f(_cfg["wind_gain"])
	var velocity := Vector3(wind.x, -speed, wind.z)
	# Every streak lives long enough to reach the ground, so none fades out in mid-air in view.
	var seconds := volume.y / speed * (1.0 + jitter) * 1.05
	var particles := GPUParticles3D.new()
	particles.name = "RainStreaks_%s" % str(row["name"])
	particles.amount = maxi(1, roundi(Num.f(row["streaks"]) * ratio))
	particles.lifetime = seconds
	particles.preprocess = seconds  # a full volume from the first frame
	particles.fixed_fps = 0
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.custom_aabb = AABB(
		Vector3(-volume.x * 0.5 - 30.0, -volume.y * 1.3, -volume.z * 0.5 - 30.0),
		Vector3(volume.x + 60.0, volume.y * 1.4, volume.z + 60.0)
	)
	var flow := ParticleProcessMaterial.new()
	flow.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	flow.emission_box_extents = Vector3(volume.x * 0.5, 0.5, volume.z * 0.5)
	flow.direction = velocity.normalized()
	flow.spread = 0.0
	flow.gravity = Vector3.ZERO
	flow.initial_velocity_min = velocity.length() * (1.0 - jitter)
	flow.initial_velocity_max = velocity.length() * (1.0 + jitter)
	particles.process_material = flow
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _streak_material(row, tint, velocity.normalized())
	particles.draw_pass_1 = quad
	add_child(particles)
	_ahead.append(Num.f(row["ahead"]))
	_tops.append(volume.y)
	return particles


## One layer's streak shader material (rain.gdshader): tint, fall direction, size and fades.
func _streak_material(row: Dictionary, tint: Color, fall_dir: Vector3) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = RAIN_SHADER
	mat.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, Num.f(row["alpha"])))
	mat.set_shader_parameter("fall_dir", fall_dir)
	mat.set_shader_parameter("streak_len", Num.f(row["len"]))
	mat.set_shader_parameter("streak_width", Num.f(row["width"]))
	for key: String in ["fade_in", "fade_out"]:
		mat.set_shader_parameter(key, Num.f(_cfg[key]))
	for key: String in ["far_begin", "far_end", "near_clear", "near_full"]:
		mat.set_shader_parameter(key, Num.f(row[key]))
	var table: Dictionary = _cfg["clear"]
	_clearing(mat, table)
	return mat


func _build_splashes(ratio: float, tint: Color) -> void:
	var area: Array = _cfg["splash_volume"]
	var seconds := Num.f(_cfg["splash_seconds"])
	splashes = GPUParticles3D.new()
	splashes.name = "RainSplashes"
	splashes.amount = maxi(1, roundi(Num.f(_cfg["splashes"]) * ratio))
	splashes.lifetime = seconds
	splashes.preprocess = seconds
	splashes.randomness = 1.0
	splashes.fixed_fps = 0
	splashes.local_coords = false
	splashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flow := ParticleProcessMaterial.new()
	flow.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	flow.emission_box_extents = Vector3(Num.f(area[0]) * 0.5, 0.0, Num.f(area[1]) * 0.5)
	flow.gravity = Vector3.ZERO
	flow.lifetime_randomness = Num.f(_cfg["splash_lifetime_spread"])
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


## The lamp reflections: one MultiMesh of ground quads under the streetlights, re-placed on a timer
## (a lamp trampled or out of reach drops its smear). Added light; a lamp that is out (daytime)
## gives none.
func _build_smears() -> void:
	var smear: Dictionary = _cfg["smear"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	_smear_mat = ShaderMaterial.new()
	_smear_mat.shader = SMEAR_SHADER
	_smear_mat.set_shader_parameter("alpha", Num.f(smear["alpha"]))
	quad.material = _smear_mat
	mm.mesh = quad
	mm.instance_count = Num.i(smear["max"])
	mm.visible_instance_count = 0
	smears = MultiMeshInstance3D.new()
	smears.name = "RainSmears"
	smears.multimesh = mm
	smears.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smears.custom_aabb = AABB(Vector3(-2000.0, -5.0, -2000.0), Vector3(4000.0, 10.0, 4000.0))
	add_child(smears)
	_smear_wait = 0.0


func _place_smears(from: Vector3) -> void:
	var smear: Dictionary = _cfg["smear"]
	var mm := smears.multimesh
	var y := Num.f(_cfg["splash_y"]) + 0.02
	var reach := Num.f(smear["reach"])
	var origin := Vector3(from.x, y, from.z)
	var count := _place_lamps(mm, origin, reach, smear)
	count = _place_windows(mm, origin, count, smear)
	for i: int in range(count, mm.instance_count):  # the rest sit far below the world, unseen
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0.0, -1000.0, 0.0)))
		mm.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.0))
	mm.visible_instance_count = -1


## One smear under every lit streetlight in reach; returns how many instances are used.
func _place_lamps(mm: MultiMesh, origin: Vector3, reach: float, smear: Dictionary) -> int:
	var lamp_fade := Num.f(Content.section("lights")["lamp"]["fade_begin"])
	var full := Num.f(smear["lamp_energy_full"])
	var count := 0
	for node: Node in get_tree().get_nodes_in_group(PooledLight.GROUP):
		var lamp := node as PooledLight
		if lamp == null or not is_equal_approx(lamp.distance_fade_begin, lamp_fade):
			continue  # fires and beacons: not a streetlight
		if lamp.energy <= 0.0 or count >= Num.i(smear["lamp_max"]):
			continue
		var at := lamp.global_position
		if Vector2(at.x - origin.x, at.z - origin.z).length() > reach:
			continue
		mm.set_instance_transform(count, Transform3D(Basis.IDENTITY, Vector3(at.x, origin.y, at.z)))
		var c := lamp.light_color
		mm.set_instance_color(count, Color(c.r, c.g, c.b, clampf(lamp.energy / full, 0.0, 1.0)))
		mm.set_instance_custom_data(
			count, Color(Num.f(smear["width"]), Num.f(smear["length_per_height"]) * at.y, 0.0, 0.0)
		)
		count += 1
	return count


## A long soft smear in front of each lit building (its windows' reflection in the wet street, the
## nearest few to the camera), as long as the lit share and the height say; returns the count.
func _place_windows(mm: MultiMesh, origin: Vector3, start: int, smear: Dictionary) -> int:
	var lit := Look.value("window_lit")
	var parent := get_parent()
	if lit <= 0.02 or not "sim" in parent:
		return start
	var sim: RampageSim = parent.get("sim")
	var reach := Num.f(smear["window_reach"])
	var near: Array[Vector2] = []  # (distance, building index)
	for i: int in sim.buildings.size():
		var b: RampageSim.Building = sim.buildings[i]
		var d := Vector2(b.x - origin.x, b.z - origin.z).length()
		if d <= reach and b.height > 0:
			near.append(Vector2(d, i))
	near.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var count := start
	var warm := Color(str(smear["window_color"]))
	for k: int in near.size():
		if count >= mm.instance_count:
			break
		var b: RampageSim.Building = sim.buildings[int(near[k].y)]
		var long := clampf(
			float(b.height) * Num.f(smear["window_length_per_height"]),
			2.0,
			Num.f(smear["window_length_max"])
		)
		mm.set_instance_transform(
			count, Transform3D(Basis.IDENTITY, Vector3(b.x, origin.y, b.z + b.d * 0.5))
		)
		mm.set_instance_color(
			count,
			Color(warm.r, warm.g, warm.b, clampf(lit * Num.f(smear["window_gain"]), 0.0, 1.0))
		)
		mm.set_instance_custom_data(count, Color(float(b.w) * 0.8, long, 0.0, 0.0))
		count += 1
	return count


## Puts a clearing table (near_clear, near_full, centre_keep, centre_radius, focus_clear,
## focus_full) on a shader that includes view_clear.gdshaderinc.
static func _clearing(mat: ShaderMaterial, table: Dictionary) -> void:
	for key: String in table:
		mat.set_shader_parameter(key, Num.f(table[key]))
