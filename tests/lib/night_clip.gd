class_name NightClip
extends RefCounted
## Night darks keep their grain (render plan item 4, looks R1; D-104, D-242). Godot applies the
## look's contrast AFTER the tone map and clamps, so at 1.3 every sRGB value under 0.115 is pure
## black (36% of a night still sat at 0-2 of 255). The AgX toe (looks.json agx_contrast) darkens
## without the cliff. Headless checks: the clip maths, the metric, and that CityEnvironment
## puts the look's two numbers on the Environment. In a windowed run it also renders the stage-3
## night still with the proposed numbers and holds its clipped share under tuning
## render_opt.night_clip_max. The proposal (PROPOSED_*) is what the director sees as stills; when he
## says yes the lead copies it into looks.json and this test then guards the shipped look too.

const Kit := preload("res://tools/capture/capture_kit.gd")
const PROPOSED_AGX := 1.6
const PROPOSED_POST := 1.0
## "Clipped" = the brightest channel at or below this, of 255.
const CLIP_LEVEL := 2
## One pixel in every STRIDE along both axes is read (a 4K still has 8 M).
const STRIDE := 8


static func run(suite: SceneTree, check: Callable) -> void:
	_check_maths(check)
	_check_metric(check)
	_check_grade(check)
	if DisplayServer.get_name() == "headless":
		print("SKIP: the night still needs a window; run windowed with the no-focus override.cfg")
		return
	await _check_render(suite, check)


## sRGB value below which Godot's post-tonemap contrast gives pure black: mix(0.5, s, c) <= 0.
static func zeroed_below(contrast: float) -> float:
	return maxf(0.5 - 0.5 / contrast, 0.0) if contrast > 1.0 else 0.0


## Share of sampled pixels whose brightest channel is at or below `level` of 255.
static func clipped_share(image: Image, level: int = CLIP_LEVEL) -> float:
	var hit := 0
	var seen := 0
	for y: int in range(0, image.get_height(), STRIDE):
		for x: int in range(0, image.get_width(), STRIDE):
			var c := image.get_pixel(x, y)
			seen += 1
			if roundi(maxf(c.r, maxf(c.g, c.b)) * 255.0) <= level:
				hit += 1
	return float(hit) / float(maxi(seen, 1))


static func _check_maths(check: Callable) -> void:
	check.call(
		is_equal_approx(zeroed_below(1.3), 0.5 - 0.5 / 1.3) and zeroed_below(1.3) > 0.115,
		"contrast 1.3 after the tone map turns every sRGB under 0.115 black"
	)
	check.call(zeroed_below(1.0) == 0.0, "contrast 1.0 after the tone map clips nothing")


static func _check_metric(check: Callable) -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(Color8(40, 40, 40))
	for y: int in 48:  # three rows in four are at or below 2 of 255
		for x: int in 64:
			image.set_pixel(x, y, Color8(2, 1, 0))
	check.call(
		is_equal_approx(clipped_share(image), 0.75),
		"the clip metric reads a planted image: %.2f" % clipped_share(image)
	)
	image.fill(Color8(3, 0, 0))
	check.call(clipped_share(image) == 0.0, "a pixel with one channel at 3 is not clipped")


## CityEnvironment.grade puts the look's two numbers on the Environment, nothing else.
static func _check_grade(check: Callable) -> void:
	Content.set_time("night")
	var look := Content.look()
	var saved_agx: Variant = look.get("agx_contrast")
	var saved_post: Variant = look.get("post_contrast")
	check.call(
		saved_agx != null and saved_post != null, "the look carries agx_contrast and post_contrast"
	)
	look["agx_contrast"] = PROPOSED_AGX
	look["post_contrast"] = PROPOSED_POST
	var env := Environment.new()
	CityEnvironment.grade(env)
	check.call(
		is_equal_approx(env.tonemap_agx_contrast, PROPOSED_AGX)
		and is_equal_approx(env.adjustment_contrast, PROPOSED_POST),
		"the environment takes the toe contrast and the post contrast from the look"
	)
	check.call(
		env.tonemap_mode == Environment.TONE_MAPPER_AGX and env.adjustment_enabled,
		"AgX stays the tone map and the grade stays on"
	)
	look["agx_contrast"] = saved_agx
	look["post_contrast"] = saved_post
	CityEnvironment.grade(env)
	check.call(
		is_equal_approx(env.adjustment_contrast, Look.value("post_contrast")),
		"the shipped look's post contrast comes back"
	)


## The stage-3 night still (the adult city, seed 0, the reptilian, as capture_one_look.gd builds
## it), once with today's numbers and once with the proposal.
static func _check_render(suite: SceneTree, check: Callable) -> void:
	var bar := Num.f(Content.section("render_opt")["night_clip_max"])
	var look := Content.look()
	var today_agx: Variant = look.get("agx_contrast")
	var today_post: Variant = look.get("post_contrast")
	var today := await _shoot(suite, Num.f(today_agx), Num.f(today_post))
	var proposed := await _shoot(suite, PROPOSED_AGX, PROPOSED_POST)
	print("NIGHTCLIP today %.3f proposed %.3f bar %.3f" % [today, proposed, bar])
	check.call(
		proposed < bar,
		(
			"with the toe contrast %.1f%% of the night still is at 0-2 of 255 (bar %.0f%%)"
			% [100.0 * proposed, 100.0 * bar]
		)
	)
	check.call(
		proposed < today,
		"the proposal clips less than today's numbers (%.3f vs %.3f)" % [proposed, today]
	)
	look["agx_contrast"] = today_agx
	look["post_contrast"] = today_post


static func _shoot(suite: SceneTree, agx: float, post: float) -> float:
	var stats := Kit.stats("reptilian", Kit.STAGE_LEVELS[2], "reptilian")
	var layout := CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(Content.species_def("reptilian"), stats, layout, 0)
	Content.set_time("night")
	var look := Content.look()
	look["agx_contrast"] = agx
	look["post_contrast"] = post
	rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	suite.root.add_child(rampage)
	var city: CityView = rampage.get("_city")
	var stream: BuildingStream = city.get("_stream")
	while not stream.complete():
		await suite.process_frame
	while rampage.sim.emerge.active:
		await suite.physics_frame
	for _i: int in 4:
		await suite.process_frame
	var image := suite.root.get_viewport().get_texture().get_image()
	var share := clipped_share(image) if image != null else 1.0
	rampage.queue_free()
	await suite.process_frame
	return share
