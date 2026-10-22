class_name BreathCone
extends RefCounted
## The cone a cone breath (the reptilian's Atomic Breath) burns, the sim's one definition of it:
## RampageSim fires it and BreathAim (presentation) draws it while the breath is ready.
## It starts at the snout: kaiju_pos is the model's origin, on the croc its tail root, and the
## snout is city "breath_snout_ahead" model lengths ahead (per size tier, x body scale; measured
## from the reptilian rigs: baby 10.4, adolescent 10.3, adult 13.5). It runs along the facing
## out to the ability's reach, within cone_half_angle_deg either side.

## Half the diagonal of a unit square: the radius of a circle that covers it.
const SQUARE_HALF_DIAGONAL := 0.7071068


## {"origin": Vector2, "dir": Vector2, "reach": float, "half_angle": float (radians)}.
static func of(sim: RampageSim) -> Dictionary:
	var snout: Array = sim.city["breath_snout_ahead"]
	var ahead := Num.f(snout[mini(sim.size_tier(), snout.size() - 1)]) * sim.body_scale()
	var half := deg_to_rad(Num.f(sim.city["cone_half_angle_deg"]))
	var at := sim.kaiju_pos + sim.facing * ahead
	return {"origin": at, "dir": sim.facing, "reach": sim.ability_reach(), "half_angle": half}


## Fires the breath (the signature): burns what BreathAim shows by `damage`, reaches up to the
## helicopters, and with City Ablaze owned can set the buildings it hits alight (D-129).
static func breathe(sim: RampageSim, reach: float, damage: float) -> void:
	var aim := of(sim)
	var half_angle := Num.f(aim["half_angle"])
	var origin: Vector2 = aim["origin"]
	var dir := sim.facing
	sim.events.append({"type": "ability", "kind": "cone", "reach": reach, "from": origin})
	var cone := func(p: Vector2, r: float) -> float:
		var to := p - origin
		if to.length() > reach + r:
			return 0.0
		return 1.0 if to.length() <= r or absf(dir.angle_to(to)) <= half_angle else 0.0
	# The ignite rolls come first, on the buildings as they stood: a block the breath then breaks
	# was still in its path (lead 2026-10-22, baby-stage finding).
	sim.powers.fire.scorch(Rect2(origin - Vector2.ONE * reach, Vector2.ONE * reach * 2.0), cone)
	sim.hit_air = true  # fire reaches up to the helicopters
	sim.hit_area(cone, damage)
	sim.hit_air = false


## Circles (x, y centre, z radius) that together cover the cone `of` gives, out to its reach,
## so presentation can flatten everything the breath burns (build 2 note 26: trees stood).
## `count` rows along the axis, each a line of circles across the cone's width there (a lattice
## of squares one row deep, each circle just wide enough to cover its square), so no circle
## bulges past the cone's flank or end by more than a fraction of a row. (One circle per row on
## the axis had to be as wide as the cone, and flattened a tree 0.19 of the reach outside it.)
static func cover(cone: Dictionary, count := 12) -> Array[Vector3]:
	var origin: Vector2 = cone["origin"]
	var dir: Vector2 = cone["dir"]
	var across := dir.orthogonal()
	var reach := Num.f(cone["reach"])
	var slope := tan(Num.f(cone["half_angle"]))
	var step := reach / count
	var radius := step * SQUARE_HALF_DIAGONAL
	var out: Array[Vector3] = []
	for i: int in count:
		var d := (i + 0.5) * step
		var half_width := (d + step * 0.5) * slope
		var lines := maxi(0, ceili(half_width / step - 0.5))
		for k: int in range(-lines, lines + 1):
			var at := origin + dir * d + across * (k * step)
			out.append(Vector3(at.x, at.y, radius))
	return out
