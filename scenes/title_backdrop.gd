class_name TitleBackdrop
extends SubViewportContainer
## The title screen's live city at night (comments #88, #98, #99): the far shore seen across the
## bay from the play area's quay by a still camera, a district over there on fire with its smoke,
## scattered gunshot flashes in the far streets and now and then an explosion. The kaiju is only
## implied, by the fire and the sound. Presentation only: the sim is built but never stepped.
## The scene starts on frame one: a night sky and the fires' glow are there at once and the city
## fades in over them as it builds (a few frames of work spread behind the menu). tuning "title".

## Set once the city stands.
signal ready_to_show

## The bay is the one plane this wide (CityGround).
const WATER_MIN_WIDTH := 2000.0

var is_loaded := false
var _shore: TitleShore
var _shiver := 0.0
var _rising := false
var _colossus: TitleColossus
var _reveal_wait := 0.0
var _reveal_rng := Seeds.make("title_colossus", 0)

var _cfg: Dictionary
var _city: CityView
var _camera: Camera3D
var _fade := 0.0
var _flash_rng := Seeds.make("title_flash", 0)
var _view: SubViewport


func _ready() -> void:
	_cfg = Content.section("title")
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(self)
	# The sky and the menu draw first; the sim and the city build behind them.
	await get_tree().process_frame
	await get_tree().process_frame
	_build()


func _build() -> void:
	Content.set_time("night")
	_make_city()
	while not _city.is_loaded:
		if not is_inside_tree():
			return
		await get_tree().process_frame
	_dress()
	is_loaded = true
	ready_to_show.emit()


## The sim, the city view and the still camera (the city then builds over a few frames).
func _make_city() -> void:
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.handle_input_locally = false
	add_child(_view)
	var tuning := CityGrowth.tuning_for(Content.tuning(), Num.i(_cfg["city_tier"]))
	var city_tuning: Dictionary = tuning["city"]
	city_tuning["far_tower_cap"] = Num.f(_cfg["tower_cap"])  # D-158: the colossus clears every tower
	var layout := CityGrowth.layout(
		Content.tuning(), Num.i(_cfg["city_tier"]), Seeds.make("city", 0)
	)
	var sim := RampageSim.new({}, tuning, layout, Seeds.make("army", 0))
	_city = CityView.new(sim, Seeds.make("fx", 0))
	var stages := BuildStages.new()
	stages.on = true
	_city.stages = stages
	_view.add_child(_city)
	var cam: Dictionary = _cfg["camera"]
	_camera = Camera3D.new()
	_camera.fov = Num.f(cam["fov"])
	# Nothing of the play-area city within this many metres draws (a lit window 10 m away was a
	# glowing box floating over the bay).
	_camera.near = Num.f(cam["near"])
	_view.add_child(_camera)
	_camera.current = true
	_camera.position = _vec(cam["position"])
	_camera.look_at(_vec(cam["look"]))


## What goes over the built city: the look, the fires, the shore, the sky's smoke, the colossus.
func _dress() -> void:
	_apply_look()
	var fire_cfg: Dictionary = _cfg["fires"]
	var district := TitleFires.new(_city, fire_cfg, _far_z())
	var fires := district.light()
	var shore_cfg: Dictionary = _cfg["shore"]
	_shore = TitleShore.new(
		shore_cfg,
		{
			"shore_z": _far_z(),
			"coast_z": _coast_z(),
			"cam": _camera.position,
			"fires": fires,
			"ripple": _cfg["ripple"]
		}
	)
	_city.add_child(_shore)
	var variant: Dictionary = _cfg["variants"][str(_cfg["variant"])]
	var layers: Array = _cfg["sky_smoke"]
	_city.add_child(TitleSkySmoke.new(layers, Num.f(variant["sky_smoke"])))
	var colossus_cfg: Dictionary = _cfg["colossus"]
	_colossus = TitleColossus.new(colossus_cfg)
	_city.add_child(_colossus)


func _process(delta: float) -> void:
	if not is_loaded:
		return
	# The camera never moves and the picture never dims (#99): only the first fade-in changes it.
	_fade = minf(1.0, _fade + delta / Num.f(_cfg["fade_s"]))
	modulate = Color(1.0, 1.0, 1.0, _fade)
	_reveal_wait -= delta
	var ripple: Dictionary = _cfg["ripple"]
	if _rising:
		# A footstep lands over a few frames, not in one: the surface is pushed, then lets go.
		_shiver = minf(1.0, _shiver + delta / Num.f(ripple["attack_s"]))
		_rising = _shiver < 1.0
	elif _shiver > 0.0:
		_shiver = maxf(0.0, _shiver - delta / Num.f(ripple["decay_s"]))
	if _shiver > 0.0 or _rising:
		_shore.set_shiver(_shiver)


## How far the bay is shivering (0 at rest .. 1 a footstep has just landed), for captures.
func shiver() -> float:
	return _shiver if not _rising else 1.0


## A far footstep landed: the bay shivers (the camera and the picture stay still), the reflections
## breaking into wobbling bands, then it settles over tuning "ripple" "decay_s".
func stomp() -> void:
	_rising = true
	if _colossus != null:
		_colossus.step()


## A gunshot far away: a small bright flash in a far street.
func shot() -> void:
	if not is_loaded:
		return
	var cfg: Dictionary = _cfg["flashes"]["shot"]
	var at := _far_spot(0.0, 0.0)
	at.y = Num.f(cfg["height"])
	var flash := FarFlash.new(
		{"color": Color(str(cfg["color"])), "size": cfg["size"], "life": cfg["life_s"]}
	)
	flash.position = at
	_city.add_child(flash)


## An explosion far away: an orange burst high over the burning district and a puff of smoke.
func boom() -> void:
	if not is_loaded:
		return
	var cfg: Dictionary = _cfg["flashes"]["boom"]
	var at := _far_spot(Num.f(cfg["min_height"]), Num.f(cfg["max_height"]))
	var life := Num.f(cfg["life_s"])
	var sky := cfg.duplicate()
	if _colossus != null and _reveal_wait <= 0.0:
		# The big one: it goes off behind the colossus and lights it, a longer flash.
		var colossus: Dictionary = _cfg["colossus"]
		var every: Array = colossus["reveal_every_s"]
		_reveal_wait = _reveal_rng.randf_range(Num.f(every[0]), Num.f(every[1]))
		at = _colossus.burst_point()
		life = Num.f(colossus["flash_life_s"])
		_colossus.reveal()
		sky["glow_share"] = colossus["glow_share"]
		sky["glow_alpha"] = colossus["glow_alpha"]
	_boom_flashes(at, cfg, life)
	_light_sky(at, Color(str(cfg["color"])), sky, life)


## The burst, its white core and the puff of smoke it leaves, at `at`.
func _boom_flashes(at: Vector3, cfg: Dictionary, life: float) -> void:
	var burst := FarFlash.new(
		{"color": Color(str(cfg["color"])), "size": cfg["size"], "life": life, "grow": 1.6}
	)
	burst.position = at
	_city.add_child(burst)
	var core := (
		FarFlash
		. new(
			{
				"color": Color(str(cfg["core_color"])),
				"size": cfg["core_size"],
				"life": life * 0.8,
				"grow": 1.4,
			}
		)
	)
	core.position = at
	_city.add_child(core)
	var puff := (
		FarFlash
		. new(
			{
				"color": Color(str(cfg["smoke_color"])),
				"size": cfg["smoke_size"],
				"life": cfg["smoke_s"],
				"rise": cfg["smoke_rise"],
				"grow": 2.0,
				"additive": false,
			}
		)
	)
	puff.position = at
	_city.add_child(puff)


## The explosion's light washing the air around it: a soft orange glow over the picture, centred
## where the burst is on screen, gone in a quarter of a second (the 3D burst hides behind towers).
func _light_sky(at: Vector3, colour: Color, cfg: Dictionary, life: float) -> void:
	if _camera.is_position_behind(at):
		return
	var glow := TextureRect.new()
	glow.texture = FarFire.soft_disc()
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	var diameter := size.y * Num.f(cfg["glow_share"])
	glow.size = Vector2.ONE * diameter
	glow.position = _camera.unproject_position(at) - glow.size / 2.0
	glow.modulate = Color(colour, Num.f(cfg["glow_alpha"]))
	add_child(glow)
	var fade := create_tween()
	fade.tween_property(glow, "modulate:a", 0.0, life)
	fade.tween_callback(glow.queue_free)


## A random spot on the far shore's front rows, left or right of the menu (flashes span_x:
## clear of the menu in the middle).
func _far_spot(low: float, high: float) -> Vector3:
	var cfg: Dictionary = _cfg["fires"]
	var spans: Array = _cfg["flashes"]["span_x"]
	var span: Array = spans[_flash_rng.randi_range(0, spans.size() - 1)]
	var far_z := _far_z()
	return Vector3(
		_flash_rng.randf_range(Num.f(span[0]), Num.f(span[1])),
		_flash_rng.randf_range(low, high),
		far_z - _flash_rng.randf_range(4.0, Num.f(cfg["depth"]))
	)


## The chosen variant's look (tuning "title" "variant" picks one of "variants"): the sky, the haze
## and the sun, set on the city's own environment, and the bay's colour.
func _apply_look() -> void:
	var look: Dictionary = _cfg["variants"][str(_cfg["variant"])]
	var env: Dictionary = look["env"]
	for node: Node in _city.find_children("*", "WorldEnvironment", true, false):
		var environment := (node as WorldEnvironment).environment
		var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
		sky_material.sky_top_color = Color(str(env["sky_top"]))
		for horizon: Color in [Color(str(env["sky_horizon"]))]:
			sky_material.sky_horizon_color = horizon
			sky_material.ground_horizon_color = horizon
			sky_material.ground_bottom_color = horizon
		sky_material.sky_curve = Num.f(env["sky_curve"])
		environment.ambient_light_color = Color(str(env["ambient_color"]))
		environment.ambient_light_energy = Num.f(env["ambient"])
		environment.fog_light_color = Color(str(env["fog_color"]))
		environment.fog_density = Num.f(env["fog_density"])
	for node: Node in _city.find_children("*", "DirectionalLight3D", true, false):
		(node as DirectionalLight3D).light_color = Color(str(env["sun_color"]))
		(node as DirectionalLight3D).light_energy = Num.f(env["sun_energy"])
	_dim_windows()
	var water: Dictionary = look["water"]
	for node: Node in _city.find_children("*", "MeshInstance3D", true, false):
		var plane := (node as MeshInstance3D).mesh as PlaneMesh
		if (
			plane != null
			and plane.size.x > WATER_MIN_WIDTH
			and plane.material is StandardMaterial3D
		):
			var mat := plane.material as StandardMaterial3D
			mat.albedo_color = Color(str(water["color"]))
			mat.roughness = Num.f(water["roughness"])


## The far shore's windows: a power cut (whole blocks dark) and the lit ones dimmer than any fire,
## so the fire is the brightest thing on the shore (tuning "windows_lit").
func _dim_windows() -> void:
	var cut: Dictionary = _cfg["windows_lit"]
	for node: Node in _city.find_children("*", "MultiMeshInstance3D", true, false):
		var instances := (node as MultiMeshInstance3D).multimesh
		if instances == null or not instances.mesh is BoxMesh:
			continue
		var mat := (instances.mesh as BoxMesh).material as ShaderMaterial
		if mat == null or not mat.shader.resource_path.ends_with("facade_far.gdshader"):
			continue
		mat.set_shader_parameter("blackout", Num.f(cut["blackout"]))
		mat.set_shader_parameter("lit_color", Color(str(cut["lit_color"])))
		mat.set_shader_parameter("glow", Num.f(cut["glow"]))


## The play area's quay (world z).
func _coast_z() -> float:
	return Num.f(_city.sim.city["coast_z"])


## Where the far shore's front edge lies (world z): the coast less the bay's width.
func _far_z() -> float:
	var city: Dictionary = _city.sim.city
	return Num.f(city["coast_z"]) - Num.f(city["bay_width"])


func _vec(v: Variant) -> Vector3:
	var a: Array = v
	return Vector3(Num.f(a[0]), Num.f(a[1]), Num.f(a[2]))
