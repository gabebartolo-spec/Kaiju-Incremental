class_name BlastShock
extends RefCounted
## A red-barrel blast's shockwave (BlastFx; director comments #20, "shockwaves and sonicboom";
## VFX lead 2026-10-23: the game's own dust, not lit cubes): the same Fx.shockwave band and Fx.dust
## puffs the stomps and landings use, out to the blast's reach. (The screen-bending ripple of the
## sonic boom is gone: it smeared the facades and put a grey blob over the kaiju.) Looks:
## data/tuning.json "blast_fx" shock; Fx's own "fx" shockwave for the band. Presentation only.


## How far the shock runs: the larger of shock.ring.footprint_scale times the site's widest
## side (halved: a radius) and the sim's own blast reach (full force to `radius`, gone at twice).
static func reach(span: float, radius: float, cfg: Dictionary) -> float:
	var ring: Dictionary = cfg["ring"]
	return maxf(span * Num.f(ring["footprint_scale"]) * 0.5, radius * 2.0)


## The ground shock: the game's own dust shockwave (Fx.shockwave, the dust band) out to `out`,
## and Fx.dust puffs round its rim (shock.ring.puffs of puff_size, the street's own dust), so it
## reads like every other thing that shakes the street.
static func ground(fx: Fx, at: Vector3, out: float, cfg: Dictionary) -> void:
	var ring: Dictionary = cfg["ring"]
	fx.shockwave(at, out)
	var puffs := Num.i(ring["puffs"])
	for k: int in puffs:
		var a := TAU * k / puffs
		fx.dust(
			at + Vector3(cos(a), 0.0, sin(a)) * out + Vector3(0, Num.f(ring["height"]), 0),
			Num.f(ring["puff_size"])
		)
