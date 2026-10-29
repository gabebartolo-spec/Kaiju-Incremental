extends "res://tests/lib/vip_base.gd"
## Leader's escape helicopter suite (VipHeli, D-149): it lifts off once a rampage inside its
## window, flies one lap then runs for the edge in about 15 s, every kill method brings it down
## (breath, Thunder Beam, a toppling tower), an escape pays nothing, and the payout is about a
## city block. Player-effect fixture "vip.payout": the same rampage with the leader shot down is
## richer by exactly the payout than with it left to escape. Headless.
##   godot --headless --path . --script tests/run_vip_tests.gd


func suite_name() -> String:
	return "Vip"


func run_checks() -> void:
	await _t("_check_window")
	await _t("_check_flight")
	await _t("_check_ranks")
	await _t("_check_breath")
	await _t("_check_beam")
	await _t("_check_topple")
	await _t("_check_burning")
	await _t("_check_escape")
	await _t("_check_payout_matters")
	await _t("_check_block_payout")
	await _t("_check_view")
	await _t("_check_wreck_paint")
	await _t("_check_headlines")


func _check_window() -> void:
	var vip: Dictionary = Content.section("vip")
	var window: Array = vip["window"]
	var run := _sim_seeded(0).stat("run_seconds")
	var times: Array[float] = []
	var once := true
	for n: int in 5:
		var sim := _sim_seeded(n)
		var spawns := 0
		var at := -1.0
		for i: int in roundi(run * 0.8 / DT):
			for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
				if str(event["type"]) == "vip_spawned":
					spawns += 1
					at = sim.elapsed
		once = once and spawns == 1
		times.append(at)
	var inside := true
	for at: float in times:
		inside = inside and at >= Num.f(window[0]) * run and at <= Num.f(window[1]) * run + 0.5
	check(once, "the leader lifts off exactly once a rampage (seeds 0-4)")
	check(inside, "...inside its window of the run: %s s" % [times])
	var lo: float = times.min()
	var hi: float = times.max()
	check(
		not is_equal_approx(lo, hi) and times == _spawn_times(),
		"...at a seeded moment: differs by seed, same on a replay"
	)


## One lap round the pad, then the dash: about 15 s from lift-off to the edge, turning smoothly
## (never a snap), rising from the roof, and never pinned to the kaiju.
func _check_flight() -> void:
	var vip: Dictionary = Content.section("vip")
	var sim := _flying()
	var pad := sim.vip.pos
	check(
		pad.distance_to(Vector2(10.0, 0.0)) < 1.0 and sim.vip.altitude() < 6.0,
		"it lifts off the pad's roof (%s at %.1f)" % [sim.vip.pos, sim.vip.altitude()]
	)
	var last := sim.vip.heading
	var snap := 0.0
	var farthest := 0.0
	var lap_done := 0.0
	var t := 0.0
	var reached := 0.0
	while sim.vip.flying() and t < 40.0:
		sim.step(DT, Vector2.ZERO, false)
		t += DT
		snap = maxf(snap, absf(angle_difference(last, sim.vip.heading)) / DT)
		last = sim.vip.heading
		farthest = maxf(farthest, sim.vip.pos.distance_to(pad))
		if lap_done == 0.0 and sim.vip._turned >= TAU:
			lap_done = t
		reached = maxf(reached, sim.vip.altitude())
	check(
		absf(t - Num.f(vip["window_seconds"])) <= 3.0,
		"it is gone about %.0f s after lift-off (%.1f s)" % [Num.f(vip["window_seconds"]), t]
	)
	check(sim.vip.state == "escaped", "left alone it reaches the edge (%s)" % sim.vip.state)
	check(
		lap_done > 0.0 and lap_done < t - 2.0,
		"one lap first (done at %.1f s), then a dash of its own" % lap_done
	)
	check(
		snap <= Num.f(vip["turn_limit"]) + TAU / Num.f(vip["circle_seconds"]) * 1.5,
		"it banks round, never snaps (fastest turn %.2f rad/s)" % snap
	)
	check(farthest > sim.arena_half * 0.4, "it runs for the map edge (%.0f out)" % farthest)
	check(
		absf(reached - Num.f(vip["altitude"])) < 0.5,
		"it climbs to its cruise height (%.1f)" % reached
	)


func _check_ranks() -> void:
	var vip: Dictionary = Content.section("vip")
	var ranks: Array = vip["ranks"]
	var payouts: Array = vip["payout"]
	var seen: Array[String] = []
	for tier: int in 3:
		var stats := _stats("reptilian", {})
		stats["size"] = tier + 1
		var sim := RampageSim.new(stats, Content.tuning(), _layout(), Seeds.make("army", 0))
		seen.append(sim.vip.rank)
		check(
			is_equal_approx(sim.vip.payout, Num.f(payouts[tier])),
			"tier %d pays %.1f" % [tier + 1, Num.f(payouts[tier])]
		)
	check(
		seen == ["MAYOR", "GOVERNOR", "PRESIDENT"] and ranks.size() == payouts.size(),
		"Mayor in the baby city, Governor in the adolescent, President in the adult: %s" % [seen]
	)


## The breath, aimed at it, brings it down and pays; a breath at empty sky does not.
func _check_breath() -> void:
	var sim := _flying()
	sim.vip.pos = sim.kaiju_pos + Vector2(5.0, 0.0)
	var rubble := sim.rubble
	var seen := _held_run(sim, sim.strikes.breath_delay() + 0.2, Vector2(5.0, 0.0), PRESS)
	check(
		sim.vip.state == "killed" and Num.i(seen.get("vip_killed", 0)) == 1,
		"the breath brings the leader down at the strike (%s)" % sim.vip.state
	)
	check(sim.rubble > rubble + sim.vip.payout * 0.99, "...and pays the payout")
	var miss := _flying()
	miss.vip.pos = Vector2(-30.0, 30.0)
	_held_run(miss, miss.strikes.breath_delay() + 0.2, Vector2(-30.0, 30.0) - miss.kaiju_pos, PRESS)
	check(miss.vip.flying(), "a breath that misses leaves it flying")


func _check_beam() -> void:
	var sim := _flying("reptilian", {"r_beam": 1})
	sim.vip.pos = sim.kaiju_pos + Vector2(8.0, 0.0)
	var seen := _held_run(sim, _strike_wait() + 0.6, Vector2(8.0, 0.0), ULT)
	check(
		sim.vip.state == "killed" and seen.has("vip_killed"),
		"the Thunder Beam brings the leader down (%s)" % sim.vip.state
	)


## A tower toppling across its path brings it down while it is still low (D-149, at lift-off);
## the same fall stops short of it once it has climbed above the tower's reach.
func _check_topple() -> void:
	var outcomes: Array[String] = []
	for wait: float in [0.0, 20.0]:
		var sim := _flying()
		_run(sim, wait, Vector2.ZERO)
		if not sim.vip.flying():
			outcomes.append("gone")
			continue
		var start := sim.vip.pos - Vector2(3.0, 0.0)
		(
			sim
			. events
			. append(
				{
					"type": "fall_start",
					"kind": "topple",
					"pivot": Vector3(start.x, 3.0, start.y),
					"to": start + Vector2(6.0, 0.0),
					"width": 2.0,
				}
			)
		)
		sim.vip.step(0.0)
		outcomes.append(sim.vip.state)
	check(
		outcomes == ["killed", "gone"],
		"a toppling tower brings it down at lift-off (and not once it is away): %s" % [outcomes]
	)


func _check_burning() -> void:
	var sim := _flying()
	sim.vip.pos = sim.kaiju_pos + Vector2(5.0, 0.0)
	sim.vip._coat_t = 5.0
	sim.vip._coat_dps = 100.0
	_run(sim, 0.5, Vector2.ZERO)
	check(sim.vip.state == "killed", "a burning coat finishes it")


## Left alone it escapes: the mocking headline's event, no payout, nothing else lost.
func _check_escape() -> void:
	var sim := _flying()
	var rubble := sim.rubble
	var seen: Dictionary = {}
	while sim.vip.flying():
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			seen[str(event["type"])] = true
	check(
		seen.has("vip_escaped") and not seen.has("vip_killed") and sim.vip.paid == 0.0,
		"an escape is announced and pays nothing: %s" % [seen.keys()]
	)
	check(
		is_equal_approx(sim.rubble, rubble), "...and loses only the payout (rubble %.2f)" % rubble
	)
	var summary := sim.vip.summary()
	check(
		Num.i(summary["vip_escaped"]) == 1 and Num.i(summary["vip_killed"]) == 0,
		"the result screen's news reads it: %s" % [summary]
	)


## Player-effect fixture "vip.payout": the same seeded rampage, the leader shot down vs left to
## escape. The kill is richer by exactly the payout (x the kaiju's rubble multiplier).
func _check_payout_matters() -> void:
	var results: Array[RampageSim] = []
	for shoot: bool in [true, false]:
		var sim := _flying()
		if shoot:
			sim.vip.pos = sim.kaiju_pos + Vector2(5.0, 0.0)
			sim.step(DT, Vector2.ZERO, true)
		else:
			sim.step(DT, Vector2.ZERO, true)  # the same breath, at an empty sky
		_run(sim, 30.0, Vector2.ZERO)
		results.append(sim)
	var gap := results[0].rubble - results[1].rubble
	var paid := results[0].vip.payout * results[0].stat("rubble_mult")
	check(
		results[0].vip.state == "killed" and results[1].vip.state == "escaped",
		(
			"fixture vip.payout: shot down vs escaped (%s / %s)"
			% [results[0].vip.state, results[1].vip.state]
		)
	)
	check(
		is_equal_approx(gap, paid) and paid > 0.0,
		"...the kill is richer by the payout (%.2f vs %.2f)" % [gap, paid]
	)


func _check_block_payout() -> void:
	VipBlock.run(check)


func _check_view() -> void:
	await VipViewCheck.run(self, check, _stats("reptilian", {}))


## A wreck's chunks wear the paint of the helicopter they came from: the leader's white and gold,
## a gunship's olive.
func _check_wreck_paint() -> void:
	await HeliWreckPaintCheck.run(self, check, _stats("reptilian", {}))


## The director's headlines (D-149) fit the held strip for every rank in the 1920 px design
## canvas that 1080p and 4K both draw (4K is the same canvas at 2x): the widest line leaves the
## tag's width and the title-safe margins either side.
func _check_headlines() -> void:
	var vip: Dictionary = Content.section("vip")
	var lines: Dictionary = vip["headlines"]
	var ranks: Array = vip["ranks"]
	var room := 1920.0 - NewsTicker.TAG_WIDTH - UiKit.safe_margin().x * 2.0
	var widest := 0.0
	for key: String in lines:
		for rank: Variant in ranks:
			var text := str(lines[key]).replace("{rank}", str(rank))
			var label := UiKit.label(text, UiKit.SIZE_BODY)
			var font := label.get_theme_font("font")
			var width := (
				font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_BODY).x
			)
			widest = maxf(widest, width)
			label.free()
	check(
		(
			str(lines["liftoff"]) == "COWARD {rank} FLEES CITY BY CHOPPER"
			and str(lines["killed"]) == "{rank} SWATTED FROM THE SKY"
			and str(lines["escaped"]) == "COWARD {rank} ESCAPES THE CITY"
		),
		"the headlines are the director's: %s / %s" % [lines["liftoff"], lines["killed"]]
	)
	print("WIDEST headline %.0f px of %.0f px room" % [widest, room])
	check(
		widest > 0.0 and widest <= room,
		"the widest line is %.0f px of %.0f px room" % [widest, room]
	)
