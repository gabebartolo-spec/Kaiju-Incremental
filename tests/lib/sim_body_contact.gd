extends RefCounted
## The sim suite's body-contact checks (playtest note 2, D-091), split out to keep the runner
## small: the young reptilian walks into a building, turns inside it and walks out, and after
## every step no standing chunk sits inside its body volume, for a building it outsizes (broken
## outright) and one that dwarfs it (chewed at a reduced rate while its wall holds the body). It
## topples a tier-2 tower by eating its base. Includes the player-effect fixture "kaiju.contact":
## the same seeded walk with the body volume off leaves chunks inside the body (it phases).

const DT := 1.0 / 30.0
## The scripted walk: forward into the building, a hard turn, then back out (steps).
const FORWARD_STEPS := 90
const TURN_STEPS := 30
const BACK_STEPS := 45
## The tower test: the baby chews across a tier-2 tower's base for at most this long (steps).
const TOPPLE_STEPS := 30 * 60
## Steps that cover one dash and its end.
const DASH_STEPS := 20

var _check: Callable
var _make: Callable


## check: the runner's check; make(species, levels, run_index, tuning) -> RampageSim.
func _init(p_check: Callable, make: Callable) -> void:
	_check = p_check
	_make = make


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
	_check_dash()


## Playtest note 4: a dash at the nearest building carries the body through it at speed, and
## the sweep still leaves nothing standing inside the body after any step.
func _check_dash() -> void:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	sim.body.use_species("reptilian")
	var dir := (sim.nearest_standing(sim.kaiju_pos) - sim.kaiju_pos).normalized()
	var from := sim.kaiju_pos
	var worst := 0
	for n: int in DASH_STEPS:
		sim.step(DT, dir, false, Dash.BUTTON if n == 1 else 0)
		var inside := sim.body.inside(sim.kaiju_pos, sim.body.heading)
		for index: int in inside:
			var cells: Dictionary = inside[index]
			worst = maxi(worst, cells.size())
	var moved := sim.kaiju_pos.distance_to(from)
	_check.call(
		sim.body.dash.dashes == 1 and moved > sim.body.length() and worst == 0,
		(
			(
				"a dash carries the body %.1f m (body %.1f m) and leaves no chunk inside it (%d);"
				+ " %d chunks broken"
			)
			% [moved, sim.body.length(), worst, sim.body.broken]
		)
	)


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
