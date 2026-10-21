class_name ChainStep
extends RefCounted
## One fixed Verlet step of a KaijuRig spring chain (R 9.1, research 2026-10-21/09-tentacles).
## KaijuRig.simulate_chains calls it at tuning "chain" "step_hz" however fast frames arrive, so a
## tail or tentacle swings the same at 30, 60 or 144 fps and a capture repeats. Presentation only.


## Pulls the joints toward `target` (where the driven rest pose would put them) with inertia and
## gravity, keeps them above the ground, then holds every bone to its length, reaching for the
## pinned joint from the tip back (FABRIK) when a tentacle grips.
static func run(chain: KaijuRig.SpringChain, target: PackedVector3Array, h: float) -> void:
	var cfg := Content.section("chain")
	var damping := Num.f(cfg["damping"])
	var pos := chain.pos
	var prev := chain.prev
	var k := chain.stiffness
	var g := Vector3(0, Num.f(cfg["gravity_y"]), 0) * chain.gravity_scale
	for i: int in range(1, pos.size()):
		var p := pos[i]
		var vel := (p - prev[i]) * damping
		prev[i] = p
		pos[i] = p + vel + ((target[i] - p) * k + g) * h * h
	for i: int in range(1, pos.size()):
		pos[i].y = maxf(pos[i].y, chain.ground)
	var pinned := -1
	for i: int in chain.pins:
		pinned = maxi(pinned, i)
	for _pass: int in Num.i(cfg["passes"]):
		if pinned > 0:
			var pin: Vector3 = chain.pins[pinned]
			pos[pinned] = pin
			for i: int in range(pinned - 1, 0, -1):
				var back := (target[i + 1] - target[i]).length()
				var e := pos[i] - pos[i + 1]
				if e.length() > 0.0001:
					pos[i] = pos[i + 1] + e.normalized() * back
		for i: int in range(1, pos.size()):
			var length := (target[i] - target[i - 1]).length()
			var d := pos[i] - pos[i - 1]
			if d.length() > 0.0001:
				pos[i] = pos[i - 1] + d.normalized() * length
	chain.pos = pos
	chain.prev = prev
