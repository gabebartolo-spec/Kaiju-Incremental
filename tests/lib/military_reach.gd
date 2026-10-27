extends RefCounted
## The tanks' reach is measured to the kaiju's body, as their firing posts are (army-balance,
## D-259). Two seeded fixtures, part of the military suite:
## - a tank posted beside the head of the Colossus's body, in its firing band but further than its
##   reach from the origin (the tail root), fires; measured to the origin it never did (main at
##   27dd83b5: 15 m from the body, 23 m from the tail root, reach 18, did not fire);
## - at every growth stage the body's keep-away sits inside the firing band, so some post is
##   both outside the keep-away and in reach (young croc on main 27dd83b5: keep-away 12.0, band
##   out to 11.6, so no young tank ever fired).
## Seeded by design: city and army seed 0; the tank's spot is the first clear one in a fixed order.

const DT := 1.0 / 15.0
## Where along the body line, origin 0 to head 1, the tank stands abreast of it.
const ALONG: Array[float] = [1.0, 0.95, 0.9, 0.85]
## How far out from the body line the tank stands, as a share of the reach (inside the band).
const OUT := 0.8

var _check: Callable
var _make: Callable


## check: the runner's check; make(tier, seed) -> RampageSim (the suite's _rampage).
func _init(p_check: Callable, make: Callable) -> void:
	_check = p_check
	_make = make


func run() -> void:
	_fires_by_the_head()
	_keep_away_in_band()


func _fires_by_the_head() -> void:
	var sim: RampageSim = _make.call(3, 0)
	var convoy := sim.army_units.convoy
	var head := convoy.posts.head()
	var line := head - sim.kaiju_pos
	var reach := convoy.reach()
	var spot := Vector2(INF, INF)
	var aim := Vector2.ZERO
	for t: float in ALONG:
		for side: float in [1.0, -1.0]:
			var on := sim.kaiju_pos + line * t
			var at := on + line.normalized().orthogonal() * side * reach * OUT
			if spot.x == INF and convoy.clear_line(at, on):
				spot = at
				aim = on
	var tank := RampageSim.Tank.new()
	tank.id = 9999
	tank.pos = spot
	tank.hp = 1000.0
	tank.cooldown = 0.0
	sim.tanks.append(tank)
	sim.events.clear()
	sim.army_units.step(DT)
	var fired := false
	for e: Dictionary in sim.events:
		fired = fired or (str(e["type"]) == "tank_fired" and Num.i(e["tank"]) == tank.id)
	_check.call(
		spot.x < INF and spot.distance_to(sim.kaiju_pos) > reach + 1.0 and fired,
		(
			(
				"a tank %.0f m from the Colossus's body by its head (%.0f m from the tail root, "
				+ "body %.0f m, reach %.0f) fires: %s"
			)
			% [spot.distance_to(aim), spot.distance_to(sim.kaiju_pos), line.length(), reach, fired]
		)
	)


func _keep_away_in_band() -> void:
	var seen: Array[String] = []
	var ok := true
	for tier: int in [1, 2, 3]:
		var sim: RampageSim = _make.call(tier, 0)
		var convoy := sim.army_units.convoy
		var band: Array = convoy.cfg["band"]
		var outer := convoy.reach() * Num.f(band[1])
		ok = ok and convoy.danger() < outer
		seen.append("tier %d keep-away %.1f band to %.1f" % [tier, convoy.danger(), outer])
	_check.call(ok, "the keep-away sits inside the firing band at every stage: %s" % [seen])
