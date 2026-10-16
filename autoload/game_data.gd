extends Node
## Runtime access to content and balance. Forwards to Content (sim/content.gd), which tests
## use directly.

var tuning: Dictionary:
	get:
		return {
			"kaiju": Content.section("kaiju"),
			"army": Content.section("army"),
			"city": Content.section("city")
		}
var upgrades: Array[Dictionary]:
	get:
		return Content.upgrades()
var species: Array[Dictionary]:
	get:
		return Content.species()


func section(key: String) -> Dictionary:
	return Content.section(key)


func species_def(id: String) -> Dictionary:
	return Content.species_def(id)


static func load_json(path: String) -> Dictionary:
	return Content.load_json(path)
