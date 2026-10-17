class_name RevealStage
extends RefCounted
## The set the evolution reveal plays on, shared with the demo end card: a dark backdrop, a sun,
## the ground, a real city tower beside the kaiju and a camera that frames them both.

## The comparison tower's footprint (chunks); it is built by the city's own BuildingView.
const TOWER_SIDE := 6


## The tallest tower (floors) a body of size tier `size_tier` topples without undermining it:
## its tier x the city's tier height, capped at the city's tallest (`city`: a stage's "city").
static func tower_floors(size_tier: int, city: Dictionary) -> int:
	return mini(size_tier * Num.i(city["tier_height"]), Num.i(city["max_height"]))


## Builds the set into `viewport` for a kaiju scaled `body_scale` beside a `floors` tower.
static func build(viewport: SubViewport, body_scale: float, floors: int) -> Camera3D:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("1b2433")
	env.environment.ambient_light_color = Color("6f86a8")
	env.environment.ambient_light_energy = 0.6
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_energy = 1.2
	viewport.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2c3036")
	ground.material_override = mat
	viewport.add_child(ground)
	var tallest := maxf(KaijuModel.MODEL_HEIGHT * body_scale, float(floors))
	var tower_x := KaijuModel.MODEL_HEIGHT * body_scale * 0.5 + TOWER_SIDE
	viewport.add_child(_tower(tower_x, floors))
	var camera := Camera3D.new()
	camera.fov = 40.0
	var aim := Vector3(tower_x * 0.5, tallest * 0.5, 0.0)
	camera.position = aim + Vector3(0.0, tallest * 0.15, tallest * 1.55 + 8.0)
	viewport.add_child(camera)
	camera.look_at(aim)
	return camera


## A real city building of `floors` floors (same voxels, windows and shader as the city),
## standing on the ground line at x.
static func _tower(x: float, floors: int) -> BuildingView:
	var b := RampageSim.Building.new()
	b.x = x
	b.z = 0.0
	b.w = TOWER_SIDE
	b.d = TOWER_SIDE
	b.height = floors
	b.tier = CityGen.tier_for_height(floors, Content.section("city"))
	b.style = 0
	b.frame = Structure.new(b.w, b.d, b.height, 1.0)
	return BuildingView.new(b, Look.styles()[0])
