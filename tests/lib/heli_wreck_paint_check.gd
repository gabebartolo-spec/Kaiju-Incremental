class_name HeliWreckPaintCheck
extends RefCounted
## A wreck's chunks wear the paint of the helicopter they came from (HeliWreck, HeliDebris,
## HelicopterModel.debris_paint): in a real Rampage scene a shot-down gunship breaks into olive
## chunks and the leader's helicopter into white and gold ones, never the other way round (a
## white-and-gold helicopter breaking into olive chunks is a wrong-colour defect, D-324). Seeded by
## design: the flow suite's city.


static func run(suite: SceneTree, check: Callable, stats: Dictionary) -> void:
	var rampage := Rampage.new()
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	rampage.setup(Content.species_def("reptilian"), stats, layout, 1)
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	suite.root.add_child(rampage)
	await suite.physics_frame
	var sim := rampage.sim
	# A gunship shot down by a killing blow: the sim's events reach the view as a step's would.
	sim.events.clear()
	sim.air.spawn()
	_deliver(rampage)
	sim.air.hit(func(_p: Vector2, _r: float) -> float: return 1.0, 9999.0, true)
	_deliver(rampage)
	await suite.physics_frame
	var olive := _chunks(rampage._powers._wrecks._debris)
	var gunship_paint: Array[Color] = HelicopterModel.GUNSHIP_PAINT
	check.call(olive.size() > 0, "a shot-down gunship throws wreck chunks (%d)" % olive.size())
	check.call(
		_paint_is(olive, gunship_paint), "the gunship's wreck chunks are olive: %s" % [olive]
	)
	var debris: HeliDebris = rampage._powers._wrecks._debris
	check.call(
		_shared(debris),
		"every wreck chunk draws the one shared box mesh, one material per colour (draw batching)"
	)
	# The leader's helicopter shot down the same way.
	var view: VipView = rampage.find_children("*", "VipView", true, false)[0]
	sim.vip._spawn_at = 0.0
	var frames := 0
	while view._model == null and frames < 300:
		await suite.physics_frame
		frames += 1
	var leader_paint := view._model.debris_paint()
	sim.hit_air = true
	sim.vip.hit(func(_p: Vector2, _r: float) -> float: return 1.0, 9999.0)
	sim.hit_air = false
	_deliver(rampage)
	await suite.physics_frame
	var white := _chunks(view._wreck._debris)
	check.call(white.size() > 0, "the shot-down leader throws wreck chunks (%d)" % white.size())
	check.call(
		_paint_is(white, leader_paint), "the leader's wreck chunks are white and gold: %s" % [white]
	)
	check.call(
		not leader_paint.has(HelicopterModel.PAINT) and leader_paint != gunship_paint,
		"the leader's two paints are its own, not the gunship's olive: %s" % [leader_paint]
	)
	rampage.queue_free()
	await suite.process_frame


## The sim's events since the last call, reaching the view as a step's would.
static func _deliver(rampage: Rampage) -> void:
	for event: Dictionary in rampage.sim.events.duplicate():
		rampage._on_event(event)
	rampage.sim.events.clear()


## The paint colours of the wreck's thrown chunks (boxes; the model's own parts are voxel meshes):
## every chunk but the charred ones (HeliDebris.CHARCOAL, SCORCH), sorted into a set.
static func _chunks(debris: HeliDebris) -> Array[Color]:
	var out: Array[Color] = []
	for node: Node in debris.get_children():
		var box := node as MeshInstance3D
		if box == null or not box.mesh is BoxMesh:
			continue
		var mat := box.material_override as StandardMaterial3D
		var colour := mat.albedo_color
		if colour in [HeliDebris.CHARCOAL, HeliDebris.SCORCH] or out.has(colour):
			continue
		out.append(colour)
	return out


## True when all the wreck's chunks share one mesh and every chunk of a colour one material.
static func _shared(debris: HeliDebris) -> bool:
	var meshes := {}
	var mats := {}
	for node: Node in debris.get_children():
		var box := node as MeshInstance3D
		if box == null or not box.mesh is BoxMesh:
			continue
		meshes[box.mesh] = true
		var mat := box.material_override as StandardMaterial3D
		if mats.get(mat.albedo_color, mat) != mat:
			return false
		mats[mat.albedo_color] = mat
	return meshes.size() == 1


## Every distinct paint chunk is one of the helicopter's `paint` tones, and each tone is thrown.
static func _paint_is(seen: Array[Color], paint: Array[Color]) -> bool:
	for colour: Color in seen:
		if not paint.has(colour):
			return false
	for tone: Color in paint:
		if not seen.has(tone):
			return false
	return true
