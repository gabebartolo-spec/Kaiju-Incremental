extends RefCounted
## The flow suite's street readings: finding a rampage's StreetLife, and its traffic jams (split
## out of run_flow_tests.gd to keep files small).


## The StreetLife under `node` (depth first), or null.
static func street_life(node: Node) -> StreetLife:
	if node is StreetLife:
		var found: StreetLife = node
		return found
	for child: Node in node.get_children():
		var hit := street_life(child)
		if hit != null:
			return hit
	return null


## Traffic jams (DESIGN D-255): behind a live car a car queues for jam_queue_s, so lines back up;
## behind a wreck it turns round after jam_wreck_s. Before the fix every car gave up after 2.5 s.
static func jams_hold(check: Callable, traffic: Traffic) -> void:
	var cfg := Content.section("street")
	var me := Traffic.Car.new()
	me.pos = Vector2(-500, -500)
	me.dir = Vector2(0, -1)
	var ahead := Traffic.Car.new()
	ahead.pos = me.pos + me.dir * Num.f(cfg["car_gap"]) * 0.5
	var saved := traffic.cars
	traffic.cars = [me, ahead]
	var queue := traffic._blocked(me)
	ahead.crushed = true
	var wreck := traffic._blocked(me)
	traffic.cars = saved
	(
		check
		. call(
			(
				queue == Num.f(cfg["jam_queue_s"])
				and wreck == Num.f(cfg["jam_wreck_s"])
				and queue > wreck
			),
			(
				"a car queues behind a live car (%.1f s) and turns round at a wreck (%.1f s)"
				% [queue, wreck]
			),
		)
	)
