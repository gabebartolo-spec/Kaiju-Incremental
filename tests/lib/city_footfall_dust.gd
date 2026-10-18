extends RefCounted
## The city suite's footfall-dust check (greenery review, 2026-10-18): a burst of footfalls leaves
## only a few short, thin puffs in the air, so a walk cannot pile its dust into a haze that greys
## out the ground. The haze is the puffs in the air times each puff's opacity; the old collapse
## cloud per step (0.47 opacity, 2.6 s, no cap) gave 4.7 for this burst.

const STEPS := 10  # a burst of footfalls with no time between them
const HAZE := 0.9  # at most about one opaque layer of dust over the ground
const LIFE := 1.2  # seconds: a puff, not a cloud


static func check(check: Callable, root: Node) -> void:
	var cfg: Dictionary = Content.section("fx")["footfall_dust"]
	var fx := Fx.new()
	root.add_child(fx)
	fx.steps_live.clear()  # the prewarm puff is out of sight; count only the walk
	for i: int in STEPS:
		fx.footfall(Vector3(i * 2.0, 0.2, 0.0), 1.5)
	var live := fx.steps_live.size()
	var haze := live * Num.f(cfg["alpha"])
	var life := fx.steps_live[0].lifetime if live > 0 else INF
	check.call(
		haze <= HAZE and life <= LIFE,
		(
			"%d footfalls leave %d puffs in the air: haze %.2f (max %.1f), each %.1f s"
			% [STEPS, live, haze, HAZE, life]
		)
	)
	fx.free()
