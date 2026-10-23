class_name SerpentProto
extends Node3D
## The serpent slither prototype (D-198 "Yes, now"): a stand-in serpent (SerpentStandIn) steered
## by the player's move controls in the real city's streets, light and sky, under its own high,
## steady camera (SerpentCamera). Off the croc's game entirely: run
## `godot --path . res://scenes/serpent_proto.tscn`. Buildings are left out (no crushing in this
## step): all of them by default, or only those near a route a capture gives (`clear_along`).
## The sim's SerpentBody decides where the body is; this only draws and frames it.

## Debug start: on the ring avenue at the city's south edge, facing up the screen.
const START_IN := 6.0
## Buildings closer than this to a cleared route go (on top of the S's swing and the body's width).
const CLEAR_MARGIN := 2.0

var body: SerpentBody
var stand_in: SerpentStandIn
var sim: RampageSim
var camera: Camera3D
## Capture hook: when set, called with the seconds run so far for the stick (ground x, z).
var scripted: Callable
## Ground points a capture's route passes; empty: leave every building out.
var clear_along := PackedVector2Array()
var seconds := 0.0
var _cfg: Dictionary = Content.section("serpent")
var _follow: SerpentCamera
var _start := Vector2.INF
var _heading := Vector2(0, -1)


## Where the head starts and which way it faces (before _ready; default: the debug start).
func place(at: Vector2, heading: Vector2) -> void:
	_start = at
	_heading = heading.normalized()


func _ready() -> void:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var tuning := CityGrowth.for_stats(stats)
	Content.set_time("noon")
	var layout: Array[Dictionary] = []
	if not clear_along.is_empty():
		layout = _cleared(CityGen.generate(Seeds.make("city", 0), Content.section("city")))
	sim = RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	if _start.x == INF:
		_start = Vector2(0.0, CityGen.half_extent(sim.city) - START_IN)
	if body == null:
		body = SerpentBody.new(_cfg, _start, _heading)
	sim.kaiju_pos = _middle_ground()
	add_child(CityView.new(sim, Seeds.make("fx", 0)))
	_shade_sun()
	if stand_in == null:
		stand_in = SerpentStandIn.new(_cfg)
	add_child(stand_in)
	stand_in.update(body, 0.0)
	camera = Camera3D.new()
	camera.fov = CameraTuning.fov()
	camera.far = 4000.0
	add_child(camera)
	camera.current = true
	var moving := Vector3(body.heading.x, 0.0, body.heading.y) * body.speed
	_follow = SerpentCamera.new(_cfg, SerpentCamera.target(_cfg, body), moving)
	camera.transform = _follow.step(SerpentCamera.target(_cfg, body), 0.0)


## Steps the body `steps` physics ticks along `heading`, stick full on, before the first frame:
## a capture starts mid-slither, its S already laid. Call before adding to the tree.
func preroll(start: Vector2, heading: Vector2, steps: int) -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var stick := heading.normalized()
	place(start, heading)
	body = SerpentBody.new(_cfg, start, heading)
	stand_in = SerpentStandIn.new(_cfg)
	for _i: int in steps:
		body.step(dt, stick)
		stand_in.update(body, dt)


func _physics_process(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if scripted.is_valid():
		move = scripted.call(seconds)
	seconds += delta
	body.step(delta, move)
	sim.kaiju_pos = _middle_ground()  # the city streams and the people flee around the body
	stand_in.update(body, delta)


func _process(delta: float) -> void:
	_place_camera(delta)


func _place_camera(delta: float) -> void:
	camera.transform = _follow.follow(body, delta, stand_in.joints)


## The prototype's sun shadows (round 5 critic: a dotted dark band beside the raised head, dots in
## the coil's hole): the speckle is the soft shadow filter's scattered samples, spread by the sun's
## shadow_blur (1.5 in CityEnvironment); this scene sets it to sun_shadow_blur. Shadow bias and
## normal bias were tried and do not clear it (round 6). This scene only: the main game's sun is
## the lead's call.
func _shade_sun() -> void:
	for node: Node in find_children("*", "DirectionalLight3D", true, false):
		var sun := node as DirectionalLight3D
		if sun.shadow_enabled:
			sun.shadow_blur = Num.f(_cfg["sun_shadow_blur"])


## The sun's (shadow blur, shadow bias, normal bias) as set, for captures.
func sun_shadow() -> Vector3:
	for node: Node in find_children("*", "DirectionalLight3D", true, false):
		var sun := node as DirectionalLight3D
		if sun.shadow_enabled:
			return Vector3(sun.shadow_blur, sun.shadow_bias, sun.shadow_normal_bias)
	return -Vector3.ONE


func _middle_ground() -> Vector2:
	var mid := SerpentCamera.middle(body)
	return Vector2(mid.x, mid.z)


## The city without the buildings the route's body would pass through.
func _cleared(layout: Array[Dictionary]) -> Array[Dictionary]:
	var reach := Num.f(_cfg["wave_amp"]) + Num.f(_cfg["girth"]) + CLEAR_MARGIN
	var out: Array[Dictionary] = []
	for entry: Dictionary in layout:
		var centre := Vector2(Num.f(entry["x"]), Num.f(entry["z"]))
		var half := Vector2(Num.f(entry["w"]), Num.f(entry["d"])) * 0.5
		var near := false
		for p: Vector2 in clear_along:
			var gap := ((p - centre).abs() - half).max(Vector2.ZERO)
			if gap.length() < reach:
				near = true
				break
		if not near:
			out.append(entry)
	return out
