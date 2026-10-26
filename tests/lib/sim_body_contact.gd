extends RefCounted
## The sim suite's body-contact checks (playtest note 2, D-091), split out to keep the runner
## small: the young reptilian walks into a building, turns inside it and walks out, and after
## every step no standing chunk sits inside its body volume, for a building it outsizes (broken
## outright) and one that dwarfs it (chewed at a reduced rate while its wall holds the body). The
## tower checks (topple by chewing the base, swipes) are tests/lib/sim_body_chew.gd, run from here.
## Includes the player-effect fixture "kaiju.contact":
## the same seeded walk with the body volume off leaves chunks inside the body (it phases). The
## runner's scripted rampage carries the body and no wall holds it long; the sweep's last sample
## is the pose the hold reads; the "contact" tuning is valid.

const Fixture := preload("res://tests/lib/sim_body_fixture.gd")
const Chew := preload("res://tests/lib/sim_body_chew.gd")

const DT := 1.0 / 30.0
## The scripted walk: forward into the building, a hard turn, then back out (steps).
const FORWARD_STEPS := 90
const TURN_STEPS := 30
const BACK_STEPS := 45
## Steps that cover one leap and its end (the young croc's is about 2.1 s).
const DASH_STEPS := 90
## A scripted young rampage: no wall holds the body longer than this at a stretch (a quarter of
## its 40 s). A body stuck on a wall would hold for the rest of the run.
const HOLD_LIMIT_S := 10.0
## The walk-through (D-118): steps walked, the steps after contact in which chunks must already be
## gone, how many, and the longest a wall may hold the body (seconds).
const WALK_STEPS := 150
const EARLY_STEPS := 6
const EARLY_CHUNKS := 3
const SHOVE_LIMIT_S := 1.0
## The walls walked into: these tiers, every style (BuildingCells).
const WALK_TIERS: Array[int] = [2, 3]
const WALK_STYLES: Array[int] = [0, 1, 2, 3]

var _check: Callable
var _make: Callable
var _autoplay: Callable
var _make_seeded: Callable


## check: the runner's check; make(species, levels, run_index, tuning) -> RampageSim;
## autoplay(sim) -> result, the runner's scripted player; make_seeded(species, levels, tuning,
## Vector2i(city seed, run index)) -> RampageSim.
func _init(p_check: Callable, make: Callable, autoplay: Callable, make_seeded: Callable) -> void:
	_check = p_check
	_make = make
	_autoplay = autoplay
	_make_seeded = make_seeded


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
	_check_dash()
	_check_walk_through()
	Chew.new(_check, _make, _make_seeded).run()
	_check_autoplay()
	_check_sweep_end()
	_check_contact_data()


## The leap (the dash button, D-259) at the nearest building lands the body on it, and the sweep
## still leaves nothing standing inside the body after any step on the ground.
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
		sim.body.dash.landings == 1 and moved > sim.body.length() * 0.25 and worst == 0,
		(
			(
				"a leap lands the body %.1f m on (body %.1f m) and leaves no chunk inside it (%d);"
				+ " %d chunks broken"
			)
			% [moved, sim.body.length(), worst, sim.body.broken]
		)
	)


## D-118 (director 2026-10-21): "even big building should take visible damage, it should be easy
## for him to tear through them, it just requires slightly more effort". The baby walks straight
## into each building that dwarfs it, in every tier and style the city has: within EARLY_STEPS of
## the first touch at least EARLY_CHUNKS chunks are gone (visible damage, not a wall that soaks the
## walk up) and no wall holds the body longer than SHOVE_LIMIT_S (a short shove, then it gives).
## The same walks with the shove off (the D-091 chew alone) leave at least one wall with fewer
## chunks gone, so the shove is what changed it.
func _check_walk_through() -> void:
	var walls := 0
	var soaked := 0
	for tier: int in WALK_TIERS:
		for style: int in WALK_STYLES:
			var on := _walk_into(tier, style, true)
			if on.is_empty():
				continue
			var off := _walk_into(tier, style, false)
			walls += 1
			soaked += 1 if Num.i(off["early"]) < EARLY_CHUNKS else 0
			var said := "tier %d style %d (%s): %d chunks gone %.1f s after the first touch (>= %d),"
			said += " the wall held the body %.2f s (<= %.1f); the chew alone: %d chunks, %.2f s"
			_check.call(
				Num.i(on["early"]) >= EARLY_CHUNKS and Num.f(on["held"]) <= SHOVE_LIMIT_S + DT,
				(
					said
					% [
						tier,
						style,
						on["size"],
						Num.i(on["early"]),
						EARLY_STEPS * DT,
						EARLY_CHUNKS,
						Num.f(on["held"]),
						SHOVE_LIMIT_S,
						Num.i(off["early"]),
						Num.f(off["held"])
					]
				)
			)
	_check.call(
		walls >= 3 and soaked >= 1,
		(
			"%d walls walked into; the chew alone gave under %d chunks early in %d"
			% [walls, EARLY_CHUNKS, soaked]
		)
	)


## One walk straight into the nearest building of `tier` and `style` (at least 6 floors, 4 across),
## from 0.6 body lengths off its west face, for WALK_STEPS: {"early" (chunks broken EARLY_STEPS
## after the first touch), "held" (longest hold, s), "size" ("WxDxH")}; empty with no such
## building. `shove` off sets the D-118 shove aside (the chew alone).
func _walk_into(tier: int, style: int, shove: bool) -> Dictionary:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	if not shove:
		Fixture.chew_only(sim)
	sim.body.use_species("reptilian")
	var index := Fixture.nearest_of(sim, tier, Vector2i(6, 4), style)
	if index < 0:
		return {}
	var b := sim.buildings[index]
	var dir := Vector2(1, 0)
	Fixture.set_down(sim, Vector2(b.x - b.w * 0.5 - sim.body.length() * 0.6, b.z), dir)
	var contact := -1
	var early := 0
	for n: int in WALK_STEPS:
		sim.step(DT, dir, false)
		if contact < 0 and sim.body.held:
			contact = n
		if contact >= 0 and n == contact + EARLY_STEPS:
			early = sim.body.broken
	return {
		"early": early,
		"held": sim.body.longest_hold,
		"size": "%dx%dx%d" % [b.w, b.d, b.height],
	}


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
	var b := sim.buildings[Fixture.nearest_of(sim, tier, Vector2i.ZERO, -1)]
	var centre := Vector2(b.x, b.z)
	var dir := (centre - sim.kaiju_pos).normalized()
	Fixture.set_down(sim, centre - dir * (maxf(b.w, b.d) * 0.5 + probe.length() * 0.6), dir)
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
		worst = maxi(worst, Fixture.count(probe.inside(sim.kaiju_pos, sim.body.heading)))
	return {"worst": worst, "held": held, "broken": sim.body.broken, "chunks": sim.chunks_destroyed}


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
		var pose := BodyVolume.sweep_pose(Vector2(1.1, 2.9), from_heading, to, to_heading, 1.0)
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
