class_name SignatureStrike
extends RefCounted
## The kaiju's signature move as simulation: the croc's tail lash, the breath's cone, Leap
## Slam's jump and landing, or the stomp ring. Part of RampageSim (step() fires it); split out
## to keep files small. Pure.


static func fire(sim: RampageSim) -> void:
	var reach := sim.ability_reach()
	var damage := sim.stat("ability_damage")
	match sim.ability_type:
		"lash":
			sim.powers.wind_lash()
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


## The signature, the croc's breath button (D-401) and the ultimate, each on its own cooldown.
static func step_buttons(sim: RampageSim, dt: float, signature_pressed: bool, buttons: int) -> void:
	sim.ability_ready_in = maxf(0.0, sim.ability_ready_in - dt)
	var lash := sim.ability_type == "lash"
	if signature_pressed and sim.ability_ready_in <= 0.0:
		var cd := Num.f(sim.powers_cfg["lash_cooldown"]) if lash else sim.stat("ability_cooldown")
		sim.ability_ready_in = maxf(0.5, cd)
		fire(sim)
	sim.breath_ready_in = maxf(0.0, sim.breath_ready_in - dt)
	if lash and buttons & RampageSim.BREATH != 0 and sim.breath_ready_in <= 0.0:
		sim.breath_ready_in = maxf(0.5, sim.stat("ability_cooldown"))
		sim.strikes.breath()  # the cone burns at the strike, where he faces then (D-166)
	sim.ultimate_ready_in = maxf(0.0, sim.ultimate_ready_in - dt)
	if (
		buttons & RampageSim.ULTIMATE != 0
		and sim.ultimate_ready_in <= 0.0
		and sim.powers.has_ultimate()
	):
		sim.ultimate_ready_in = Num.f(sim.powers_cfg["ultimate_cooldown"])
		sim.powers.ultimate()
