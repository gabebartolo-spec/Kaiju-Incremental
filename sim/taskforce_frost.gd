class_name TaskforceFrost
extends RefCounted
## The Taskforce's frost grenades (D-137, D-139, D-145): an agent launches one at street level at
## the kaiju's feet (never its head); if the kaiju still stands there when it lands, ice crusts
## its legs and slows it for `seconds`. Another grenade refreshes the same ice and never stacks
## (one slow, one clock); the dash shatters it early; otherwise it thaws and cracks off.
## Part of Taskforce; pure. Events: frost_launched, frost_hit, frost_cracked.

var sim: RampageSim
var cfg: Dictionary
## Seconds of ice left on the legs (0: none); the view crusts the legs by frost_left / seconds.
var frost_left := 0.0
## Grenades in the air: [seconds left, where it lands (x, z)].
var grenades: Array[Array] = []


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg


## Whether the kaiju is within a launcher's range (`dist` from the agent, ground plane).
func reaches(dist: float) -> bool:
	return dist <= Num.f(cfg["range"])


## The speed multiplier the ice puts on the kaiju: the same slow however many grenades landed.
func mult() -> float:
	return Num.f(cfg["slow_mult"]) if frost_left > 0.0 else 1.0


## An agent at `from` throws a grenade at the kaiju's feet now.
func launch(agent: int, from: Vector3) -> void:
	var feet := sim.kaiju_pos
	grenades.append([Num.f(cfg["flight_s"]), feet])
	sim.events.append(
		{"type": "frost_launched", "agent": agent, "from": from, "x": feet.x, "z": feet.y}
	)


func step(dt: float) -> void:
	var flying: Array[Array] = []
	for grenade: Array in grenades:
		grenade[0] = Num.f(grenade[0]) - dt
		if Num.f(grenade[0]) > 0.0:
			flying.append(grenade)
		else:
			_land(grenade[1])
	grenades = flying
	if frost_left <= 0.0:
		return
	if sim.body.dash.on():
		_crack("dash")
		return
	frost_left -= dt
	if frost_left <= 0.0:
		_crack("thaw")


## A grenade lands: it freezes the kaiju only if it still stands within `radius` (plus its body)
## of the spot; the ice is always the full `seconds`, never longer for a second grenade.
func _land(at: Vector2) -> void:
	var reach := Num.f(cfg["radius"]) + Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	if sim.kaiju_pos.distance_to(at) > reach:
		return
	sim.events.append({"type": "frost_hit", "x": at.x, "z": at.y, "refreshed": frost_left > 0.0})
	frost_left = Num.f(cfg["seconds"])


func _crack(why: String) -> void:
	frost_left = 0.0
	sim.events.append({"type": "frost_cracked", "why": why})
