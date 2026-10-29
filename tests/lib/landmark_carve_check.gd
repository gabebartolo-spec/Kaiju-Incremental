extends RefCounted
## The carving suite's player-effect fixture "landmark_carve" ("carve is universal", director
## 2026-10-26; ROADMAP 4), split out to keep the runner small: the stadium as the city builds it,
## one blow on the foot of its rim with the kaiju outside. On: the blow bites the landmark's own
## cells (cells_carved) and its rim arc comes down outward as one topple of fine cells over the
## stub (LandmarkCells' rule, WP6). Off: no cells; the chunk Structure's arc falls as before.

var _check: Callable
var _make: Callable


## check: the runner's check; make(layout, carve) -> RampageSim.
func _init(p_check: Callable, make: Callable) -> void:
	_check = p_check
	_make = make


func run() -> void:
	for carve: bool in [true, false]:
		var sim: RampageSim = _make.call([_stadium()] as Array[Dictionary], carve)
		var b := sim.buildings[0]
		var foot := Vector3i(b.w / 2, 0, b.d - 1)
		while foot.z > 0 and not b.frame.alive(foot):
			foot.z -= 1
		sim.kaiju_pos = Vector2(b.x, b.z + b.d)
		sim.damage_chunks(0, [foot] as Array[Vector3i], INF)
		var carved := 0
		var arc := {}
		for e: Dictionary in sim.events:
			var type := str(e["type"])
			carved += 1 if type == "cells_carved" else 0
			if type == "fall_start" and str(e["kind"]) == "topple" and e["dir"] == Vector2(0, 1):
				arc = e
		var fine: PackedInt32Array = arc.get("index", PackedInt32Array())
		if carve:
			var pivot: Vector3 = arc.get("pivot", Vector3.ZERO)
			var stub := b.frame.arcs.stub
			_check.call(
				sim.carving.takes(0) and carved > 0 and fine.size() >= 100,
				(
					(
						"landmark_carve on: the blow carves the stadium's cells (%d events) and its"
						+ " rim arc falls outward as %d fine cells"
					)
					% [carved, fine.size()]
				)
			)
			var stub_y := b.local_to_world(Vector3(0.0, stub, 0.0)).y
			var tips := "landmark_carve on: the arc tips over its %d-floor stub (pivot y %.2f of %.2f)"
			_check.call(is_equal_approx(pivot.y, stub_y), tips % [stub, pivot.y, stub_y])
		else:
			_check.call(
				not sim.carving.takes(0) and carved == 0 and not arc.is_empty() and fine.is_empty(),
				(
					"landmark_carve off: chunks only (%d carve events, arc fell %s)"
					% [carved, not arc.is_empty()]
				)
			)
		sim.dispose()


## The stadium's layout entry as the city builds it (its baked chunks, its arcs).
static func _stadium() -> Dictionary:
	var shape: Dictionary = Content.landmarks()["stadium"]
	var entry := {
		"x": 0.0,
		"z": 0.0,
		"w": shape["w"],
		"d": shape["d"],
		"h": shape["h"],
		"tier": 1,
		"style": 0,
		"landmark": "stadium",
		"chunks": shape["chunks"],
		"rubble_bonus": 1.5,
	}
	for spec: Dictionary in Content.section("city")["landmarks"]:
		if str(spec["id"]) == "stadium" and spec.has("arcs"):
			entry["arcs"] = spec["arcs"]
	return entry
