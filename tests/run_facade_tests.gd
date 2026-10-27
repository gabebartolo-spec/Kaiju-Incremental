extends "res://tests/lib/runner.gd"
## Facade suite (D-289, director 2026-10-27: "when a building gets carved anywhere, its whole
## facade changes texture, so even if you carve the bottom of a tower, the top of the tower is
## changing appearance too"): the first blow on a building changes only the facade near the cut.
## Every facade archetype is built as a BuildingView, the street-side base chunk is broken the
## way CityView does (hide_chunks, then chip), and the faces the player sees from outside on the
## upper floors must be exactly the faces seen before the blow.
## Seeded by design: fixed buildings, one fixed chip seed; no clock.
##   godot --headless --path . --script tests/run_facade_tests.gd

## Each fixture: [name, x, z, w, d, floors, style]; style % 4 is the archetype.
const FIXTURES: Array = [
	["office", 10.5, 4.5, 3, 3, 8, 0],
	["brick", 20.5, 4.5, 3, 3, 8, 1],
	["glass", 30.5, 4.5, 3, 3, 8, 2],
	["stone", 40.5, 4.5, 3, 3, 8, 3],
]
## The floors from this one up are far from the cut (the base chunk and the chip round it).
const FAR_FROM_FLOOR := 3

const FacadeFaces := preload("res://tests/lib/facade_faces.gd")


func suite_name() -> String:
	return "Facade"


func run_checks() -> void:
	await _t("_check_first_blow_leaves_upper_floors_alone")
	await _t("_check_floors_show_only_next_to_the_blow")
	await _t("_check_a_broken_building_shows_the_base_blow")


func _building(f: Array) -> RampageSim.Building:
	var b := RampageSim.Building.new()
	b.x = f[1]
	b.z = f[2]
	b.w = f[3]
	b.d = f[4]
	b.height = f[5]
	b.tier = 2
	b.style = f[6]
	b.frame = Structure.new(b.w, b.d, b.height, 1.0)
	return b


## The street-side chunk at the base, as a blow on the ground floor breaks it.
func _blow(view: BuildingView) -> void:
	var cut: Array[Vector3i] = [Vector3i(view.b.w - 1, 0, view.b.d / 2)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	view.hide_chunks(cut)
	view.chip(cut, rng)


func _check_first_blow_leaves_upper_floors_alone() -> void:
	for f: Array in FIXTURES:
		var view := BuildingView.new(_building(f), Color("8a7f72"))
		var before := FacadeFaces.seen_from_outside(view)
		_blow(view)
		var after := FacadeFaces.seen_from_outside(view)
		var changed := FacadeFaces.changed_from_floor(before, after, FAR_FROM_FLOOR)
		check(
			changed == 0,
			(
				"%s: faces seen from outside on floor %d and up are the same after the blow (%d of %d changed)"
				% [f[0], FAR_FROM_FLOOR, changed, before.size()]
			)
		)
		view.free()


## The floors inside show next to the blow only: what the unbroken facade shows through its gaps
## (the hole a hidden balcony slab leaves in a brick wall) stays what it was standing.
func _check_floors_show_only_next_to_the_blow() -> void:
	for f: Array in FIXTURES:
		var view := BuildingView.new(_building(f), Color("8a7f72"))
		var standing := FacadeFaces.floors_drawn_from(view, 0)
		_blow(view)
		var far := FacadeFaces.floors_drawn_from(view, FAR_FROM_FLOOR)
		var near := FacadeFaces.floors_drawn_from(view, 0) - far
		check(
			standing == 0, "%s: no floor is drawn while the building stands (%d)" % [f[0], standing]
		)
		check(
			far == 0,
			(
				"%s: no floor is drawn on floor %d and up after the blow (%d)"
				% [f[0], FAR_FROM_FLOOR, far]
			)
		)
		check(near > 0, "%s: the floors next to the blow are drawn (%d)" % [f[0], near])
		view.free()


## The check is not blind: the blow does change the facade where it lands.
func _check_a_broken_building_shows_the_base_blow() -> void:
	for f: Array in FIXTURES:
		var view := BuildingView.new(_building(f), Color("8a7f72"))
		var before := FacadeFaces.seen_from_outside(view)
		_blow(view)
		var after := FacadeFaces.seen_from_outside(view)
		var near := (
			FacadeFaces.changed_from_floor(before, after, 0)
			- FacadeFaces.changed_from_floor(before, after, FAR_FROM_FLOOR)
		)
		check(
			near > 0, "%s: the blow changes the faces on the floors it lands on (%d)" % [f[0], near]
		)
		view.free()
