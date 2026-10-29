class_name RampageStomp
extends RefCounted
## The kaiju's stomp (D-166): a blow every stomp_interval that hurts what is under the foot that
## comes down. A standing body stomps at once, feet alternating; a walking body (one with a step
## clock) lets it fall on the footfall, on the foot that lands, and every blow that came due while
## the foot was up falls with it (D-302: a longer, slower step clears as much per metre). Part of
## RampageSim.

var sim: RampageSim
var _timer := 0.0
var _due := 0  # blows come due since the last stomp: a walking body lets them fall on a footfall


func _init(p_sim: RampageSim) -> void:
	sim = p_sim


## Advances the stomp timer: a stomp comes due every stomp_interval, and falls when a walking
## body's foot lands (a standing body stomps at once).
func step(dt: float) -> void:
	_timer -= dt
	if _timer <= 0.0:
		_timer += maxf(0.1, sim.stat("stomp_interval"))
		_due = 0 if sim.airborne else _due + 1
	if sim.body.dash.on():  # no stomp through a leap, crouch to recovery (sim review of #225)
		_due = 0
	if _due > 0 and (sim.body.footfall_now or not sim.body.walking()):
		var blows := _due
		_due = 0
		_land(blows)


## The foot comes down with `blows` stomps' force (those come due since the last).
func _land(blows: int) -> void:
	var body := sim.body
	var radius := sim.stomp_radius()
	var on_foot := body.walking() and body.footfall_now  # a walking stomp falls on the landing foot
	var left := body.landed_left() if on_foot else body.stomps % 2 == 0
	var centre := body.landed_foot() if on_foot else body.stomp_foot(left)
	body.stomps += 1
	var wait := sim.strikes.stomp_delay(on_foot)  # the croc's standing stomp lands with the foot
	sim.events.append(
		{
			"type": "stomp",
			"radius": radius,
			"lift": sim.stand_y,
			"at": centre,
			"side": "left" if left else "right",
			"on_foot": on_foot,
			"strike_in": wait,
			"blows": blows
		}
	)
	sim.strikes.stomp(centre, wait, blows)
