class_name VipViewCheck
extends RefCounted
## The leader's view (VipView): in a real Rampage scene the leader lifts off and the strip says so,
## the model flies white and gold with its own lower rotor; shot down it goes to its wreck and the
## strip says that. Seeded by design: the flow suite's city, army seed from run 1.


static func run(suite: SceneTree, check: Callable, stats: Dictionary) -> void:
	var rampage := Rampage.new()
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	rampage.setup(Content.species_def("reptilian"), stats, layout, 1)
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	suite.root.add_child(rampage)
	await suite.physics_frame
	var view: VipView = rampage.find_children("*", "VipView", true, false)[0]
	var vip := rampage.sim.vip
	vip._spawn_at = 0.0
	var frames := 0
	while view._model == null and frames < 300:
		await suite.physics_frame
		frames += 1
	check.call(view._model != null and vip.flying(), "the model lifts off with the sim")
	check.call(
		(
			view._strip != null
			and view._strip._headlines.contains("COWARD MAYOR FLEES CITY BY CHOPPER")
		),
		"the strip announces the escape"
	)
	check.call(
		view._rotor != null and view._rotor.playing and view._rotor.pitch_scale < 1.0,
		"its own, lower rotor is playing"
	)
	# Headless draws nothing and reads back no voxel colours: there the check is that the leader
	# has its own recoloured copy, not the gunships' shared one; the colours are judged in the clip.
	var plain := HelicopterModel.new()
	var own := _first_multimesh(view._model) != _first_multimesh(plain)
	plain.free()
	check.call(own, "the leader wears its own recoloured voxels, the gunships' stay tan")
	if DisplayServer.get_name() != "headless":
		var paint := _body_colour(view._model)
		check.call(
			paint.get_luminance() > 0.7 and paint.r > paint.b,
			"the body is white (a warm white, not tan): %s" % [paint]
		)
	for i: int in 10:
		await suite.physics_frame
	var where := Vector3(vip.pos.x, vip.altitude(), vip.pos.y)
	check.call(view._model.position.distance_to(where) < 3.0, "the model follows the sim's flight")
	rampage.sim.hit_air = true
	vip.hit(func(_p: Vector2, _r: float) -> float: return 1.0, 9999.0)
	rampage.sim.hit_air = false
	for event: Dictionary in rampage.sim.events:  # as a step's events reach the view
		rampage._on_event(event)
	await suite.physics_frame
	await suite.physics_frame
	check.call(
		view._model == null and view._strip._headlines.contains("MAYOR SWATTED FROM THE SKY"),
		"shot down, the model goes to its wreck and the strip says so"
	)
	var hold := Num.f(Content.section("vip")["killed_seconds"])
	check.call(
		absf(view._strip_left - hold) < 0.2 and hold == 3.0,
		(
			"the swatted headline holds %.1f s (the director's 3 s) while play runs on"
			% view._strip_left
		)
	)
	rampage.queue_free()
	await suite.process_frame


## The colour of the brightest-lit body voxel of a model.
static func _body_colour(model: HelicopterModel) -> Color:
	var best := Color.BLACK
	for mmi: MultiMeshInstance3D in model.find_children("*", "MultiMeshInstance3D", true, false):
		for i: int in mmi.multimesh.instance_count:
			var c := mmi.multimesh.get_instance_color(i)
			if c.get_luminance() > best.get_luminance():
				best = c
	return best


static func _first_multimesh(model: Node3D) -> MultiMesh:
	var body := model.get_child(0) as MultiMeshInstance3D  # HelicopterModel's first child
	return body.multimesh
