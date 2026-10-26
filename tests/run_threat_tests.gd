extends "res://tests/lib/runner.gd"
## Threat suite (D-259 "A small threat icon", news crawl "On big events"; D-260 specimens): the
## threat level is the army's escalation read out (1-5, data rows); the sim reports each rise, each
## felled landmark and each tower total once; every report has a short crawl line (the VIP's wait
## for the helicopter); the bar under the clock reads the level by filled segments and
## the progress by the current one;
## the crawl slides up for each moment in turn; every death owes one lab card; and by real input
## through Main a death puts the lab card (K-01 LOST - K-02 RELEASED) before the next rise.
## Seeded by design: the sims are built on pinned seeds and their state set by hand; no outcome
## of play is checked.
##   godot --headless --path . --script tests/run_threat_tests.gd

const ThreatPlay := preload("res://tests/lib/threat_play.gd")
## A landmark and a plain block: enough city for the sim's reports.
const LAYOUT: Array[Dictionary] = [
	{"x": 0.0, "z": 0.0, "w": 4, "d": 4, "h": 4, "tier": 1, "style": 0, "landmark": "spire"},
	{"x": -8.0, "z": 0.0, "w": 3, "d": 3, "h": 3, "tier": 1, "style": 1},
]
## A crawl line stays a headline: at most this many characters.
const MAX_LINE := 36


func suite_name() -> String:
	return "Threat"


func run_checks() -> void:
	await _t("_check_levels")
	await _t("_check_threat_events")
	await _t("_check_landmark_event")
	await _t("_check_tower_totals")
	await _t("_check_lines")
	await _t("_check_lab_card_save")
	await _h("Threat play", func() -> void: await ThreatPlay.new(self, check).run())


## A small sim on pinned seeds (ThreatPlay builds its own too).
static func small_sim() -> RampageSim:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	return RampageSim.new(stats, Content.tuning(), LAYOUT, Seeds.make("army", 0))


## Level 1 while the city is caught unaware, 5 once the army spawns as fast as it can, one up at
## each data row; never outside 1-5.
func _check_levels() -> void:
	var at: Array = Content.section("threat")["level_at"]
	check(at.size() == 4, "four rows lift the level from 1 to 5: %s" % [at])
	check(RunNews.level_for(0.0, at) == 1, "no escalation reads level 1")
	var seen: Array[int] = []
	for share: Variant in at:
		seen.append(RunNews.level_for(Num.f(share) - 0.001, at))
		seen.append(RunNews.level_for(Num.f(share), at))
	check(
		seen == [1, 2, 2, 3, 3, 4, 4, 5],
		"each row lifts the level by one at its share and not before: %s" % [seen]
	)
	check(RunNews.level_for(9.0, at) == 5, "the level stops at 5")
	var sim := small_sim()
	check(is_zero_approx(RunNews.army_share(sim)), "a fresh rampage's army has not escalated")
	sim.chunks_destroyed = ThreatPlay.chunks_at(sim, 1.0)
	check(
		is_equal_approx(RunNews.army_share(sim), 1.0),
		"at the army's fastest spawn rate the share is 1 (%d chunks)" % sim.chunks_destroyed
	)


## As the city falls the sim reports each new level once, in order, and never a fall back.
func _check_threat_events() -> void:
	var sim := small_sim()
	var at: Array = Content.section("threat")["level_at"]
	var levels: Array[int] = []
	for share: Variant in at + [1.0, 0.0]:
		sim.chunks_destroyed = ThreatPlay.chunks_at(sim, Num.f(share))
		var events: Array[Dictionary] = []
		sim.news.step(events)
		sim.news.step(events)  # a second look at the same city adds nothing
		for e: Dictionary in events:
			if e["type"] == "threat_up":
				levels.append(Num.i(e["level"]))
	check(levels == [2, 3, 4, 5], "one threat_up per level, in order: %s" % [levels])
	check(sim.news.level == 5, "the level stays at its peak (%d)" % sim.news.level)


## A landmark is reported once, the step it loses the felled share; a flattened block never is.
func _check_landmark_event() -> void:
	var sim := small_sim()
	var share := Num.f(Content.section("results")["landmark_felled_share"])
	var mark := sim.buildings[0]
	var cells := ThreatPlay.cells(mark)
	var under := ceili(share * cells.size()) - 1
	for c: Vector3i in cells.slice(0, under):
		mark.frame.remove(c)
	for c: Vector3i in ThreatPlay.cells(sim.buildings[1]):
		sim.buildings[1].frame.remove(c)
	var before: Array[Dictionary] = []
	sim.news.step(before)
	check(before.is_empty(), "short of the share nothing is felled: %s" % [before])
	mark.frame.remove(cells[under])
	var events: Array[Dictionary] = []
	sim.news.step(events)
	sim.news.step(events)
	check(
		events == [{"type": "landmark_felled", "landmark": "spire"}],
		"the chunk that reaches the share reports the spire once: %s" % [events]
	)


## Each tower total in data is reported once, when the toppled count reaches it.
func _check_tower_totals() -> void:
	var sim := small_sim()
	var counts: Array[int] = []
	for toppled: int in [1, 3, 12, 12, 60, 140]:
		sim.collapse.toppled = toppled
		var events: Array[Dictionary] = []
		sim.news.step(events)
		for e: Dictionary in events:
			counts.append(Num.i(e["count"]))
	var rows: Array = Content.section("threat")["tower_counts"]
	check(counts.size() == rows.size(), "every total is reported: %s of %s" % [counts, rows])
	var same := true
	for i: int in mini(counts.size(), rows.size()):
		same = same and counts[i] == Num.i(rows[i])
	check(same, "the totals come once each, in order: %s" % [counts])


## Every report has a short, upper-case crawl line; the VIP's events have theirs; anything else
## is not news.
func _check_lines() -> void:
	var events: Array[Dictionary] = [
		{"type": "landmark_felled", "landmark": "stadium"},
		{"type": "landmark_felled", "landmark": "wheel"},
		{"type": "landmark_felled", "landmark": "a_new_one"},
		{"type": "towers_toppled", "count": 10},
		{"type": "vip_spawned"},
		{"type": "vip_killed"},
		{"type": "vip_escaped"},
	]
	for level: int in [2, 3, 4, 5]:
		events.append({"type": "threat_up", "level": level})
	var bad: Array[String] = []
	var lines: Dictionary = {}
	for e: Dictionary in events:
		var line := RampageNews.line_for(e)
		lines[line] = true
		if line == "" or line.length() > MAX_LINE or line != line.to_upper():
			bad.append("%s: '%s'" % [e["type"], line])
	check(
		bad.is_empty(), "each report has a headline of %d or fewer capitals: %s" % [MAX_LINE, bad]
	)
	check(lines.size() == events.size(), "no two reports share a line")
	check(
		RampageNews.line_for({"type": "towers_toppled", "count": 25}).begins_with("25 "),
		"a tower total names its number"
	)
	check(RampageNews.line_for({"type": "stomp"}) == "", "an everyday event is not news")


## Every death owes one lab card; the city's fall owes none; an older save owes none; the flag
## survives a reload.
func _check_lab_card_save() -> void:
	var save := SaveFile.new_save("reptilian")
	check(not SaveFile.take_lab_card(save), "a new kaiju owes no lab card")
	SaveFile.note_end(save, {"reason": "city_fallen"})
	check(not SaveFile.take_lab_card(save), "felling the city owes no lab card")
	for reason: String in SaveFile.DEATHS:
		SaveFile.note_end(save, {"reason": reason})
		var owed := SaveFile.take_lab_card(save)
		check(owed and not SaveFile.take_lab_card(save), "'%s' owes one lab card" % reason)
	SaveFile.note_end(save, {"reason": "time"})
	SaveFile.save_game(save, 3)
	var back := SaveFile.load_game(3)
	check(SaveFile.take_lab_card(back), "the owed card survives a reload")
	SaveFile.delete_save(3)
	var old := save.duplicate()
	old.erase("lab_card")
	check(not SaveFile.take_lab_card(old), "a save from before the card owes none")
	check(
		SpecimenCard.fill("K-{lost} LOST, K-{next} RELEASED", 2) == "K-01 LOST, K-02 RELEASED",
		"the headline names the lost specimen and the next"
	)
