extends RefCounted
## The sim suite's body-contact checks (playtest note 2, D-091), split out to keep the runner
## small: the young reptilian walks into a building, turns inside it and walks out, and after
## every step no standing chunk sits inside its body volume, for a building it outsizes (broken
## outright) and one that dwarfs it (chewed at a reduced rate while its wall holds the body). It
## topples a tier-2 tower by eating its base. Includes the player-effect fixture "kaiju.contact":
## the same seeded walk with the body volume off leaves chunks inside the body (it phases). The
## runner's scripted rampage carries the body and no wall holds it long; the sweep's last sample
## is the pose the hold reads; the "contact" tuning is valid.

const DT := 1.0 / 30.0
## The scripted walk: forward into the building, a hard turn, then back out (steps).
const FORWARD_STEPS := 90
const TURN_STEPS := 30
const BACK_STEPS := 45
## The tower test: the baby chews across a tier-2 tower's base for at most this long (steps).
const TOPPLE_STEPS := 30 * 60
## A scripted young rampage: no wall holds the body longer than this at a stretch (a quarter of
## its 40 s). A body stuck on a wall would hold for the rest of the run.
const HOLD_LIMIT_S := 10.0

var _check: Callable
var _make: Callable
var _autoplay: Callable


## check: the runner's check; make(species, levels, run_index, tuning) -> RampageSim;
## autoplay(sim) -> result, the runner's scripted player.
func _init(p_check: Callable, make: Callable, autoplay: Callable) -> void:
	_check = p_check
	_make = make
	_autoplay = autoplay


func run() -> void:
	var on := _walk(true, 1)
	var off := _walk(false, 1)
	_check.call(
		Num.i(off["worst"]) > 0,
		(
			"without the body volume the walk into a low building leaves %d chunks inside the body"
			% Num.i(off["worst"])
		)
	)
	_check.call(
		Num.i(on["worst"]) == 0 and Num.i(on["broken"]) > 0,
		(
			"with it, a low building breaks: none inside the body (%d), %d broken, held %d steps"
			% [Num.i(on["worst"]), Num.i(on["broken"]), Num.i(on["held"])]
		)
	)
	var big := _walk(true, 2)
	(
		_check
		. call(
			Num.i(big["worst"]) == 0 and Num.i(big["held"]) > 0 and Num.i(big["broken"]) > 0,
			(
				(
					"a tower that dwarfs it holds the body at its wall while it chews in: none inside (%d),"
					+ " held %d steps, %d broken"
				)
				% [Num.i(big["worst"]), Num.i(big["held"]), Num.i(big["broken"])]
			)
		)
	)
	_check.call(on == _walk(true, 1), "the walk through a building replays identically")
	_check_topple()
	_check_autoplay()
	_check_sweep_end()
	_check_contact_data()


## The nearest standing building of exactly this tier (no landmark) to the kaiju; `min_height`
## and `min_side` narrow it.
func _nearest(sim: RampageSim, tier: int, min_height: int = 0, min_side: int = 0) -> int:
	var best := -1
	var best_d := INF
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.tier != tier or b.landmark != "" or b.height < min_height or mini(b.w, b.d) < min_side:
			continue
		var d := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		if d < best_d:
			best = i
			best_d = d
	return best


## One seeded walk into the nearest building of `tier`, from just outside it; with `body` off
## the volume is only measured (a probe), never applied.
func _walk(body: bool, tier: int) -> Dictionary:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	var probe := sim.body
	if body:
		sim.body.use_species("reptilian")
	else:
		sim.body.use_species("")  # no volume: the walk only measures it with the probe
		probe = BodyContact.new(sim, Content.tuning())
		probe.use_species("reptilian")
	var b := sim.buildings[_nearest(sim, tier)]
	var centre := Vector2(b.x, b.z)
	var dir := (centre - sim.kaiju_pos).normalized()
	_place(sim, centre - dir * (maxf(b.w, b.d) * 0.5 + probe.length() * 0.6), dir)
	var worst := 0
	var held := 0
	for n: int in FORWARD_STEPS + TURN_STEPS + BACK_STEPS:
		var move := dir
		if n >= FORWARD_STEPS + TURN_STEPS:
			move = -dir
		elif n >= FORWARD_STEPS:
			move = dir.orthogonal()
		sim.step(DT, move, false)
		held += 1 if sim.body.held else 0
		worst = maxi(worst, _count(probe.inside(sim.kaiju_pos, sim.body.heading)))
	return {"worst": worst, "held": held, "broken": sim.body.broken, "chunks": sim.chunks_destroyed}


func _place(sim: RampageSim, at: Vector2, facing: Vector2) -> void:
	sim.kaiju_pos = at
	sim.facing = facing
	sim.body.heading = facing


func _count(inside: Dictionary) -> int:
	var count := 0
	for index: int in inside:
		var cells: Dictionary = inside[index]
		count += cells.size()
	return count


## D-091: "more than capable of tearing the roots out and toppling the large buildings". The baby
## chews straight into the base of the nearest tall tier-2 tower until it comes down.
func _check_topple() -> void:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	sim.body.use_species("reptilian")
	var index := _nearest(sim, 2, 10, 4)
	var b := sim.buildings[index]
	var start := b.frame.alive_count
	var into := Vector2(0, -1)  # from the tower's south face, across its base
	_place(sim, Vector2(b.x, b.z + b.d * 0.5 + sim.body.length() * 0.6), into)
	var steps := 0
	var worst := 0
	var fell := false
	while steps < TOPPLE_STEPS and not fell:
		sim.step(DT, into, false)
		worst = maxi(worst, _count(sim.body.inside(sim.kaiju_pos, sim.body.heading)))
		for f: RampageSim.Fall in sim.falls:
			fell = fell or (f.building == index and f.kind == "topple")
		steps += 1
	_check.call(
		fell and worst == 0,
		(
			(
				"the baby topples a %d-floor tier-2 tower by eating its base: %s after %.1f s"
				+ " (%d of %d chunks standing, none inside the body: %d)"
			)
			% [b.height, fell, steps * DT, b.frame.alive_count, start, worst]
		)
	)


## The runner's scripted rampage (determinism, upgrade effects, rooftops) runs with the body.
func _check_autoplay() -> void:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	var active := sim.body.active()
	var result: Dictionary = _autoplay.call(sim)
	_check.call(
		active and sim.body.broken > 0 and sim.body.longest_hold <= HOLD_LIMIT_S,
		(
			(
				"the scripted young rampage carries the body (%s), which breaks %d chunks; no wall"
				+ " holds it over %.0f s at a stretch (longest %.2f s, ended by %s)"
			)
			% [active, sim.body.broken, HOLD_LIMIT_S, sim.body.longest_hold, result["reason"]]
		)
	)


## The sweep's last sample is exactly the end pose the hold test reads, whatever the turn.
func _check_sweep_end() -> void:
	var off := 0
	var to := Vector2(3.7, -11.3)
	for deg: int in 360:
		var from_heading := Vector2.from_angle(deg * 0.37)
		var to_heading := Vector2.from_angle(deg_to_rad(deg))
		var pose := BodyContact.sweep_pose(Vector2(1.1, 2.9), from_heading, to, to_heading, 1.0)
		off += 0 if pose[0] == to and pose[1] == to_heading else 1
	_check.call(
		off == 0, "the sweep ends on the hold's pose for every turn, off for %d of 360" % off
	)


## The "contact" tuning: every rate positive, the pay share a fraction. A zero bite_dps would
## leave a tower that dwarfs the body holding it forever (the D-091 "too strong" wall).
func _check_contact_data() -> void:
	var cfg: Dictionary = Content.tuning()["contact"]
	var bad := cfg.duplicate()
	bad["bite_dps"] = 0.0
	_check.call(
		contact_errors(cfg).is_empty() and "bite_dps" in str(contact_errors(bad)),
		"the contact tuning is valid (%s) and a zero bite_dps is caught" % [contact_errors(cfg)]
	)


static func contact_errors(cfg: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in ["bite_dps", "sample", "turn_rate"]:
		if Num.f(cfg.get(key, 0.0)) <= 0.0:
			out.append("%s must be > 0, is %s" % [key, cfg.get(key, 0.0)])
	var pay := Num.f(cfg.get("pay_mult", -1.0))
	if pay <= 0.0 or pay > 1.0:
		out.append("pay_mult must be in (0, 1], is %s" % pay)
	return out
