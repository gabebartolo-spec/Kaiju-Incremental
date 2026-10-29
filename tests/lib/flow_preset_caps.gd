extends RefCounted
## The graphics presets' counts (R 18.3; GraphicsPresets.CAPS): every row's counts are frozen at
## rampage start and never change mid-run, a row missing one fails validation, and a Potato run's
## counts reach the systems (CityView's debris pool and fire cap, StreetLife's civilians, every
## particle system's amount_ratio). High holds today's values.

## Today's values, which High keeps exactly (they were constants or tuning keys before R 18.3).
const TODAY := {
	"debris_pool": 600,
	"max_fires": 30,
	"debris_live": 2000,
	"debris_static": 4000,
	"particles": 1.0,
	"crowd_max": 4000,
	"civilians": 3,
}


static func check(tree: SceneTree, check_fn: Callable) -> void:
	var table: Dictionary = Content.section("display")["graphics"]
	var broken := table.duplicate(true)
	var potato: Dictionary = broken["potato"]
	potato.erase("max_fires")
	var found := GraphicsPresets.errors(broken)
	var high: Dictionary = table["high"]
	var same := true
	for key: String in TODAY:
		same = same and is_equal_approx(Num.f(high[key]), Num.f(TODAY[key]))
	check_fn.call(
		found == ["graphics potato: missing max_fires"] and same,
		"a row missing a count fails validation (%s); High keeps today's counts: %s" % [found, same]
	)
	var was := PlayerSettings.graphics
	var frozen := true
	var bad := ""
	for level: Variant in table.keys():
		PlayerSettings.graphics = str(level)
		var rampage := _rampage()
		PlayerSettings.graphics = "potato" if str(level) != "potato" else "max"  # a mid-run change
		var row: Dictionary = table[level]
		for key: String in GraphicsPresets.CAPS:
			if not is_equal_approx(GraphicsPresets.cap(key), Num.f(row[key])):
				frozen = false
				bad = "%s %s = %s" % [level, key, GraphicsPresets.cap(key)]
		rampage.free()
	check_fn.call(frozen, "each row's counts are the run's from its start, never mid-run %s" % bad)
	var slow: Dictionary = table["potato"]
	await _potato_reaches(tree, slow, check_fn)
	PlayerSettings.graphics = was
	GraphicsPresets.start_run(PlayerSettings.graphics_row())


## A Potato run, built: its counts are what the systems use.
static func _potato_reaches(tree: SceneTree, row: Dictionary, check_fn: Callable) -> void:
	PlayerSettings.graphics = "potato"
	var rampage := _rampage()
	PlayerSettings.graphics = "high"  # changed in play: this run keeps Potato
	tree.root.add_child(rampage)
	await rampage.wait_loaded()
	var city: CityView = rampage._city
	for i: int in Num.i(row["max_fires"]) + 5:
		city.fire(Vector3(i, 0, 0), 0.5)
	var ratios := {}
	for p: Node in city.find_children("*", "GPUParticles3D", true, false):
		ratios[(p as GPUParticles3D).amount_ratio] = true
	var people := city.street.civilians()
	var want_people := Num.i(row["civilians"]) * rampage.sim.lot_buildings().size()
	want_people += city.street.beach_people  # the fixed front's sand crowd (#411), not per lot
	check_fn.call(
		(
			city._debris._cap == Num.i(row["debris_pool"])
			and city._fires.size() == Num.i(row["max_fires"])
			and ratios.size() > 0
			and ratios.keys().all(
				func(r: float) -> bool: return is_equal_approx(r, Num.f(row["particles"]))
			)
			and people == want_people
		),
		(
			(
				"a Potato run uses Potato's counts: debris pool %d, fires %d, particle ratios %s,"
				+ " civilians %d of %d"
			)
			% [city._debris._cap, city._fires.size(), ratios.keys(), people, want_people]
		)
	)
	rampage.queue_free()
	await tree.process_frame


static func _rampage() -> Rampage:
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	var rampage := Rampage.new()
	rampage.setup(species, stats, CityGrowth.layout(Content.tuning(), 1, Seeds.make("city", 0)), 0)
	return rampage
