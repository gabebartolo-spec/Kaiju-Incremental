extends RefCounted
## The flow suite's save checks (tests/lib/flow_screens.gd calls them): an old save migrates, a
## newer one is refused, and a v1 file from before save slots loads from slot 1 as the current
## version (tests/run_slots_tests.gd holds the slot checks).


## A version 1 save comes up as the current version with its best destruction kept; newer is
## refused.
static func migration(check: Callable) -> void:
	var v1 := {
		"version": 1,
		"species": "reptilian",
		"rubble": 42,
		"levels": {"claws": 2},
		"runs": 3,
		"best_destruction": 0.4
	}
	var up := SaveFile.migrate(v1)
	check.call(
		(
			Num.i(up["version"]) == SaveFile.VERSION
			and Num.f(up["best"]["destruction"]) == 0.4
			and not up.has("best_destruction")
			and Num.i(up["rubble"]) == 42
		),
		"a v1 save migrates to v%d keeping its best and its bank: %s" % [SaveFile.VERSION, up]
	)
	check.call(
		SaveFile.migrate({"version": SaveFile.VERSION + 1}).is_empty(),
		"a save from a newer version is refused"
	)
	SaveFile.wipe()  # the pre-slots file moves into the first empty slot
	var file := FileAccess.open(SaveFile.LEGACY_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(v1))
	file.close()
	var loaded := SaveFile.load_game(1)
	check.call(
		(
			Num.i(loaded.get("version", 0)) == SaveFile.VERSION
			and Num.i(loaded["levels"]["claws"]) == 2
		),
		"a v1 save file on disk loads as v%d" % SaveFile.VERSION
	)
	_refund(check)


## A v2 save that bought EVOLVE: Apex Titan (cut, D-135) comes up as v3 with the node gone and
## its rubble back in the bank, every other level and the top skill it unlocked kept.
static func _refund(check: Callable) -> void:
	var refund := Num.i(Content.section("save")["refunds"]["evolve3"])
	var v2 := {
		"version": 2,
		"species": "reptilian",
		"rubble": 1000,
		"levels": {"claws": 5, "evolve1": 1, "evolve2": 1, "evolve3": 1, "r_beam": 2},
		"runs": 40,
		"best": {"rubble": 9.0}
	}
	var up := SaveFile.migrate(v2)
	var levels: Dictionary = up["levels"]
	check.call(
		(
			Num.i(up["version"]) == SaveFile.VERSION
			and not levels.has("evolve3")
			and Num.i(up["rubble"]) == 1000 + refund
			and Num.i(levels["r_beam"]) == 2
			and Num.i(levels["evolve2"]) == 1
			and Num.i(up["runs"]) == 40
		),
		(
			"a v2 save with Apex Titan comes up as v%d, refunded %d rubble: %s"
			% [SaveFile.VERSION, refund, up]
		)
	)
	var tree := UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def("reptilian"), tree
	)
	check.call(
		Num.i(stats["size"]) == 3,
		"the migrated tree is the adult (size 3) and still owns the beam it unlocked"
	)
	var again := SaveFile.migrate(up)
	check.call(again == up, "migrating a current save changes nothing")
	var plain := SaveFile.migrate({"version": 2, "rubble": 7, "levels": {"claws": 1}})
	check.call(Num.i(plain["rubble"]) == 7, "a v2 save without the cut node keeps its bank")
