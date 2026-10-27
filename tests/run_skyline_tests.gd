extends "res://tests/lib/runner.gd"
## Skyline suite: the far insectoid rampaging across the bay (SkylineRampage, director 2026-10-25
## "yes bring it back"), on by default. Player-effect fixture "skyline.rampage": the same seeded
## run with the flag on has the beast spawned and walking, with it off has none.
## The far city in the bay's air (director comment #37, 2026-10-25, asked twice: "something funky
## going on with the distant city"), on by default. Player-effect fixture "skyline.far_fog": with
## tuning city far_fog on every far material takes the engine's fog and height fog at its foot, and
## the fog never thins from the bay to the far city; off, the far city keeps its built look and is
## clearer than the bay in front of it.
## Seeded by design: Seeds "city" 0 and the run's own seeded streams; the beast's path is a pure
## function of elapsed time, and no check reads the clock.
##   godot --headless --path . --script tests/run_skyline_tests.gd

enum { BAY_NEAR, BAY_FAR, FOOT, CROWN }  # _fog_line's points

const WALK_FRAMES := 90
const FAR_MATERIALS := 5  # the far towers, the hazy plain boxes (2), the far beast and its smoke
const FRONT := 12.0  # CitySkyline._far_shore: the first far row stands this far behind the shore
const FOOT_Y := 1.0
const CROWN_Y := 60.0  # a tall far tower's upper floors
const FOOT_OVER_CROWN := 0.02  # the height fog: the far city's foot at least this much hazier


func suite_name() -> String:
	return "Skyline"


func run_checks() -> void:
	await _t("_check_default_on")
	await _t("_check_beast_walks_when_on")
	await _t("_check_nothing_when_off")
	await _t("_check_far_city_in_the_bay_air")
	await _t("_check_far_city_floats_when_off")


func _check_default_on() -> void:
	var on: Variant = Content.section("skyline_rampage").get("on", false)
	var enabled: bool = on is bool and on
	check(enabled, "tuning skyline_rampage.on defaults to true (the feature is in the game)")
	check(
		str(Content.section("skyline_rampage").get("species", "")) == "insectoid",
		"the far beast is the insectoid"
	)


func _check_beast_walks_when_on() -> void:
	var rampage := await _run(true)
	var far := _find(rampage)
	check(far != null, "with the flag on a SkylineRampage stands in the run")
	if far != null:
		var beasts := far.find_children("*", "FarBeast", false, false)
		check(beasts.size() == 1, "the far beast is spawned (%d)" % beasts.size())
		var first := far.beast_at()
		var t0 := far.elapsed
		for _i: int in WALK_FRAMES:
			await process_frame
		check(far.elapsed > t0, "the far rampage clock runs")
		check(
			far.beast_at().distance_to(first) > 0.5,
			"the far beast moves along the far shore (%.2f)" % far.beast_at().distance_to(first)
		)
		check(far.fallen() >= 0, "its fallen towers are counted")
	rampage.queue_free()
	await process_frame


func _check_nothing_when_off() -> void:
	var rampage := await _run(false)
	check(_find(rampage) == null, "with the flag off no far rampage is built")
	rampage.queue_free()
	await process_frame
	Content.section("skyline_rampage")["on"] = true


## On by default: every far material (towers, quay, lattice tower, the far beast and its smoke)
## takes the engine's fog and the height fog; the fog never thins from the bay to the far city's
## foot, and the foot is hazier than the crown (no crisp base line).
func _check_far_city_in_the_bay_air() -> void:
	var cfg: Dictionary = Content.section("city")["far_fog"]
	var on: Variant = cfg.get("on", false)
	var enabled: bool = on is bool and on
	check(enabled, "tuning city far_fog.on defaults to true (the fix is in the game)")
	var rampage := await _run(true)
	var mats := _skyline(rampage).far_haze.materials()
	check(mats.size() == FAR_MATERIALS, "every far material takes the far haze (%d)" % mats.size())
	for mat: ShaderMaterial in mats:
		var file := mat.shader.resource_path.get_file()
		check(file.ends_with("_fogged.gdshader"), "%s takes the engine's fog" % file)
		check(
			is_equal_approx(Num.f(mat.get_shader_parameter("haze_base")), Num.f(cfg["base"])),
			"%s has the height fog at its foot" % file
		)
	var fog := _fog_line(rampage)
	check(
		fog[BAY_NEAR] <= fog[BAY_FAR] and fog[BAY_FAR] <= fog[FOOT],
		"the fog never thins from the bay to the far city's foot (%s)" % [fog]
	)
	check(
		fog[FOOT] > fog[CROWN] + FOOT_OVER_CROWN,
		"the far city's foot sinks in the haze (%s)" % [fog]
	)
	rampage.queue_free()
	await process_frame


## Player-effect fixture "skyline.far_fog": off, the far city keeps the look it was built with (its
## own shaders, no engine fog) and stands clearer than the bay in front of it.
func _check_far_city_floats_when_off() -> void:
	var cfg: Dictionary = Content.section("city")["far_fog"]
	cfg["on"] = false
	var rampage := await _run(true)
	for mat: ShaderMaterial in _skyline(rampage).far_haze.materials():
		var file := mat.shader.resource_path.get_file()
		check(not file.ends_with("_fogged.gdshader"), "off: %s as built" % file)
	var fog := _fog_line(rampage)
	check(
		fog[FOOT] < fog[BAY_FAR], "off: the far city is clearer than the bay before it (%s)" % [fog]
	)
	rampage.queue_free()
	await process_frame
	cfg["on"] = true


func _run(on: bool) -> Rampage:
	Content.section("skyline_rampage")["on"] = on
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0))
	var rampage := Rampage.new()
	rampage.setup(species, stats, layout, 0)
	root.add_child(rampage)
	for _i: int in 5:
		await process_frame
	return rampage


func _find(rampage: Rampage) -> SkylineRampage:
	var found := rampage.find_children("*", "SkylineRampage", true, false)
	return null if found.is_empty() else found[0] as SkylineRampage


func _skyline(rampage: Rampage) -> CitySkyline:
	return rampage.find_children("*", "CitySkyline", true, false)[0] as CitySkyline


## The share of fog the eye sees from the game camera at the bay's near and far water and at the far
## city's front row foot and crown: the engine's depth fog, then the far materials' own haze and
## height fog as FarHaze has them (tools/capture/capture_far_city.gd writes the same line).
func _fog_line(rampage: Rampage) -> PackedFloat64Array:
	var skyline := _skyline(rampage)
	var cam := root.get_camera_3d().global_position
	var density := 0.0
	for world: WorldEnvironment in rampage.find_children("*", "WorldEnvironment", true, false):
		if world.get_viewport() == root and world.environment.fog_enabled:
			density = world.environment.fog_density
	var shore := skyline.ground.coast - Num.f(skyline.cfg["bay_width"])
	var built := Num.f(skyline.cfg["far_haze"])
	var points: Array[Vector3] = [
		Vector3(cam.x, CityGround.WATER_Y, skyline.ground.coast - 10.0),
		Vector3(cam.x, CityGround.WATER_Y, shore + 10.0),
		Vector3(cam.x, FOOT_Y, shore - FRONT),
		Vector3(cam.x, CROWN_Y, shore - FRONT),
	]
	var out := PackedFloat64Array()
	for p: Vector3 in points:
		var metres := cam.distance_to(p)
		var fog := 1.0 - exp(-metres * density)
		if p.z < shore:
			var own := skyline.far_haze.share_at(metres, p.y, built)
			fog = 1.0 - (1.0 - own) * (1.0 - fog) if skyline.far_haze.fogged else own
		out.append(snappedf(fog, 0.001))
	return out
