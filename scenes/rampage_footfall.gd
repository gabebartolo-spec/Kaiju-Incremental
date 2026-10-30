class_name RampageFootfall
extends RefCounted
## The rampage's footfalls: dust, a ring, a camera dip and a step sound each, and the stomp the sim
## decided landing under the foot that delivers it.


## Every footfall kicks a little dust, nudges the camera and sounds a step (or the stomp that
## was waiting for this foot), so what you hear lands with what you see.
static func footfall(r: Rampage, side: String, strength: float, at: Vector3) -> void:
	var stomped := r._stomp_wait > 0.0 and side != "tail" and r._stomp_side in ["", side]
	if stomped:
		land_stomp(r, side, at)
	r.sfx.footstep(strength)
	var size := r.sim.body_scale() * (0.2 + strength)
	if side != "tail":  # a tail slam throws its own puffs (Fx.shockwave)
		r._city.footfall(at, Rampage.FOOTFALL_DUST * size, r.sim.body_scale())
	var ring := r._stomp_radius * 1.3 * Fx.STOMP_RING if stomped else Rampage.FOOTFALL_RING * size
	r._city.fx.shockwave(at, ring, side == "tail", stomped)
	var dip := (
		Rampage.FOOTFALL_DIP * maxf(Rampage.FOOTFALL_DIP_FLOOR, r.sim.body_scale()) * strength
	)
	r._step_dip = maxf(r._step_dip, dip)


## The waiting stomp lands under the foot that delivers it: cracks (if heavy enough), the street
## crushed around that foot, one dust ripple. Sound is released by the same footfall (Sfx.footstep).
static func land_stomp(r: Rampage, side: String, at: Vector3) -> void:
	r._stomp_wait = 0.0
	r.rumble.stomp()
	var heavy := r._power("stomp_damage")
	r.sfx.stomp(heavy, r._land.landed(side, r.ability_fx.stomp_cracks(at, r._stomp_radius, heavy)))
	var street := r._city.street  # the foot lands wider than its ring (stomp_catch)
	var catch := street.tune("stomp_catch") * r.sim.body_scale() if street != null else 0.0
	r._city.crush(at, r._stomp_radius + catch)
	r.stomp_ring_at.append(at)
