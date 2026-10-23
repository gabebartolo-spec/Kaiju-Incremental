class_name CityHaze
extends RefCounted
## The haze that carries the city's depth (director D-163: "the haze carries the depth"): fog that
## melts the far skyline into the sky's colour (aerial perspective), a low layer thicker near the
## street, and a warm glow towards the sun, all in the look's cool fog colour. Fires are warm
## against it. The whole haze scales with one strength, so the rampage escalation (D-154 haze
## thickens, the sky turns orange) and weather (D-155) drive it by calling apply() again.


## `strength` 1 is the look as written; 0 clears the haze, 2 doubles its thickness.
static func apply(env: Environment, fog_scale: float, strength: float = 1.0) -> void:
	env.fog_enabled = Look.value("fog_density") > 0.0
	env.fog_light_color = Look.color("fog_color")
	# A grown city (D-039) thins the fog with its size, so its far edge still reads as skyline.
	var scale := fog_scale * strength
	env.fog_density = Look.value("fog_density") * scale
	env.fog_aerial_perspective = clampf(Look.value("haze_aerial") * strength, 0.0, 1.0)
	env.fog_sky_affect = clampf(Look.value("haze_sky_affect"), 0.0, 1.0)
	env.fog_sun_scatter = clampf(Look.value("haze_sun_scatter") * strength, 0.0, 1.0)
	env.fog_height = Look.value("haze_height")
	env.fog_height_density = Look.value("haze_height_density") * scale
