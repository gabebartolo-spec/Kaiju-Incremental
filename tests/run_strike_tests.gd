extends "res://tests/lib/powers_base.gd"
## Damage lands on impact (D-166, D-175; Strikes): the reptilian's breath burns at the strike, 0.8 /
## 1.1 / 1.4 s after the press (young / Behemoth / Colossus), the cone read where he faces then; the
## Thunder Beam's stream starts 1.4 s after the press with the walk slow from the press; a standing
## stomp lands 0.45 s after its tick, a walking one on its tick; the dash is instant; cooldowns
## count from the press; nothing lands if the rampage ends or he evolves in the wind-up; the events
## carry the strike time; same seed, same strikes.
## Seeded by design: every sim is Seeds.make("army", 0) in a small hand-made layout.

## The levels that make each growth step: young, Behemoth, Colossus.
const TIERS: Array[Dictionary] = [{}, {"evolve1": 1}, {"evolve1": 1, "evolve2": 1}]
const DASH := 4  # Dash.BUTTON
const DASH_FLAG := 8  # _watch: press the dash on the first step


func suite_name() -> String:
	return "Strike"


func run_checks() -> void:
	await _t("_check_breath_delay")
	await _t("_check_breath_aim")
	await _t("_check_beam_delay")
	await _t("_check_cancelled")
	await _t("_check_standing_stomp")
	await _t("_check_dash")
	await _t("_check_replay")


## A reptilian of these levels at the origin facing `way`, a block of 3x3x4 chunks in its breath's
## cone: half the reach out from the snout, well past the stomp.
func _breath_sim(levels: Dictionary, way: Vector2 = NORTH) -> RampageSim:
	var probe := _sim("reptilian", levels, [], Vector2.ZERO)
	probe.facing = way
	var cone := BreathCone.of(probe)
	var origin: Vector2 = cone["origin"]
	var at := origin + way * Num.f(cone["reach"]) * 0.5
	var sim := _sim("reptilian", levels, [_b(at.x, at.y, Vector3i(3, 3, 4))], Vector2.ZERO)
	sim.facing = way
	return sim


## Steps `seconds` (PRESS / ULT pressed on the first step); every event with the seconds since the
## watch began, and per step the chunks broken, the walk-speed multiplier and the two cooldowns.
func _watch(sim: RampageSim, seconds: float, move: Vector2, buttons: int = 0) -> Dictionary:
	var out := {"events": [], "chunks": [], "speed": [], "ready": [], "ult": []}
	for i: int in roundi(seconds / DT):
		var flags := RampageSim.HELD if buttons & HOLD else 0
		if i == 0 and buttons & ULT:
			flags |= RampageSim.ULTIMATE
		if i == 0 and buttons & DASH_FLAG:
			flags |= DASH
		for event: Dictionary in sim.step(DT, move, i == 0 and buttons & PRESS != 0, flags):
			var events: Array = out["events"]
			events.append({"t": i * DT, "event": event})
		var chunks: Array = out["chunks"]
		chunks.append(sim.chunks_destroyed)
		var speed: Array = out["speed"]
		speed.append(sim.powers.speed_mult())
		var ready: Array = out["ready"]
		ready.append(sim.ability_ready_in)
		var ult: Array = out["ult"]
		ult.append(sim.ultimate_ready_in)
	return out


## Seconds from the watch's start to the first event of `type`; -1 if none came.
func _at(seen: Dictionary, type: String) -> float:
	var events: Array = seen["events"]
	for entry: Dictionary in events:
		var event: Dictionary = entry["event"]
		if str(event["type"]) == type:
			return Num.f(entry["t"])
	return -1.0


## The first event of `type` ({} if none came).
func _event(seen: Dictionary, type: String) -> Dictionary:
	var events: Array = seen["events"]
	for entry: Dictionary in events:
		var event: Dictionary = entry["event"]
		if str(event["type"]) == type:
			return event
	return {}


## What a per-step log said at the step `seconds` into the watch.
func _log(seen: Dictionary, key: String, seconds: float) -> float:
	var values: Array = seen[key]
	return Num.f(values[clampi(roundi(seconds / DT), 0, values.size() - 1)])


## Whether a strike due after `delay` seconds landed on its step: within two steps of it.
func _on_time(landed: float, delay: float) -> bool:
	return landed >= delay - 0.0001 and landed <= delay + 2.0 * DT


func _check_breath_delay() -> void:
	var delays: Array = Content.section("strike")["breath"]
	check(delays == [0.8, 1.1, 1.4], "the breath strikes 0.8 / 1.1 / 1.4 s after the press (D-175)")
	for tier: int in TIERS.size():
		var delay := Num.f(delays[tier])
		var sim := _breath_sim(TIERS[tier])
		var seen := _watch(sim, 2.5, Vector2.ZERO, PRESS)
		var windup := _event(seen, "strike_windup")
		check(
			(
				_at(seen, "strike_windup") == 0.0
				and str(windup.get("kind", "")) == "breath"
				and is_equal_approx(Num.f(windup.get("strike_in", -1.0)), delay)
			),
			(
				"growth step %d: the press announces the strike in %.1f s: %s"
				% [tier + 1, delay, windup]
			)
		)
		var struck := _at(seen, "ability")
		check(
			_on_time(struck, delay),
			(
				"growth step %d: the breath burns %.2f s after the press (data %.1f s)"
				% [tier + 1, struck, delay]
			)
		)
		var before := _log(seen, "chunks", struck - DT)
		var after := _log(seen, "chunks", struck)
		check(
			before == 0.0 and after > 0.0,
			(
				"growth step %d: nothing breaks until the strike, then the cone does (%d to %d chunks)"
				% [tier + 1, before, after]
			)
		)
		var cooldown := sim.stat("ability_cooldown")
		var left := _log(seen, "ready", struck)
		check(
			absf(left - (cooldown - struck)) < 0.01,
			(
				"growth step %d: the cooldown counts from the press (%.2f s left at the strike)"
				% [tier + 1, left]
			)
		)


## The cone is read at the strike, from where he faces then: turned east after the press, the
## breath burns the block to the east and leaves the one he faced at the press.
func _check_breath_aim() -> void:
	var probe := _sim("reptilian", {}, [], Vector2.ZERO)
	var snout: Vector2 = BreathCone.of(probe)["origin"]
	var out := snout.length() + probe.ability_reach() * 0.5
	var layout: Array[Dictionary] = [
		_b(0.0, -out, Vector3i(3, 3, 4)), _b(out, 0.0, Vector3i(3, 3, 4))
	]
	var sim := _sim("reptilian", {}, layout, Vector2.ZERO)
	sim.facing = NORTH
	var north := _alive(sim, 0)
	var east := _alive(sim, 1)
	_watch(sim, 0.1, Vector2.ZERO, PRESS)
	sim.facing = EAST
	_watch(sim, 2.0, Vector2.ZERO)
	check(
		_alive(sim, 1) < east and _alive(sim, 0) == north,
		(
			"turned east in the wind-up, the breath burns the east block (%d of %d), not north (%d of %d)"
			% [_alive(sim, 1), east, _alive(sim, 0), north]
		)
	)


func _check_beam_delay() -> void:
	var line: Array[Dictionary] = [_b(0, -6, Vector3i(3, 3, 4)), _b(0, -11, Vector3i(3, 3, 4))]
	var sim := _sim("reptilian", {"r_beam": 1}, line, Vector2.ZERO)
	var free := sim.powers.speed_mult()
	var seen := _watch(sim, 6.5, Vector2.ZERO, ULT)
	var delay := Num.f(Content.section("strike")["beam"])
	var windup := _event(seen, "strike_windup")
	check(
		(
			delay == 1.4
			and str(windup.get("kind", "")) == "beam"
			and is_equal_approx(Num.f(windup.get("strike_in", -1.0)), delay)
		),
		"the press announces the beam's strike in 1.4 s: %s" % [windup]
	)
	check(_at(seen, "ultimate") == 0.0, "the roar is on the press")
	var started := _at(seen, "beam_start")
	check(
		_on_time(started, delay),
		"the stream starts %.2f s after the press (data %.1f s)" % [started, delay]
	)
	check(
		_log(seen, "chunks", started - DT) == 0.0 and _at(seen, "coated") >= started,
		"nothing burns before the stream starts"
	)
	check(
		_log(seen, "chunks", started + 1.0) > 0.0,
		(
			"then it breaks what it crosses (%d chunks a second on)"
			% _log(seen, "chunks", started + 1.0)
		)
	)
	var slowed := _log(seen, "speed", 0.0)
	var mult := Num.f(sim.powers_cfg["beam_move_mult"])
	check(
		free > 0.0 and absf(slowed / free - mult) < 0.001,
		"the walk slow x%.1f starts at the press (x%.2f)" % [mult, slowed / maxf(free, 0.001)]
	)
	check(
		absf(_at(seen, "beam_end") - started - Num.f(sim.powers_cfg["beam_seconds"])) <= 2.0 * DT,
		(
			"the stream runs its 4 s from the strike (ends %.2f s on)"
			% (_at(seen, "beam_end") - started)
		)
	)
	var cooldown := Num.f(sim.powers_cfg["ultimate_cooldown"])
	check(
		absf(_log(seen, "ult", started) - (cooldown - started)) < 0.01,
		(
			"the cooldown counts from the press (%.2f s left at the strike)"
			% _log(seen, "ult", started)
		)
	)


## The rampage ends, or he evolves, in the wind-up: nothing lands, and a cancelled beam frees the
## legs again.
func _check_cancelled() -> void:
	var ended := _breath_sim({})
	_watch(ended, 0.1, Vector2.ZERO, PRESS)
	ended.end("ended")
	var late := _watch(ended, 2.0, Vector2.ZERO)
	check(
		_at(late, "ability") < 0.0 and ended.chunks_destroyed == 0,
		(
			"a breath pressed before the rampage ends lands nothing (%d chunks)"
			% ended.chunks_destroyed
		)
	)
	var grown := _breath_sim({})
	_watch(grown, 0.1, Vector2.ZERO, PRESS)
	grown.stats["size"] = float(grown.size_tier() + 1)
	var after := _watch(grown, 2.0, Vector2.ZERO)
	check(
		_at(after, "ability") < 0.0 and grown.chunks_destroyed == 0,
		"a breath pressed before he evolves lands nothing (%d chunks)" % grown.chunks_destroyed
	)
	var line: Array[Dictionary] = [_b(0, -6, Vector3i(3, 3, 4))]
	var beamed := _sim("reptilian", {"r_beam": 1}, line, Vector2.ZERO)
	var free := beamed.powers.speed_mult()
	_watch(beamed, 0.1, Vector2.ZERO, ULT)
	beamed.stats["size"] = float(beamed.size_tier() + 1)
	var rest := _watch(beamed, 3.0, Vector2.ZERO)
	check(
		_at(rest, "beam_start") < 0.0 and beamed.chunks_destroyed == 0,
		"a beam pressed before he evolves never starts"
	)
	check(
		absf(_log(rest, "speed", 3.0) / free - 1.0) < 0.001,
		"and the walk slow is gone with it (x%.2f)" % (_log(rest, "speed", 3.0) / free)
	)


## A stomp's tick while he stands lands 0.45 s on; walking, on the tick; the other species' stomps
## are untouched. The stomp event carries the time.
func _check_standing_stomp() -> void:
	var delay := Num.f(Content.section("strike")["stomp_standing"])
	check(delay == 0.45, "a standing stomp lands 0.45 s after its tick (D-175)")
	var near: Array[Dictionary] = [_b(0.0, -2.2, Vector3i(3, 3, 4))]
	var stood := _sim("reptilian", {}, near, Vector2.ZERO)
	var seen := _watch(stood, 1.0, Vector2.ZERO)
	var tick := _event(seen, "stomp")
	var landed := roundi(delay / DT) * DT
	check(
		_at(seen, "stomp") == 0.0 and is_equal_approx(Num.f(tick.get("strike_in", -1.0)), delay),
		"the stomp event is on the tick and carries the strike time: %s" % [tick]
	)
	check(
		_log(seen, "chunks", landed - DT) == 0.0 and _log(seen, "chunks", landed + DT) > 0.0,
		(
			"standing, the block is untouched until the foot lands (%d, then %d chunks)"
			% [_log(seen, "chunks", landed - DT), _log(seen, "chunks", landed + DT)]
		)
	)
	var walked := _sim("reptilian", {}, near, Vector2.ZERO)
	var steps := _watch(walked, 0.2, Vector2(-1, 0))
	var walking := _event(steps, "stomp")
	check(
		Num.f(walking.get("strike_in", -1.0)) == 0.0 and _log(steps, "chunks", DT) > 0.0,
		"walking, the stomp lands on its tick: %s" % [walking]
	)
	var mantis := _sim("insectoid", {}, near, Vector2.ZERO)
	var legs := _event(_watch(mantis, 0.2, Vector2.ZERO), "stomp")
	check(
		Num.f(legs.get("strike_in", -1.0)) == 0.0,
		"the other species' standing stomp is unchanged: %s" % [legs]
	)


## The dash is instant: he is already on his way on the press step.
func _check_dash() -> void:
	var sim := _sim("reptilian", {}, [], Vector2.ZERO)
	sim.body.use_species("reptilian")
	var from := sim.kaiju_pos
	var seen := _watch(sim, DT, NORTH, DASH_FLAG)
	check(
		_at(seen, "dash") == 0.0 and sim.kaiju_pos.distance_to(from) > 1.0,
		(
			"the dash starts on the press step and has covered %.1f units"
			% sim.kaiju_pos.distance_to(from)
		)
	)


func _check_replay() -> void:
	var first := _trace()
	check(
		first == _trace() and first.contains("ability") and first.contains("beam_start"),
		"the same seed strikes at the same steps: %s" % first
	)


## When the strike events came in a breath run and a beam run.
func _trace() -> String:
	var out := PackedStringArray()
	var breath := _watch(_breath_sim({"evolve1": 1}), 2.0, Vector2.ZERO, PRESS)
	var line: Array[Dictionary] = [_b(0, -6, Vector3i(3, 3, 4))]
	var beam := _watch(_sim("reptilian", {"r_beam": 1}, line, Vector2.ZERO), 3.0, Vector2.ZERO, ULT)
	for seen: Dictionary in [breath, beam]:
		var events: Array = seen["events"]
		for entry: Dictionary in events:
			var event: Dictionary = entry["event"]
			out.append("%s@%.3f" % [event["type"], entry["t"]])
	return ",".join(out)
