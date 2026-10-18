extends RefCounted
## The flow suite's helicopter-sound check (kept here so run_flow_tests.gd stays under its line
## cap): one more helicopter arrives, fires and is shot down through the powers' view, the way
## the sim sends its events, and the rampage hears its rotor, gun and crash.


static func check_heard(
	check: Callable, rampage: Rampage, view: PowersView, species_id: String
) -> void:
	var at := Vector3(rampage.sim.kaiju_pos.x, 0.0, rampage.sim.kaiju_pos.y)
	for event: Dictionary in [
		{"type": "heli_spawned", "heli": 999},
		{"type": "heli_fired", "heli": 999},
		{"type": "heli_destroyed", "heli": 999, "x": at.x + 10.0, "z": at.z},
	]:
		view.on_event(event, at)
	var heard := rampage.sfx.played
	check.call(
		["heli_rotor", "heli_gun", "heli_crash"].all(func(k: String) -> bool: return heard.has(k)),
		"the %s's helicopters are heard flying, firing, falling: %s" % [species_id, heard.slice(-8)]
	)
