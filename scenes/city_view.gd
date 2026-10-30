class_name CityView
extends Node3D
## The voxel city and its effects: sky and light, ground, buildings (BuildingView: voxels by
## structural chunk), falling sections, physics debris, fires, dust and sparks (Fx), rings,
## flames. Draws only; RampageSim decides what breaks and what falls.

const DEBRIS_PER_CHUNK := 8

## Staged (stages.on): _ready builds in stages, one per frame, while the owner draws its loading
## screen between them (b2-30: building the whole city in one call froze the screen for seconds).
var stages := BuildStages.new()
## Whether the city is built (always true after _ready when not staged).
var is_loaded := false

var sim: RampageSim
var fx: Fx
## Civilians, police and moving traffic (null on an empty stage).
var street: StreetLife
## Breaks the chunks a red-barrel blast reaches over a few frames (BlastFx sets it).
var blast_break: BlastBreak
## Draws carved buildings from their own fine cells (destruction plan stage 1; null until built).
var carve: CityCarve
var wildlife: WildlifeView  # gulls, pigeons and the whale (null without decor)
var _rng: RandomNumberGenerator
var _stream: BuildingStream
var _bubble: CameraBubble
var _falls: CityFalls
var _falling: Dictionary = {}  # _falls.falling (tests and tools read it)
var _ruins: RuinYard
var _topple: ToppleFx
var _decor: CityDecor
var _fires: Array[Fire] = []
var _chunk_fires := BuildingFires.new()
var _debris: DebrisField

var _with_decor := true


## with_decor false: an empty stage (no streets, cars or trees), e.g. a model line-up.
func _init(p_sim: RampageSim, rng: RandomNumberGenerator, with_decor: bool = true) -> void:
	sim = p_sim
	_rng = rng
	_with_decor = with_decor
	SmokeSoft.apply()  # smoke and dust melt into what they meet (render plan item 13)


func _ready() -> void:
	if stages.on:
		process_mode = Node.PROCESS_MODE_DISABLED  # street life and traffic wait for the finished city
	CityEnvironment.attach(self, sim)
	_build_ground()
	if not await stages.next(self):
		return
	_build_buildings()
	_add_layers()
	if not await stages.next(self):
		return
	if _with_decor:
		_decor = CityDecor.new(sim, Seeds.make("decor", 0))
		add_child(_decor)
		if not await stages.next(self):
			return
		street = StreetLife.new(sim, fx, Seeds.make("civilians", 0), Seeds.derive(_rng, 0x5907))
		add_child(street)
		if not await stages.next(self):
			return
	# Where the kaiju's walk ends (comments #18).
	add_child(ArenaEdge.new(sim, ArenaEdge.trees_of(_decor)))
	while stages.on and not _stream.initial_done():
		if not await stages.next(self, false):
			return
	_stream.finish_initial()
	process_mode = Node.PROCESS_MODE_INHERIT
	is_loaded = true


## The effect layers: dust and sparks, debris, ruins, topples, falls and the light pool.
func _add_layers() -> void:
	fx = Fx.new()
	add_child(fx)
	_debris = DebrisField.new(_rng, int(GraphicsPresets.cap("debris_pool")))
	add_child(_debris)
	_ruins = RuinYard.new(sim, _stream.view)
	add_child(_ruins)
	_topple = ToppleFx.new(self, _rng)
	add_child(_topple)
	_falls = CityFalls.new(self, _stream, _topple, _rng)
	_falling = _falls.falling
	add_child(LightPool.new())  # before any lamp, fire or beacon: it lights the nearest few
	Fire.prewarm(self)


## Building `index` regrew in Endless mode (Endless): its ruin view goes, the sim's standing one
## is built.
func regrow(index: int) -> void:
	carve.forget(index)
	_stream.regrow(index)


func building(index: int) -> BuildingView:  # built now if it waits (SlamView shudders it)
	return _stream.view(index)


## Cars, trees and lights under a stomp go flat; people there are crushed (by_tank: StreetLife;
## by_army: a stray shell did it, so the dead are the army's: ArmyToll).
func crush(at: Vector3, radius: float, by_tank: bool = false, by_army: bool = false) -> void:
	if _decor != null:
		_decor.crush(at, radius)
	if street == null:
		return
	var before := ArmyToll.read(street)
	street.crush(at, radius, by_tank)
	if by_army:
		street.toll.take(street, before)


## Everything on the ground in a breath's cone (BreathCone.of) goes the same way.
func crush_cone(cone: Dictionary) -> void:
	crush_all(BreathCone.cover(cone))


## Everything on the ground within any of `spots` (x, z, radius), as crush() on each in turn,
## with one pass over the people (b2-3: a cone or a topple strip crushes a dozen spots at once).
func crush_all(spots: Array[Vector3]) -> void:
	if _decor != null:
		for s: Vector3 in spots:
			_decor.crush(Vector3(s.x, 0.0, s.y), s.z)
	if street != null:
		street.crush_all(spots)


func _process(delta: float) -> void:
	if not is_loaded:
		return
	_falls.animate(delta)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var feet := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
		# Only what the camera itself runs into is cut away, never the destruction (D-283, D-326).
		var frame := FrameShare.of(camera, get_viewport().get_visible_rect().size)
		_bubble.update(frame, feet, CameraBubble.field(sim), delta)
		# Smoke between the camera and the kaiju thins out (smoke.gdshader, director's playtest).
		var depth := (feet - camera.global_position).dot(-camera.global_transform.basis.z)
		RenderingServer.global_shader_parameter_set("smoke_focus", depth)


## The sections falling now (the capture tools and tests read them). They are never faded or
## cut (D-326).
func falling_pieces() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for f: Dictionary in _falling.values():
		out.append(f["node"])
	return out


## The buildings (streamed in), their fine-grid views and the camera bubble.
func _build_buildings() -> void:
	_stream = BuildingStream.new(sim, BuildingColors.of(sim))
	_stream.defer_initial = stages.on  # the workers mesh the nearest buildings while the rest builds
	add_child(_stream)
	carve = CityCarve.new(sim, _stream)
	add_child(carve)  # after the stream: its views have meshed this frame when it takes them
	_bubble = CameraBubble.new(sim.buildings, _stream.built)


## The street plan's ground and, round a real city, the outskirts, the bay and the skyline.
func _build_ground() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(800.0, 1.0, 800.0)
	shape.shape = box_shape
	shape.position.y = -0.5
	ground.add_child(shape)
	add_child(ground)
	var streets := CityGround.new(sim.city)
	add_child(streets)
	WeatherView.attach(self)  # the run's weather: rain streaks, wet streets, a duller sky
	if _with_decor:
		SkylineRampage.attach(self, CitySkyline.new(streets, Seeds.make("skyline", 0)), _rng)
		wildlife = WildlifeView.attach(self, sim)


## Chunks broke: their voxels vanish, some fly off as physics debris, dust puffs out.
func chunks_broken(index: int, cells: Array[Vector3i], kaiju_at: Vector3) -> void:
	var view := _stream.view(index)
	if sim.body.over(index):  # the body's bite tears a piece off (BodyBite)
		BodyBite.tear(self, view, cells, kaiju_at, _rng)
		_broke(index, cells)
		return
	if blast_break != null and blast_break.takes(index, cells, view):
		_ruins.mark(index)
		return
	var parts := view.hide_chunks(cells)
	parts.append_array(view.chip(cells, _rng))
	var b := sim.buildings[index]
	var centre := Vector3(b.x, 0, b.z)
	var flip := -1.0 if b.landmark != "" else 1.0  # a landmark sheds out onto the street
	var away := (centre - Vector3(kaiju_at.x, 0, kaiju_at.z)).normalized() * flip
	var budget := mini(parts.size(), cells.size() * DEBRIS_PER_CHUNK)
	for n: int in budget:
		var part: Dictionary = parts[_rng.randi_range(0, parts.size() - 1)]
		var pos: Vector3 = part["pos"]
		var color: Color = part["color"]
		debris(pos, color, away)
	var mid := Vector3.ZERO
	for c: Vector3i in cells:
		mid += b.chunk_world(c)
	if cells.size() >= 4:  # only a real collapse throws up a dust cloud
		fx.dust(mid / maxi(1, cells.size()), 0.5 + cells.size() * 0.05)
	_broke(index, cells)


## The sim's fine-grid events (cells_promoted, cells_carved, fall_start): CityCarve draws the
## carved building from its cells; a section starts to fall.
func on_cells(event: Dictionary) -> void:
	if str(event["type"]) == "fall_start":
		fall_start(event)
	else:
		carve.on_event(event)


## A section starts to fall (CityFalls): its piece topples or drops.
func fall_start(event: Dictionary) -> void:
	_falls.start(event)
	var cells: Array[Vector3i] = event["cells"]
	_broke(Num.i(event["building"]), cells)


## A section hit the ground (or what was below it): it bursts into debris and dust.
func fall_land(event: Dictionary) -> void:
	_falls.land(event)


## A foot came down: its dust, and the rubble under it pressed flatter (D-245).
func footfall(at: Vector3, dust: float, body_scale: float) -> void:
	fx.footfall(at + Vector3(0, 0.2, 0), dust)
	var street := Content.section("street")
	_ruins.press(at, Num.f(street["rubble_press"]) * body_scale, Num.f(street["rubble_keep"]))


## The ruins of the rampage (ToppleFx builds its rubble strips through it).
func ruins() -> RuinYard:
	return _ruins


func debris(pos: Vector3, color: Color, away: Vector3) -> void:
	_debris.spawn(pos, color, away)


## A fire that keeps burning on the ground (wrecks, a crash, a thrown landing); the oldest goes
## out past the cap. Nothing lights one on a collapse: rubble never burns (#111).
func fire(at: Vector3, size: float, seconds := 0.0) -> Fire:
	var f := Fire.new(size, _rng.randf() * 10.0)
	f.position = at
	add_child(f)
	_fires.append(f)
	if _fires.size() > int(GraphicsPresets.cap("max_fires")):
		var old: Fire = _fires.pop_front()
		old.queue_free()
	if seconds > 0.0:  # a blast's fire burns for a few seconds, then goes out like any other
		get_tree().create_timer(seconds).timeout.connect(_put_out.bind(f))
	return f


func _put_out(f: Fire) -> void:
	if is_instance_valid(f) and _fires.has(f):
		_fires.erase(f)
		f.go_out()


## A fire the sim lit on one chunk (the beam's coat): it goes out when that chunk breaks or falls.
func burn_chunk(index: int, cell: Vector3i, size: float) -> void:
	var f := fire(sim.buildings[index].chunk_world(cell), size)
	_chunk_fires.add(index, cell, f)


## Chunks broke or fell: fires on them go out, all of the building's once none stand (#111).
func _broke(index: int, cells: Array[Vector3i]) -> void:
	var out := _chunk_fires.cells_gone(index, cells)
	if sim.buildings[index].frame.alive_count == 0:
		out.append_array(_chunk_fires.building_gone(index))
	for f: Fire in out:
		_fires.erase(f)
		f.go_out(Num.f(sim.powers_cfg["fire"]["view_out_fade"]))
	_ruins.mark(index)


## A short burst of real light (muzzle flash, explosion, breath).
func flash(at: Vector3, color: Color, energy: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy * PlayerSettings.flash_scale()  # Reduce flashing (D-259)
	light.omni_range = 3.0 + energy
	light.position = at
	add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, seconds)
	tween.tween_callback(light.queue_free)


static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


## An expanding, fading ring on the ground around `centre`.
func ring(centre: Vector3, radius: float, color: Color, seconds: float) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = mat
	mi.mesh = torus
	mi.position = Vector3(centre.x, 0.3, centre.z)
	mi.scale = Vector3(0.2, 0.3, 0.2)
	add_child(mi)
	var tween := mi.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mi, "scale", Vector3(radius, 0.3, radius), seconds)
	tween.tween_property(mat, "albedo_color:a", 0.0, seconds)
	tween.chain().tween_callback(mi.queue_free)
