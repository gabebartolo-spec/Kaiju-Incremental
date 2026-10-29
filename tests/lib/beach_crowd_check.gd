extends RefCounted
## The beach's people (scenes/beach_crowd.gd), for the city suite.

const Harbour := preload("res://tests/lib/city_harbour.gd")
const DT := 1.0 / 30.0
const AFTER := 2.0  # seconds after his head breaks the water that the beach's people get to move


## The beach's people (BeachCrowd; D-381 "crowded sand"): on a run that rises from the sea, every
## one stands on the sand where it was put until his head breaks the water (off), and almost every
## one is on the move AFTER seconds later (on).
static func check(tier: int, map_seed: int, host: Node, check_fn: Callable) -> void:
	var sim := Harbour._fresh(tier, map_seed)
	sim.emerge.start(sim)
	var plan := CityGen.map(sim.city)
	var holder := Node3D.new()
	host.add_child(holder)
	var fx := Fx.new()
	holder.add_child(fx)
	var street := StreetLife.new(sim, fx, Seeds.make("civilians", 0))
	holder.add_child(street)
	var start := PackedVector2Array()
	var dry := 0
	for i: int in street.pos.size():
		if street.pinned_until[i] >= BeachCrowd.HELD:
			start.append(street.pos[i])
			dry += 0 if CityHarbour.on_sand(plan, sim.city, street.pos[i]) else 1
	var first := street.pos.size() - start.size()  # the beach's people come last
	var early := 0
	var t := 0.0
	while not sim.emerge.surfaced and t < Num.f(Content.tuning()["emerge"]["max_seconds"]):
		sim.step(DT, Vector2.ZERO, false)
		street._process(DT)
		t += DT
		for k: int in start.size():
			early += 1 if street.pos[first + k] != start[k] else 0
	var surfaced_at := t
	while t < surfaced_at + AFTER:
		sim.step(DT, Vector2.ZERO, false)
		street._process(DT)
		t += DT
	var moved := 0
	for k: int in start.size():
		if first + k < street.pos.size():
			moved += 1 if street.pos[first + k] != start[k] else 0
	holder.free()
	check_fn.call(
		start.size() > 0 and dry == 0 and early == 0 and moved * 10 >= start.size() * 9,
		(
			(
				"stage %d, map_seed %d: %d people on the beach (%d off the sand); %d steps"
				+ " before his head is out (%.1f s), %d on the move %.0f s after"
			)
			% [tier, map_seed, start.size(), dry, early, surfaced_at, moved, AFTER]
		)
	)
