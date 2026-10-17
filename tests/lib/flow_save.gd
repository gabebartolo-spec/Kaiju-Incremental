extends RefCounted
## The flow suite's save checks (tests/lib/flow_screens.gd calls them): an old save migrates, a
## newer one is refused, and a v1 file on disk loads as the current version.


## A version 1 save comes up as version 2 with its best destruction kept; newer is refused.
static func migration(check: Callable) -> void:
	var v1 := {
		"version": 1,
		"species": "cephalopod",
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
	var file := FileAccess.open(SaveFile.PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(v1))
	file.close()
	var loaded := SaveFile.load_game()
	check.call(
		Num.i(loaded.get("version", 0)) == 2 and Num.i(loaded["levels"]["claws"]) == 2,
		"a v1 save file on disk loads as v2"
	)
