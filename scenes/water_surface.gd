class_name WaterSurface
extends RefCounted
## The city's water surface (D-244, D-245; D-325 step 1, "the surface"): every river channel and
## the bay drawn with water.gdshader, one look for both (depth colour, a foam line where anything
## meets it, two scales of moving normal detail, Fresnel, the sky's reflection kept); the river's
## waves ride its current along the channel, the bay has a gentle swell. Its waves run with the
## run's wind (Fire.WIND), as the rain and the smoke lean. Numbers: tuning "water"; colours: the
## look's "river" and "water" (the deep colour of each), "water_shallow" and "water_foam".
## Presentation only: nothing reads it back. Tuning water.on false draws the glossy sheet it
## replaced (captures compare the two).

const SHADER := preload("res://scenes/water.gdshader")
## Every sheet is in this group (a capture masks the water by it).
const GROUP := "water_surface"
## Drawn first of the transparent things after the crease pass (CreasePass.FIRST), so smoke,
## spray, rings and fire over the water always draw on top of it.
const PRIORITY := Material.RENDER_PRIORITY_MIN + 1
## The glossy sheet's numbers (water.on false), as it was.
const GLOSS_ROUGHNESS := 0.12
const GLOSS_SPECULAR := 0.8


## True when the water surface is on (tuning water.on, on by default).
static func on() -> bool:
	return Num.f(Content.section("water")["on"]) > 0.0  # a bool, or a --tune float


## A sheet of water over rect (x, z) at height y. deep: its colour where it is deep; bay: the open
## water north of the quay (its swell), else a river channel (its current runs along the rect's
## long side, east to west on today's plans). seed: the city's map seed.
static func sheet(rect: Rect2, y: float, deep: Color, bay: bool, seed: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = rect.size
	plane.material = material(rect, deep, bay, seed) if on() else _gloss(deep)
	mi.mesh = plane
	var mid := rect.get_center()
	mi.position = Vector3(mid.x, y, mid.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(GROUP)
	return mi


## The water material for one sheet (see sheet()).
static func material(rect: Rect2, deep: Color, bay: bool, seed: int) -> ShaderMaterial:
	ThreadCheck.main_only("WaterSurface.material")
	var cfg: Dictionary = Content.section("water")
	var kind: Dictionary = cfg["bay" if bay else "river"]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.render_priority = PRIORITY
	mat.set_shader_parameter("deep_color", deep)
	mat.set_shader_parameter("shallow_color", Look.color("water_shallow"))
	mat.set_shader_parameter("foam_color", Look.color("water_foam"))
	for key: String in ["absorb", "murk", "foam_depth", "foam", "rough_near", "rough_far"]:
		mat.set_shader_parameter(key, Num.f(cfg[key]))
	mat.set_shader_parameter("spec", Num.f(cfg["specular"]))
	mat.set_shader_parameter("crest_light", Num.f(cfg["crest_light"]))
	for key: String in ["wave_length", "wave_slope", "ripple_length", "ripple_slope"]:
		mat.set_shader_parameter(key, Num.f(kind[key]))
	mat.set_shader_parameter("swell_length", Num.f(kind.get("swell_length", 0.0)))
	mat.set_shader_parameter("swell_slope", Num.f(kind.get("swell_slope", 0.0)))
	var wind := Vector2(Fire.WIND.x, Fire.WIND.z).normalized()
	mat.set_shader_parameter("wind", wind)
	var along := Vector2.RIGHT if rect.size.x >= rect.size.y else Vector2.DOWN
	mat.set_shader_parameter("flow", along * Num.f(kind.get("flow", 0.0)))
	mat.set_shader_parameter("seed", float(seed % 1000))
	return mat


## The glossy sheet the surface replaced (tuning water.on false).
static func _gloss(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = GLOSS_ROUGHNESS
	mat.metallic_specular = GLOSS_SPECULAR
	return mat
