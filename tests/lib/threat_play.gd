extends RefCounted
## The threat suite's on-screen checks (tests/run_threat_tests.gd): the badge beside a centred
## clock, by number and lit bars; the crawl sliding up for each big moment in turn and hiding for
## the end beat; then by real input through Main: a threat rise, a landmark fall and a death, and
## the lab card before the next rise.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const CreationWalk := preload("res://tests/lib/creation_walk.gd")
const MAIN_SCENE := "res://scenes/main.tscn"
const CANVAS := Vector2i(1920, 1080)
## The director's TV (D-027).
const TV_SIZE := Vector2i(3840, 2160)
const MIN_TEXT := 24
const DT := 1.0 / 60.0
## Frames (suites run at a fixed 60 fps) the queued crawl lines get to show in turn, and the
## lab card to make way.
const CRAWL_WAIT_FRAMES := 60 * 30
const CARD_WAIT_FRAMES := 60 * 6
## Frames for a set ending to land (the rise from the river runs first).
const END_WAIT_FRAMES := 60 * 20

var t: SceneTree
var check: Callable


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check


func run() -> void:
	var window := t.root.size
	t.root.size = CANVAS
	PlayerSettings.controls_seen = true
	await _hud_checks()
	t.root.size = TV_SIZE
	await _by_input()
	t.root.size = window


## Every live cell of `b`.
static func cells(b: RampageSim.Building) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x: int in b.w:
		for z: int in b.d:
			for y: int in b.height:
				if b.frame.alive(Vector3i(x, y, z)):
					out.append(Vector3i(x, y, z))
	return out


## Chunks of escalation at which the army has climbed `share` of its spawn ramp.
static func chunks_at(sim: RampageSim, share: float) -> int:
	var span := Num.f(sim.army["start_interval"]) - Num.f(sim.army["min_interval"])
	return ceili(share * span / Num.f(sim.army["escalation_per_chunk"]))


func _sim() -> RampageSim:
	var tuning := Content.tuning()
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var layout := CityGrowth.layout(tuning, 1, Seeds.make("city", 0))
	return RampageSim.new(stats, CityGrowth.tuning_for(tuning, 1), layout, Seeds.make("army", 0))


func _hud_checks() -> void:
	var sim := _sim()
	var hud := RampageHud.new(sim, Content.species_def("reptilian"), null)
	t.root.add_child(hud)
	await _frames(3)
	_layout(hud)
	_levels_read_without_colour(hud.clock.badge)
	hud.clock.badge.show_level(1, false)
	sim.chunks_destroyed = chunks_at(sim, 0.25)
	await _step(hud, sim)
	var badge := hud.clock.badge
	check.call(
		badge.level == 2 and badge.digit.text == "2" and badge.meter.lit == 2,
		"a rise shows level 2 by number and two lit bars: %s" % badge.digit.text
	)
	check.call(badge.scale.x > 1.01, "the rise pops the badge (scale %.2f)" % badge.scale.x)
	var line := RampageNews.line_for({"type": "threat_up", "level": 2})
	check.call(
		hud.news.showing() and hud.news.shown == PackedStringArray([line]),
		"the crawl slides up with the rise's line: %s" % [hud.news.shown]
	)
	var strip := hud.news.ticker
	check.call(
		(
			strip != null
			and strip.unit_width() >= 2.0 * strip.visible_width() + strip.headlines_width()
		),
		"one line never shows twice on the strip at once"
	)
	sim.chunks_destroyed = chunks_at(sim, 1.0)
	sim.collapse.toppled = 10
	await _step(hud, sim)
	for _i: int in CRAWL_WAIT_FRAMES:
		if hud.news.shown.size() >= 3:
			break
		await t.process_frame
	var want := PackedStringArray(
		[
			line,
			RampageNews.line_for({"type": "threat_up", "level": 5}),
			RampageNews.line_for({"type": "towers_toppled", "count": 10}),
		]
	)
	check.call(
		hud.news.shown == want,
		"moments in one step crawl past one after another: %s" % [hud.news.shown]
	)
	hud.show_end_beat("time")
	await _frames(2)
	check.call(not hud.news.visible, "the crawl gives way to the end beat")
	hud.finish_beat()
	hud.queue_free()
	await _frames(2)


func _step(hud: RampageHud, sim: RampageSim) -> void:
	sim.step(DT, Vector2.ZERO, false, 0)
	hud.refresh()
	await t.physics_frame
	await _frames(2)


## The clock stays dead centre; the badge sits right of it in the title-safe area, its text 24 px
## or more.
func _layout(hud: RampageHud) -> void:
	var view := t.root.get_visible_rect()
	var clock := hud.clock_label().get_global_rect()
	var badge := hud.clock.badge.get_global_rect()
	check.call(
		absf(clock.get_center().x - view.get_center().x) <= 1.0,
		"the clock stays centred beside the badge: %.1f" % clock.get_center().x
	)
	var safe := view.grow_individual(
		-UiKit.safe_margin().x, -UiKit.safe_margin().y, -UiKit.safe_margin().x, 0.0
	)
	check.call(
		badge.position.x >= clock.end.x and safe.encloses(badge),
		"the badge sits right of the clock inside the safe area: %s" % badge
	)
	var small: Array[String] = []
	for label: Label in hud.clock.badge.find_children("*", "Label", true, false):
		var px := label.get_theme_font_size("font_size")
		if px < MIN_TEXT:
			small.append("%s %d" % [label.text, px])
	check.call(small.is_empty(), "badge text is %d px or more: %s" % [MIN_TEXT, small])


## Each level shows its own number and its own count of lit bars (colour-blind safe).
func _levels_read_without_colour(badge: ThreatBadge) -> void:
	var seen: Array[String] = []
	for n: int in [1, 2, 3, 4, 5]:
		badge.show_level(n, false)
		seen.append("%s/%d" % [badge.digit.text, badge.meter.lit])
	check.call(
		seen == ["1/1", "2/2", "3/3", "4/4", "5/5"],
		"levels read by number and lit bars: %s" % [seen]
	)


## A new kaiju by clicks; a threat rise and a felled landmark reach the crawl; time's up kills it;
## EVOLVE, RAMPAGE: the lab card for K-02, then the rise.
func _by_input() -> void:
	SaveFile.wipe()
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	t.root.add_child(main)
	await _frames(3)
	await GuiInput.click(t, GuiInput.button(_screen(main), "NEW KAIJU"))
	await _frames(2)
	await CreationWalk.walk(t, main)
	var rampage := _screen(main) as Rampage
	check.call(rampage != null, "a rampage is on")
	if rampage == null:
		main.queue_free()
		return
	await rampage.wait_loaded()
	var sim := rampage.sim
	for _i: int in END_WAIT_FRAMES:  # the rise from the river first: the sim waits for it
		if not sim.emerge.active:
			break
		await t.process_frame
	var hud := GuiInput.find_script(rampage, RampageHud) as RampageHud
	sim.chunks_destroyed += chunks_at(sim, 0.25)
	_fell_landmark(sim)
	await _frames(30)
	var news := hud.news.shown + hud.news.waiting()
	check.call(hud.clock.badge.level >= 2, "in play the badge rises (%d)" % hud.clock.badge.level)
	check.call(
		(
			news.has(RampageNews.line_for({"type": "threat_up", "level": 2}))
			and news.has(_landmark_line(sim))
		),
		"in play the rise and the felled landmark reach the crawl: %s" % [news]
	)
	for _i: int in END_WAIT_FRAMES:
		if sim.over:
			break
		sim.time_left = 0.0
		await t.process_frame
	await _frames(RampageHud.BEAT_MIN_FRAMES + 2)
	await GuiInput.key(t, KEY_ENTER)
	await _frames(2)
	var results := GuiInput.find_script(rampage, ResultsScreen) as ResultsScreen
	if results != null:
		await GuiInput.key(t, KEY_ENTER)
		await GuiInput.click(t, GuiInput.button(results, "EVOLVE"))
		await _frames(2)
	var tree := _screen(main) as UpgradeScreen
	check.call(tree != null, "time's up leads through the report to the tree")
	if tree != null:
		await GuiInput.click(t, GuiInput.button(tree, "RAMPAGE"))
		await _frames(2)
		await _lab_card(main)
	main.queue_free()
	await _frames(2)
	SaveFile.wipe()


func _lab_card(main: Node) -> void:
	var card := _screen(main) as SpecimenCard
	check.call(card != null, "RAMPAGE after a death opens the lab card: %s" % _screen(main))
	if card == null:
		return
	check.call(
		card.title.text == "SPECIMEN K-02" and card.headline_text() == "K-01 LOST · K-02 RELEASED",
		"the card names K-02 and the loss: %s / %s" % [card.title.text, card.headline_text()]
	)
	var missing: Array[String] = []
	for label: Label in [card.title, card.lost, card.released]:
		var font := label.get_theme_font("font")
		for i: int in label.text.length():
			if not font.has_char(label.text.unicode_at(i)):
				missing.append(label.text[i])
	check.call(missing.is_empty(), "the card's fonts draw every letter: %s" % [missing])
	var frames := 0
	while not _screen(main) is Rampage and frames < CARD_WAIT_FRAMES:
		frames += 1
		await t.process_frame
	var shown_s := (frames + 2) * DT
	check.call(
		_screen(main) is Rampage and absf(shown_s - 2.0) < 0.2,
		"after about 2 s (%.1f s) the new specimen rises" % shown_s
	)
	var save := SaveFile.load_game(1)
	check.call(
		Num.i(save.get("specimen", 0)) == 2 and save.get("lab_card", true) == false,
		"the slot holds K-02 and owes no card: %s" % [save.get("specimen")]
	)


## Removes the felled share of the first landmark's chunks (the sim's own rule then reports it).
func _fell_landmark(sim: RampageSim) -> void:
	for b: RampageSim.Building in sim.buildings:
		if b.landmark != "":
			var share := Num.f(Content.section("results")["landmark_felled_share"])
			var live := cells(b)
			for c: Vector3i in live.slice(0, ceili(share * live.size())):
				b.frame.remove(c)
			return


func _landmark_line(sim: RampageSim) -> String:
	for b: RampageSim.Building in sim.buildings:
		if b.landmark != "":
			return RampageNews.line_for({"type": "landmark_felled", "landmark": b.landmark})
	return "no landmark"


func _screen(main: Node) -> Node:
	return main.call("screen")


func _frames(n: int) -> void:
	for _i: int in n:
		await t.process_frame
