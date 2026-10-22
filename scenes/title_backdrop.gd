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

var is_loaded := false

var _cfg: Dictionary
var _city: CityView
var _camera: Camera3D
var _fade := 0.0
var _shake := 0.0
var _shake_rng := Seeds.make("title_shake", 0)
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
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.handle_input_locally = false
	add_child(_view)
	var tuning := CityGrowth.tuning_for(Content.tuning(), Num.i(_cfg["city_tier"]))
	var layout := CityGrowth.layout(Content.tuning(), Num.i(_cfg["city_tier"]), Seeds.make("city", 0))
	var sim := RampageSim.new({}, tuning, layout, Seeds.make("army", 0))
	_city = CityView.new(sim, Seeds.make("fx", 0))
	var stages := BuildStages.new()
	stages.on = true
	_city.stages = stages
	_view.add_child(_city)
	var cam: Dictionary = _cfg["camera"]
	_camera = Camera3D.new()
	_camera.fov = Num.f(cam["fov"])
	_view.add_child(_camera)
	_camera.current = true
	_camera.position = _vec(cam["position"])
	_camera.look_at(_vec(cam["look"]))
	while not _city.is_loaded:
		if not is_inside_tree():
			return
		await get_tree().process_frame
	_light_fires()
	is_loaded = true
	ready_to_show.emit()


func _process(delta: float) -> void:
	if not is_loaded:
		return
	_fade = minf(1.0, _fade + delta / Num.f(_cfg["fade_s"]))
	var tremor: Dictionary = _cfg["ambience"]["tremor"]
	_shake = maxf(0.0, _shake - _shake * Num.f(tremor["decay_per_s"]) * delta)
	var dim := 1.0 - Num.f(tremor["dim"]) * _shake
	modulate = Color(dim, dim, dim, _fade)
	var cam: Dictionary = _cfg["camera"]
	_camera.position = _vec(cam["position"]) + (
		Vector3(_shake_rng.randf_range(-1.0, 1.0), _shake_rng.randf_range(-1.0, 1.0), 0.0)
		* Num.f(tremor["amplitude"])
		* _shake
	)


## A far stomp (strength 0..1): the picture shudders and flickers, then settles.
func stomp(strength: float) -> void:
	_shake = clampf(strength, 0.0, 1.0)


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
	var burst := FarFlash.new(
		{"color": Color(str(cfg["color"])), "size": cfg["size"], "life": cfg["life_s"], "grow": 1.6}
	)
	burst.position = at
	_city.add_child(burst)
	var puff := FarFlash.new(
		{
			"color": Color(str(cfg["smoke_color"])),
			"size": cfg["smoke_size"],
			"life": cfg["smoke_s"],
			"rise": cfg["smoke_rise"],
			"grow": 2.0,
			"additive": false,
		}
	)
	puff.position = at
	_city.add_child(puff)


## A random spot on the far shore's front rows, among the burning district's x range.
func _far_spot(low: float, high: float) -> Vector3:
	var cfg: Dictionary = _cfg["fires"]
	var focus: Array = cfg["focus"]
	var far_z := _far_z()
	return Vector3(
		Num.f(focus[0]) + _flash_rng.randf_range(-1.0, 1.0) * Num.f(cfg["radius"]),
		_flash_rng.randf_range(low, high),
		far_z - _flash_rng.randf_range(4.0, Num.f(cfg["depth"]))
	)


## A district burns: the tallest far-shore towers around the focus each burn at the top.
func _light_fires() -> void:
	var cfg: Dictionary = _cfg["fires"]
	var at: Array = cfg["focus"]
	var focus := Vector2(Num.f(at[0]), Num.f(at[1]))
	var far_z := _far_z()
	var towers: Array[Dictionary] = []
	for node: Node in _city.find_children("*", "CitySkyline", true, false):
		for box: Dictionary in (node as CitySkyline).stand_ins():
			var centre: Vector3 = box["at"]
			var size: Vector3 = box["size"]
			var front := centre.z < far_z and centre.z > far_z - Num.f(cfg["depth"])
			if front and Vector2(centre.x, centre.z).distance_to(focus) <= Num.f(cfg["radius"]):
				towers.append({"top": centre + Vector3(0.0, size.y * 0.5, 0.0), "height": size.y})
	towers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["height"] > b["height"])
	var rng := Seeds.make("title_fire", 0)
	var far: Dictionary = cfg["far"]
	for n: int in mini(Num.i(cfg["count"]), towers.size()):
		var top: Vector3 = towers[n]["top"]
		var fire := FarFire.new(far, rng.randf() * 10.0)
		fire.position = top
		_city.add_child(fire)


## Where the far shore's front edge lies (world z): the coast less the bay's width.
func _far_z() -> float:
	var city: Dictionary = _city.sim.city
	return Num.f(city["coast_z"]) - Num.f(city["bay_width"])


func _vec(v: Variant) -> Vector3:
	var a: Array = v
	return Vector3(Num.f(a[0]), Num.f(a[1]), Num.f(a[2]))
