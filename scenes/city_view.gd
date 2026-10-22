class_name CityView
extends Node3D
## The voxel city and its effects: sky and light, ground, buildings (BuildingView: voxels by
## structural chunk), falling sections, physics debris, fires, dust and sparks (Fx), rings,
## flames and floating text. Draws only; RampageSim decides what breaks and what falls.

const DEBRIS_PER_CHUNK := 8
const DEBRIS_PER_LANDING := 160
const FLOAT_TEXT := "float_text"  # world hints' group: the end beat clears it (RampageHud)
const DROP_REACH := 0.8  # a dropped section crushes people this far out from its walls

## Staged (stages.on): _ready builds in stages, one per frame, while the owner draws its loading
## screen between them (b2-30: building the whole city in one call froze the screen for seconds).
var stages := BuildStages.new()
## Whether the city is built (always true after _ready when not staged).
var is_loaded := false

var sim: RampageSim
var fx: Fx
## Civilians, police and moving traffic (null on an empty stage).
var street: StreetLife
## The kaiju's drawn body points (HeadFrame.sight), set by Rampage each frame: the fade keeps
## them in sight beside the sim's own points (R 19.4: a tower over the drawn head or chest fades).
var drawn_sight := PackedVector3Array()
var _rng: RandomNumberGenerator
var _stream: BuildingStream
var _fade: BuildingFade
var _fall_fade := FallFade.new()
var _falling: Dictionary = {}
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


func _ready() -> void:
	if stages.on:
		process_mode = Node.PROCESS_MODE_DISABLED  # street life and traffic wait for the finished city
	CityEnvironment.attach(self, sim)
	_build_ground()
	if not await stages.next(self):
		return
	var colors: Array[Color] = []
	for b: RampageSim.Building in sim.buildings:
		colors.append(_base_color(b))
	_stream = BuildingStream.new(sim, colors)
	_stream.defer_initial = stages.on  # the workers mesh the nearest buildings while the rest builds
	add_child(_stream)
	_fade = BuildingFade.new(sim.buildings, _stream.built)
	fx = Fx.new()
	add_child(fx)
	_debris = DebrisField.new(_rng, int(GraphicsPresets.cap("debris_pool")))
	add_child(_debris)
	_ruins = RuinYard.new(sim, _stream.view)
	add_child(_ruins)
	_topple = ToppleFx.new(self, _rng)
	add_child(_topple)
	add_child(LightPool.new())  # before any lamp, fire or beacon: it lights the nearest few
	Fire.prewarm(self)
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


## Cars, trees and lights under a stomp go flat; people there are crushed (by_tank: StreetLife;
## by_army: a stray shell did it).
func crush(at: Vector3, radius: float, by_tank: bool = false, by_army: bool = false) -> void:
	if _decor != null:
		_decor.crush(at, radius)
	if street != null:
		street.crush(at, radius, by_tank, by_army)


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
	_animate_falls(delta)
	var camera := get_viewport().get_camera_3d()
	if camera != null:  # buildings in front of the kaiju fade to a screen door (D-025)
		var feet := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
		var sight := BuildingFade.sight_of(sim, camera.global_position) + drawn_sight
		_fade.update(camera.global_position, sight, delta)
		_fall_fade.update(falling_pieces(), camera.global_position, sight, delta)  # toppling too
		# Smoke between the camera and the kaiju thins out (smoke.gdshader, director's playtest).
		var depth := (feet - camera.global_position).dot(-camera.global_transform.basis.z)
		RenderingServer.global_shader_parameter_set("smoke_focus", depth)


## The sections falling now (FallFade; the capture tools read them).
func falling_pieces() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for f: Dictionary in _falling.values():
		out.append(f["node"])
	return out


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
	if _with_decor:
		add_child(CitySkyline.new(streets, Seeds.make("skyline", 0)))


func _base_color(b: RampageSim.Building) -> Color:
	var styles := Look.styles()
	return styles[posmod(b.style + roundi(b.x * 3.0 + b.z), styles.size())]


## Chunks broke: their voxels vanish, some fly off as physics debris, dust puffs out.
func chunks_broken(index: int, cells: Array[Vector3i], kaiju_at: Vector3) -> void:
	var view := _stream.view(index)
	if sim.body.over(index):  # the body's bite tears a piece off (BodyBite)
		BodyBite.tear(self, view, cells, kaiju_at, _rng)
		_broke(index, cells)
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


## A section starts to fall: lift its voxels into a piece that topples or drops.
func fall_start(event: Dictionary) -> void:
	var index := Num.i(event["building"])
	var cells: Array[Vector3i] = event["cells"]
	var pivot: Vector3 = event["pivot"]
	var piece := _stream.view(index).lift_piece(cells, pivot)
	if LandmarkBurst.bursts(sim, event):  # a landmark's section bursts where it stands
		piece = LandmarkBurst.new(piece, self, event)
	add_child(piece)
	_falling[Num.i(event["id"])] = {
		"node": piece,
		"kind": str(event["kind"]),
		"dir": event["dir"],
		"drop": Num.f(event["drop"]),
		"duration": maxf(0.05, Num.f(event["duration"])),
		"t": 0.0,
	}
	fx.dust(pivot + Vector3(0, 0.5, 0), 1.0)
	_broke(index, cells)
	if street != null:  # the people under it freeze; its landing crushes the same reach
		street.brace_fall(event, DROP_REACH)


## Gravity drives it: the angle (topple) or the drop grows with the square of time.
func _animate_falls(delta: float) -> void:
	for id: int in _falling:
		var f: Dictionary = _falling[id]
		var node: Node3D = f["node"]
		f["t"] = Num.f(f["t"]) + delta
		var k := clampf(Num.f(f["t"]) / Num.f(f["duration"]), 0.0, 1.0)
		if str(f["kind"]) == "topple":
			_topple.pose(f, delta)
		else:
			node.position.y = (
				node.position.y - (Num.f(f["drop"]) * k * k - Num.f(f.get("dropped", 0.0)))
			)
			f["dropped"] = Num.f(f["drop"]) * k * k


## A section hit the ground (or what was below it): it bursts into debris and dust.
func fall_land(event: Dictionary) -> void:
	var id := Num.i(event["id"])
	if not _falling.has(id):
		return
	var f: Dictionary = _falling[id]
	_falling.erase(id)
	var node: Node3D = f["node"]
	var parts: Array = node.get_meta("parts", [])
	if str(event["kind"]) == "topple" and not (node is LandmarkBurst):
		_topple_land(node, event)
		return
	var landed: Array[Vector3] = []
	for n: int in mini(parts.size(), DEBRIS_PER_LANDING):
		var part: Dictionary = parts[_rng.randi_range(0, parts.size() - 1)]
		var pos: Vector3 = part["pos"]
		var pivot: Vector3 = node.get_meta("pivot")
		var at := node.global_transform * (pos - pivot)
		landed.append(at)
		var color: Color = part["color"]
		debris(at, color, Vector3.UP)
	if sim.buildings[Num.i(event["building"])].landmark != "":
		LandmarkBurst.retire(node, true)
	else:
		_topple.crumble(node)  # crumbles into the street over a moment, never a one-frame pop
	if not landed.is_empty():
		fx.dust(landed[0], 1.5)
		var b := sim.buildings[Num.i(event["building"])]
		if street != null and b.landmark == "":  # came down round its own (not a ring's) walls
			var spill := Num.f(street.tune("fall_spill"))
			street.crush(Vector3(b.x, 0, b.z), maxf(b.w, b.d) * 0.5 + DROP_REACH + spill)


## A tower came down across the street: it breaks up and leaves a rubble strip (ToppleFx); what
## the strip covers is crushed.
func _topple_land(node: Node3D, event: Dictionary) -> void:
	_topple.land(node, event, _stream.view(Num.i(event["building"])).voxels)
	var from: Vector2 = event["from"]
	var to: Vector2 = event["to"]
	var width := Num.f(event["width"])
	var a := Vector3(from.x, 0, from.y)
	var b := Vector3(to.x, 0, to.y)
	var steps := maxi(1, ceili(a.distance_to(b) / 1.5))
	var spill := Num.f(street.tune("fall_spill")) if street != null else 0.0
	var spots: Array[Vector3] = []
	for i: int in steps + 1:
		var at := a.lerp(b, float(i) / steps)
		spots.append(Vector3(at.x, at.z, width * 0.6 + spill))
	crush_all(spots)


## The ruins of the rampage (ToppleFx builds its rubble strips through it).
func ruins() -> RuinYard:
	return _ruins


func debris(pos: Vector3, color: Color, away: Vector3) -> void:
	_debris.spawn(pos, color, away)


## A fire that keeps burning on the ground (wrecks, a crash, a thrown landing); the oldest goes
## out past the cap. Nothing lights one on a collapse: rubble never burns (#111).
func fire(at: Vector3, size: float) -> Fire:
	var f := Fire.new(size, _rng.randf() * 10.0)
	f.position = at
	add_child(f)
	_fires.append(f)
	if _fires.size() > int(GraphicsPresets.cap("max_fires")):
		var old: Fire = _fires.pop_front()
		old.queue_free()
	return f


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
		f.go_out()
	_ruins.mark(index)


## A short burst of real light (muzzle flash, explosion, breath).
func flash(at: Vector3, color: Color, energy: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
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


func float_text(text: String, pos: Vector3, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 96
	l.outline_size = 24
	l.modulate = color
	l.no_depth_test = true
	l.add_to_group(FLOAT_TEXT)
	l.position = pos
	add_child(l)
	var tween := l.create_tween()
	tween.set_parallel(true)
	tween.tween_property(l, "position", pos + Vector3(0, 3, 0), 1.0)
	tween.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.chain().tween_callback(l.queue_free)
