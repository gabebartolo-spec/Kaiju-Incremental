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
	# Headless draws nothing and a MultiMesh reads back no voxel colours, so the paint is read from
	# the colours the model kept as it painted (HelicopterModel.painted), not from the GPU.
	var plain := HelicopterModel.new()
	var own := _first_multimesh(view._model) != _first_multimesh(plain)
	var gunless := not view._model._gun.visible and plain._gun.visible
	plain.free()
	check.call(own, "the leader wears its own recoloured voxels, the gunships' stay theirs")
	check.call(gunless, "the leader carries no gun, a gunship does")
	_check_paint(view._model, check)
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


## What the leader was painted (D-149: a white body with a gold band, gold rotors), read from the
## colours its model kept as it painted its own voxels. Fails when the view stops painting (nothing
## kept), paints the gunships' tan, or paints a part the wrong colour. Runs headless and on a GPU.
static func _check_paint(model: HelicopterModel, check: Callable) -> void:
	var look: Dictionary = Content.section("vip")["look"]
	var white := Color(str(look["white"]))
	var gold := Color(str(look["gold"]))
	var body: PackedColorArray = model.painted.get("body", PackedColorArray())
	var whites := 0
	var golds := 0
	var sum := Color(0.0, 0.0, 0.0, 0.0)
	for c: Color in body:
		if _is_shade_of(c, white):
			whites += 1
			sum += c
		elif _is_shade_of(c, gold):
			golds += 1
	check.call(
		whites * 2 > body.size() and golds > 0 and golds < whites,
		(
			"the body is white with a gold band: %d white, %d gold of %d voxels"
			% [whites, golds, body.size()]
		)
	)
	var mean := sum / maxf(1.0, whites)
	check.call(
		whites > 0 and mean.get_luminance() > 0.8 and mean.r >= mean.b,
		"...a warm white (mean %s), not the gunships' olive" % [mean]
	)
	var rotor_voxels := 0
	var gold_voxels := 0
	for part: String in ["main_rotor", "tail_rotor"]:
		var voxels: PackedColorArray = model.painted.get(part, PackedColorArray())
		rotor_voxels += voxels.size()
		for c: Color in voxels:
			gold_voxels += 1 if _is_shade_of(c, gold) else 0
	check.call(
		rotor_voxels > 0 and gold_voxels == rotor_voxels,
		"...and both rotors gold: %d of %d voxels" % [gold_voxels, rotor_voxels]
	)
	print(
		(
			"VIP paint (headless-readable): body %d white + %d gold of %d, mean white %s; rotors %d/%d gold"
			% [whites, golds, body.size(), mean, gold_voxels, rotor_voxels]
		)
	)


## Whether `c` is `ref` times one shade factor (HelicopterModel keeps a voxel's own light, within
## 0.8 to 1.15 of the colour it paints).
static func _is_shade_of(c: Color, ref: Color) -> bool:
	var shade := c.r / ref.r
	return (
		shade > 0.79
		and shade < 1.16
		and absf(c.g - ref.g * shade) < 0.01
		and absf(c.b - ref.b * shade) < 0.01
	)


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
