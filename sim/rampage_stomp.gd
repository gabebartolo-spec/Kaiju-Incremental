class_name RampageStomp
extends RefCounted
## The kaiju's stomp (D-166): a blow that hurts what is under the foot that comes down. It comes
## from its own button (director 2026-10-26: "Its own button", "Button replaces it"; no stomp falls
## on its own): a press stomps once stomp_interval has passed since the last (faster with
## upgrades). A standing body stomps at once, feet alternating; a walking body (one with a step
## clock) lets it fall on the next footfall, on the foot that lands. Part of RampageSim.

var sim: RampageSim
var _timer := 0.0  # seconds until the button stomps again
var _due := false  # pressed: a walking body lets the stomp fall on a footfall


func _init(p_sim: RampageSim) -> void:
	sim = p_sim


## Advances the stomp by dt; `pressed` is the stomp button this step. A press once the last stomp's
## stomp_interval has run out makes one stomp (a standing body stomps at once, a walking one on its
## next footfall); a press sooner is not kept.
func step(dt: float, pressed: bool) -> void:
	_timer = maxf(0.0, _timer - dt)
	if pressed and _timer <= 0.0 and not _due and not sim.airborne and not sim.body.dash.on():
		_timer = interval()
		_due = true
	if sim.body.dash.on():  # no stomp through a leap, crouch to recovery (sim review of #225)
		_due = false
	if _due and (sim.body.footfall_now or not sim.body.walking()):
		_due = false
		_land()


## The stomp's speed, a share of its keyed pace: a body with a "stomp_speed" (the croc: 0.80x,
## Frenzy raises it; director 2026-10-26, "it looks too fast ... weightless rather than titanic",
## "Frenzy becomes your speed-up") stomps slower, never above its stomp_speed_max; others at 1.
func speed() -> float:
	if not sim.stats.has("stomp_speed"):
		return 1.0
	return clampf(sim.stat("stomp_speed"), 0.1, sim.stat("stomp_speed_max"))


## Seconds between stomps: stomp_interval (the keyed pace) over the speed, the stomp's own length
## at that speed, so a held button never cuts one short.
func interval() -> float:
	return maxf(0.1, sim.stat("stomp_interval") / speed())


## One stomp's blow: stomp_damage times the body's stomp_damage_mult (the croc's 1.25 keeps its
## damage a second at 0.80x as it was at full speed; lead call 2026-10-26), else stomp_damage.
func damage() -> float:
	var mult := sim.stat("stomp_damage_mult") if sim.stats.has("stomp_damage_mult") else 1.0
	return sim.stat("stomp_damage") * mult


func _land() -> void:
	var body := sim.body
	var radius := sim.stomp_radius()
	var on_foot := body.walking() and body.footfall_now  # a walking stomp falls on the landing foot
	var left := body.landed_left() if on_foot else body.stomps % 2 == 0
	var centre := body.landed_foot() if on_foot else body.stomp_foot(left)
	body.stomps += 1
	sim.events.append(
		{
			"type": "stomp",
			"radius": radius,
			"lift": sim.stand_y,
			"at": centre,
			"side": "left" if left else "right",
			"on_foot": on_foot,
			"speed": speed()
		}
	)
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			return RampageSim.falloff(p.distance_to(centre) - r, radius),
		damage() * sim.powers.hit_mult(),
		maxi(0, floori(sim.stand_y) - Num.i(sim.powers_cfg["climb_dig"])),
		ceili(sim.reach_top())
	)
