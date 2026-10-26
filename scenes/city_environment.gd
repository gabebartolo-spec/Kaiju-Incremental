class_name CityEnvironment
extends RefCounted
## The sky, the fog, the sun and the screen-space effects of a CityView (the look's numbers,
## Look): built once when a rampage's city loads.


static func attach(city: Node3D, sim: RampageSim) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Look.color("sky_top")
	sky_mat.sky_horizon_color = Look.color("sky_horizon")
	sky_mat.ground_horizon_color = Look.color("sky_horizon")
	sky_mat.ground_bottom_color = Look.color("sky_horizon")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	if Content.look().has("ambient_color"):
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Look.color("ambient_color")
	env.ambient_light_energy = Look.value("ambient")
	env.ssao_intensity = Look.value("ssao")
	env.ssao_power = Look.value("ssao_power")
	env.ssao_radius = 1.5
	env.fog_enabled = Look.value("fog_density") > 0.0
	env.fog_light_color = Look.color("fog_color")
	# A grown city (D-039) thins the fog with its size, so its far edge still reads as skyline.
	env.fog_density = Look.value("fog_density") * Num.f(sim.city.get("fog_scale", 1.0))
	env.glow_enabled = Look.value("glow") > 0.0
	env.glow_intensity = Look.value("glow")
	env.glow_hdr_threshold = Look.value("glow_threshold")
	# SSAO, SSIL (screen-space bounce light; SDFGI cost ~a tenth of the frame) and the sun's
	# shadow reach, splits and softness come from the graphics preset (GraphicsPresets).
	env.adjustment_saturation = Look.value("saturation")
	grade(env)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.add_to_group(GraphicsPresets.GROUP)
	GraphicsPresets.apply_to(PlayerSettings.graphics_row(), world_env)
	city.add_child(world_env)
	GraphicsPresets.apply_look(city.get_viewport())  # debanding follows this run's look
	CreasePass.attach(city)  # creases darkened in screen space; off when the look says 0
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(Look.value("sun_pitch"), -35, 0)
	sun.light_energy = Look.value("sun_energy")
	sun.light_color = Look.color("sun_color")
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.add_to_group(GraphicsPresets.GROUP)
	GraphicsPresets.apply_to(PlayerSettings.graphics_row(), sun)
	city.add_child(sun)


## The tone map and the grade after it (render plan item 4, D-104): AgX with its own toe contrast
## (looks.json agx_contrast, 1.25 is the engine's) and the contrast Godot applies after the tone
## map (post_contrast, 1.3 = D-104). Above 1.0 that post step clips every sRGB value under
## 0.5 - 0.5 / contrast to black (0.115 at 1.3); the toe darkens without the cliff.
static func grade(env: Environment) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_agx_contrast = Look.value("agx_contrast")
	env.adjustment_enabled = true
	env.adjustment_contrast = Look.value("post_contrast")
