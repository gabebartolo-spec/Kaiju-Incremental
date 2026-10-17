class_name CityLighting
extends RefCounted
## The city's light and atmosphere from the active look (data/looks.json). Presentation only.


## The sky, ambient, fog, grade and the sun, as a WorldEnvironment and a DirectionalLight3D.
## A grown city (D-039) passes its fog_scale, so its far edge still reads as skyline.
static func build(fog_scale: float) -> Array[Node]:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Look.color("sky_top")
	sky_mat.sky_horizon_color = Look.color("sky_horizon")
	sky_mat.ground_horizon_color = Look.color("sky_horizon")
	sky_mat.ground_bottom_color = Look.color("sky_horizon")
	sky_mat.sky_energy_multiplier = Look.value_or("sky_energy", 1.0)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	if Content.look().has("ambient_color"):
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Look.color("ambient_color")
	env.ambient_light_energy = Look.value("ambient")
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = Look.value_or("exposure", 1.0)
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.ssao_radius = 1.5
	env.fog_enabled = Look.value("fog_density") > 0.0
	env.fog_light_color = Look.color("fog_color")
	env.fog_density = Look.value("fog_density") * fog_scale
	# Haze pooling low in the streets, and the sun lighting the haze it shines through.
	env.fog_height = Look.value_or("fog_height", 0.0)
	env.fog_height_density = Look.value_or("fog_height_density", 0.0)
	env.fog_sun_scatter = Look.value_or("fog_sun_scatter", 0.0)
	_volumetric_fog(env, fog_scale)
	env.glow_enabled = Look.value("glow") > 0.0
	env.glow_intensity = Look.value("glow")
	env.glow_hdr_threshold = 1.1
	# Light bounces: lamps, fires and the sun colour the streets and walls around them
	# (screen-space; full SDFGI cost about a tenth of the frame for little gain here).
	env.ssil_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = Look.value("saturation")
	env.adjustment_contrast = Look.value("contrast")
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(Look.value("sun_pitch"), Look.value_or("sun_yaw", -35.0), 0)
	sun.light_energy = Look.value("sun_energy")
	sun.light_color = Look.color("sun_color")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 1.0
	return [world_env, sun]


## Volumetric haze (Forward+ only): fires, lamps and the sun glow in the air around them, and
## light shafts fall between the towers. "vol_fog" 0 leaves it off (and costs nothing).
static func _volumetric_fog(env: Environment, fog_scale: float) -> void:
	var density := Look.value_or("vol_fog", 0.0)
	env.volumetric_fog_enabled = density > 0.0
	if density <= 0.0:
		return
	env.volumetric_fog_density = density * fog_scale
	env.volumetric_fog_albedo = Look.color_or("vol_fog_albedo", Color.WHITE)
	env.volumetric_fog_emission = Look.color_or("vol_fog_glow", Color.BLACK)
	env.volumetric_fog_emission_energy = Look.value_or("vol_fog_glow_energy", 0.0)
	env.volumetric_fog_anisotropy = Look.value_or("vol_fog_anisotropy", 0.5)
	env.volumetric_fog_length = Look.value_or("vol_fog_length", 96.0)
	env.volumetric_fog_ambient_inject = Look.value_or("vol_fog_ambient", 0.0)
