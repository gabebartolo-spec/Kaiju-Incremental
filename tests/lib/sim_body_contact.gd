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
## Steps that cover one dash and its end.
const DASH_STEPS := 20
## A scripted young rampage: no wall holds the body longer than this at a stretch (a quarter of
## its 40 s). A body stuck on a wall would hold for the rest of the run.
const HOLD_LIMIT_S := 10.0

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
	Chew.new(_check, _make, _make_seeded).run()
	_check_autoplay()
	_check_sweep_end()
	_check_contact_data()


## Playtest note 4: a dash at the nearest building carries the body through it at speed, and
## the sweep still leaves nothing standing inside the body after any step.
func _check_dash() -> void:
	var sim: RampageSim = _make.call("reptilian", {}, 0, {})
	sim.body.use_species("reptilian")
	var dir := (sim.nearest_standing(sim.kaiju_pos) - sim.kaiju_pos).normalized()
	var from := sim.kaiju_pos
	var worst := 0
	for n: int in DASH_STEPS:
		sim.step(DT, dir, false, (Dash.BUTTON if n == 1 else 0) | RampageSim.STOMP)
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
		sim.step(DT, move, false, RampageSim.STOMP)
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
