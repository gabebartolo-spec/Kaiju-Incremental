class_name SignatureStrike
extends RefCounted
## The kaiju's signature move as simulation: the breath's cone, Leap Slam's jump and landing, or
## the stomp ring. Part of RampageSim (step() fires it); split out to keep files small. Pure.


static func fire(sim: RampageSim) -> void:
	var reach := sim.ability_reach()
	var damage := sim.stat("ability_damage")
	match sim.ability_type:
		"cone":
			sim.strikes.breath()  # the cone burns at the strike, where he faces then (D-166)
		"leap":
			var from := sim.kaiju_pos
			sim.kaiju_pos = sim.clamp_to_arena(
				sim.kaiju_pos + sim.facing * Num.f(sim.city["leap_distance"]) * sim.body_scale()
			)
			var land := sim.kaiju_pos
			sim.events.append({"type": "ability", "kind": "leap", "reach": reach, "from": from})
			sim.hit_area(
				func(p: Vector2, r: float) -> float:
					return RampageSim.falloff(p.distance_to(land) - r, reach),
				damage
			)
			sim.powers.leap_landed()
		_:
			var centre := sim.kaiju_pos
			sim.events.append({"type": "ability", "kind": "ring", "reach": reach})
			sim.hit_area(
				func(p: Vector2, r: float) -> float:
					return RampageSim.falloff(p.distance_to(centre) - r, reach),
				damage
			)
