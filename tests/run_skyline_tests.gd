extends "res://tests/lib/runner.gd"
## Skyline suite: the far insectoid rampaging across the bay (SkylineRampage, director 2026-10-25
## "yes bring it back"), on by default. Player-effect fixture "skyline.rampage": the same seeded
## run with the flag on has the beast spawned and walking, with it off has none.
## Seeded by design: Seeds "city" 0 and the run's own seeded streams; the beast's path is a pure
## function of elapsed time, and no check reads the clock.
##   godot --headless --path . --script tests/run_skyline_tests.gd

const WALK_FRAMES := 90


func suite_name() -> String:
	return "Skyline"


func run_checks() -> void:
	await _t("_check_default_on")
	await _t("_check_beast_walks_when_on")
	await _t("_check_nothing_when_off")


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
