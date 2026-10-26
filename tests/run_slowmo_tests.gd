extends "res://tests/lib/runner.gd"
## Slow motion only when a landmark falls (D-259) and shot impacts on the hide (D-245), presentation
## only: the end beat runs at normal speed; a landmark_felled event slows the world to the tuned
## speed for the tuned time and eases it back, never stacks, never starts in the end beat and
## ignores the VIP's kill and every other event; the sim is always stepped by whole ticks, so a
## slowed rampage is the same rampage (a seeded run on and off ends in the same state); and rooftop
## rounds land on the hide like a tank's (tests/lib/slowmo_play.gd).
## Seeded by design: the small sims are built on pinned seeds and their state set by hand; the whole
## rampage is autoplayed on pinned seeds.
##   godot --headless --path . --script tests/run_slowmo_tests.gd

const SlowmoPlay := preload("res://tests/lib/slowmo_play.gd")
const ThreatPlay := preload("res://tests/lib/threat_play.gd")
const DT := 1.0 / 60.0
## A landmark and a plain block: enough city for the sim's reports.
const LAYOUT: Array[Dictionary] = [
	{"x": 0.0, "z": 0.0, "w": 4, "d": 4, "h": 4, "tier": 1, "style": 0, "landmark": "spire"},
	{"x": -8.0, "z": 0.0, "w": 3, "d": 3, "h": 3, "tier": 1, "style": 1},
]


func suite_name() -> String:
	return "Slowmo"


func run_checks() -> void:
	await _t("_check_speed_curve")
	await _t("_check_end_beat_whole_speed")
	await _t("_check_fall_slows_and_restores")
	await _t("_check_second_fall_restarts")
	await _t("_check_only_a_landmark_slows")
	await _t("_check_never_in_the_end_beat")
	await _t("_check_sim_takes_whole_ticks")
	await _h("Slowmo play", func() -> void: await SlowmoPlay.new(self, check).run())
	Engine.time_scale = 1.0


func _sim() -> RampageSim:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	return RampageSim.new(stats, Content.tuning(), LAYOUT, Seeds.make("army", 0))


func _hud(sim: RampageSim) -> RampageHud:
	PlayerSettings.controls_seen = true
	var hud := RampageHud.new(sim, Content.species_def("reptilian"), null)
	root.add_child(hud)
	return hud


## A slow-motion node on `sim`, in the tree (it reads the sim's events on physics ticks).
func _node(sim: RampageSim, hud: RampageHud) -> LandmarkSlowmo:
	var node := LandmarkSlowmo.new(sim, hud)
	root.add_child(node)
	return node


## The landmark loses the felled share of its chunks; the sim's news reports it on its next look,
## and that report is what the sim hands out as `events` (the step that would carry it).
func _fell_landmark(sim: RampageSim) -> Array[Dictionary]:
	var share := Num.f(Content.section("results")["landmark_felled_share"])
	var mark := sim.buildings[0]
	var cells := ThreatPlay.cells(mark)
	for c: Vector3i in cells.slice(0, ceili(share * cells.size())):
		mark.frame.remove(c)
	var events: Array[Dictionary] = []
	sim.news.step(events)
	sim.set("_events", events)
	return events


func _frames(n: int) -> void:
	for _i: int in n:
		await physics_frame


## Tuned: a split second at a fraction of speed, then eased back; the curve follows the tuning.
func _check_speed_curve() -> void:
	var cfg: Dictionary = Content.section("slowmo")
	var low := Num.f(cfg["scale"])
	var hold := Num.f(cfg["hold_s"])
	var ease_s := Num.f(cfg["ease_s"])
	check(low > 0.0 and low < 1.0, "the slow motion is slower than normal, not stopped (%s)" % low)
	check(hold + ease_s <= 1.0, "and it is a split second (%s s)" % (hold + ease_s))
	check(LandmarkSlowmo.speed_at(-1.0, cfg) == 1.0, "no fall: full speed")
	check(LandmarkSlowmo.speed_at(0.0, cfg) == low, "a fall slows the world at once")
	check(LandmarkSlowmo.speed_at(hold - 0.001, cfg) == low, "and holds it for the tuned time")
	var mid := LandmarkSlowmo.speed_at(hold + ease_s * 0.5, cfg)
	check(mid > low and mid < 1.0, "then eases back up (%.3f halfway)" % mid)
	check(LandmarkSlowmo.speed_at(hold + ease_s, cfg) == 1.0, "and is whole again after ease_s")
	var last := low
	var rising := true
	for k: int in 26:
		var speed := LandmarkSlowmo.speed_at(hold + ease_s * k / 25.0, cfg)
		rising = rising and speed >= last
		last = speed
	check(rising, "the ease never slows again on the way up")


## The end beat is at normal speed from the first frame to the last (D-259 ended its slow motion).
func _check_end_beat_whole_speed() -> void:
	var hud := _hud(_sim())
	await _frames(3)
	check(Engine.time_scale == 1.0, "the world runs at normal speed before the beat")
	hud.show_end_beat("time")
	check(Engine.time_scale == 1.0, "the end beat does not slow the world (%s)" % Engine.time_scale)
	await _frames(10)
	check(hud.beat_running() and Engine.time_scale == 1.0, "and nor does it later")
	hud.finish_beat()
	check(Engine.time_scale == 1.0, "after the beat the world is at normal speed")
	hud.queue_free()
	await _frames(2)


## A landmark_felled event from the sim drops the time scale to the tuned value; it is back to
## 1.0 once hold_s + ease_s of real time have gone (60 physics ticks a second at any time scale).
func _check_fall_slows_and_restores() -> void:
	var cfg: Dictionary = Content.section("slowmo")
	var sim := _sim()
	var hud := _hud(sim)
	var node := _node(sim, hud)
	await _frames(2)
	var told := _fell_landmark(sim)
	check(
		told == [{"type": "landmark_felled", "landmark": "spire"}],
		"the sim reports the spire felled: %s" % [told]
	)
	await _frames(2)
	check(
		is_equal_approx(Engine.time_scale, Num.f(cfg["scale"])),
		"the fall drops the time scale to the tuned %s (%s)" % [cfg["scale"], Engine.time_scale]
	)
	var total := Num.f(cfg["hold_s"]) + Num.f(cfg["ease_s"])
	var ticks := 2
	while Engine.time_scale < 1.0 and ticks < 200:
		await physics_frame
		ticks += 1
	check(
		Engine.time_scale == 1.0 and absf(ticks * DT - total) < 4.0 * DT,
		"and restores 1.0 once the tuned %.2f s are up (%d ticks, %.2f s)" % [total, ticks, ticks * DT]
	)
	check(not node.active(), "the node is idle again")
	node.queue_free()
	hud.queue_free()
	await _frames(2)


## A second fall while one plays restarts the clock; the speed is never the product of two.
func _check_second_fall_restarts() -> void:
	var cfg: Dictionary = Content.section("slowmo")
	var low := Num.f(cfg["scale"])
	var hold := Num.f(cfg["hold_s"])
	var sim := _sim()
	var node := LandmarkSlowmo.new(sim, null)
	node.trigger()
	check(Engine.time_scale == low, "the first fall slows to %s" % low)
	node.advance(Num.f(cfg["hold_s"]) * 0.8)
	node.trigger()
	check(
		Engine.time_scale == low,
		"a second fall does not stack: still %s (%s)" % [low, Engine.time_scale]
	)
	node.advance(Num.f(cfg["hold_s"]) * 0.8)
	check(
		Engine.time_scale == low,
		"and it restarted the clock: %.2f s after the first fall it still holds" % (hold * 1.6)
	)
	node.advance(Num.f(cfg["hold_s"]) * 0.4 + Num.f(cfg["ease_s"]) * 0.5)
	check(Engine.time_scale > low and Engine.time_scale < 1.0, "then it eases back once")
	node.advance(Num.f(cfg["ease_s"]))
	check(Engine.time_scale == 1.0 and not node.active(), "and ends at 1.0")
	node.free()


## Only a landmark's fall slows the world: the threat rising, towers toppling, the VIP's kill and
## its escape do not (D-243: the VIP kill stays without).
func _check_only_a_landmark_slows() -> void:
	var sim := _sim()
	var node := _node(sim, null)
	await _frames(2)
	var others: Array[Dictionary] = [
		{"type": "threat_up", "level": 2},
		{"type": "towers_toppled", "count": 10},
		{"type": "vip_spawned", "heli": 1, "rank": 1, "x": 0.0, "z": 0.0},
		{"type": "vip_down", "heli": 1, "x": 0.0, "z": 0.0, "y": 5.0},
		{"type": "vip_killed", "rank": 1, "payout": 100.0, "by": "stomp"},
		{"type": "vip_escaped", "heli": 1, "rank": 1, "payout": 10.0},
	]
	sim.set("_events", others)
	await _frames(4)
	check(
		Engine.time_scale == 1.0 and not node.active(),
		"the threat, towers and the VIP's kill leave time alone (%s)" % Engine.time_scale
	)
	var landmark: Array[Dictionary] = [{"type": "landmark_felled", "landmark": "spire"}]
	sim.set("_events", landmark)
	await _frames(2)
	check(node.active() and Engine.time_scale < 1.0, "a landmark's fall does slow it")
	node.stop()
	check(Engine.time_scale == 1.0, "stop gives the speed back")
	node.queue_free()
	await _frames(2)


## Not during the end beat: a fall that comes with it starts nothing, and one already playing is
## cut short as the beat begins; his death playing and a finished rampage never slow either.
func _check_never_in_the_end_beat() -> void:
	var sim := _sim()
	var hud := _hud(sim)
	var node := _node(sim, hud)
	await _frames(2)
	hud.show_end_beat("time")
	node.trigger()
	check(not node.active() and Engine.time_scale == 1.0, "a fall in the end beat starts nothing")
	hud.finish_beat()
	hud.queue_free()
	var sim2 := _sim()
	var hud2 := _hud(sim2)
	var node2 := _node(sim2, hud2)
	await _frames(2)
	node2.trigger()
	check(Engine.time_scale < 1.0, "a fall before the beat slows the world")
	hud2.show_end_beat("time")
	await _frames(3)
	check(
		Engine.time_scale == 1.0 and not node2.active(),
		"and the end beat cuts it short: normal speed (%s)" % Engine.time_scale
	)
	hud2.finish_beat()
	hud2.queue_free()
	var dying := _sim()
	var node4 := LandmarkSlowmo.new(dying, null)
	dying.end("time")
	check(dying.death.active() and not dying.over, "(his death is playing, the run not over yet)")
	node4.trigger()
	check(not node4.active() and Engine.time_scale == 1.0, "his death playing is not slowed")
	node4.free()
	var over := _sim()
	var node3 := LandmarkSlowmo.new(over, null)
	over.end("time", true)
	node3.trigger()
	check(not node3.active() and Engine.time_scale == 1.0, "a finished rampage never slows")
	node3.free()
	node.queue_free()
	node2.queue_free()
	await _frames(2)


## The sim is stepped by a whole tick however slow the world is: at full speed by the tick's own
## delta; slowed, by one tick on the ticks the slowed clock has run one, none in between. A
## second of ticks at 0.35 steps 21 whole ticks, which is 0.35 s of sim time.
func _check_sim_takes_whole_ticks() -> void:
	var sim := _sim()
	var node := LandmarkSlowmo.new(sim, null)
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	Engine.time_scale = 1.0
	check(node.sim_dt(tick) == tick, "at full speed the sim gets the tick's own delta")
	Engine.time_scale = 0.35
	var steps := 0
	var whole := true
	var total := 0.0
	for _i: int in Engine.physics_ticks_per_second:
		var dt := node.sim_dt(tick * 0.35)  # the delta a tick is handed at 0.35
		if dt > 0.0:
			steps += 1
			total += dt
			whole = whole and dt == tick
	check(whole, "slowed, every sim step is a whole tick, never a shortened one")
	check(steps == 21, "a second of ticks at 0.35 steps the sim 21 times (%d)" % steps)
	check(absf(total - 0.35) < 1.0e-6, "which is 0.35 s of sim time (%.6f)" % total)
	Engine.time_scale = 1.0
	check(node.sim_dt(tick) == tick, "and back at full speed it steps by the tick's delta again")
	node.free()
