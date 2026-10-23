extends RefCounted
## The flow suite's layout checks (tests/lib/flow_screens.gd calls them): every screen's buttons
## stay on the director's 4K TV at every UI scale, and the evolution reveal fits and measures
## against the new stage's city.

const GuiInput := preload("res://tests/lib/gui_input.gd")

## The director's TV (D-027). Headless windows are 64x64 (a tall square canvas), so each check
## sizes the window to this first.
const TV_SIZE := Vector2i(3840, 2160)
## The TV bar for text: cap height in real pixels on the TV (lead review 3).
const TV_CAP_PX := 28.0
## Cap height of the UI fonts as a share of their size (Open Sans / Kaiju Claw, about 0.71).
const CAP_SHARE := 0.71
## Every face the game draws text in is one of ours (D-058): Kaiju Block, headings Kaiju Claw.
const OUR_FONTS := "res://assets/fonts/kaiju_"

## The currency's old name (D-056: the kaiju earns BIOMASS); no visible text may say it.
const OLD_CURRENCY := "rubble"

var t: SceneTree
var check: Callable

## Visible texts that still say OLD_CURRENCY, "<where>: <text>" (listen() fills it).
var said: Array[String] = []
## Visible texts drawn in a face that is not ours (the engine default), "<where>: <text>".
var foreign: Array[String] = []


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check


func _frames(n: int) -> void:
	for _i: int in n:
		await t.process_frame


## Every UI scale keeps a screen's buttons fully on screen (the 4K TV at 125%, lead review 1).
func fits_at_scales(screen: Control, what: String) -> void:
	var misses: Array[String] = []
	# Headless windows are 64x64 (a tall square canvas); measure on the director's 4K TV.
	var window := t.root.size
	t.root.size = TV_SIZE
	for scale: float in PlayerSettings.UI_SCALES:
		PlayerSettings.ui_scale = scale
		PlayerSettings.apply()
		await _frames(3)
		var view := t.root.get_visible_rect()
		var nodes: Array[UpgradeNode] = []
		var crawls: Array[Rect2] = []
		for node: Node in screen.find_children("*", "Control", true, false):
			if node is NewsTicker:
				crawls.append((node as Control).get_global_rect())
		for node: Node in screen.find_children("*", "Button", true, false):
			var b: Button = node
			var name := b.text.get_slice(String.chr(10), 0)
			var at := " at %d%%" % roundi(scale * 100.0)
			if b.is_visible_in_tree() and not view.encloses(b.get_global_rect()):
				misses.append(name + at + " off screen")
			for crawl: Rect2 in crawls:
				if b.is_visible_in_tree() and crawl.intersects(b.get_global_rect()):
					misses.append(name + at + " under the news crawl")
			if b is UpgradeNode:
				nodes.append(b)
				if (
					b.get_minimum_size().y > b.size.y + 0.5
					or b.get_global_transform().get_scale().x != 1.0
				):
					misses.append(name + at + " text does not fit")
				if _breaks_a_word(b):
					var room := b.size.x - b.get_theme_stylebox("normal").get_minimum_size().x
					var px_size := b.get_theme_font_size("font_size")
					misses.append(
						"%s%s breaks a word (%.0f px room, %d px text)" % [name, at, room, px_size]
					)
				var px := (
					b.get_theme_font_size("font_size") * (TV_SIZE.y / 1080.0) * scale * CAP_SHARE
				)
				if px < TV_CAP_PX:
					misses.append("%s%s cap %.0f px" % [name, at, px])
		for node: Node in screen.find_children("*", "Label", true, false):
			var l: Label = node
			for n: UpgradeNode in nodes:
				if (
					l.is_visible_in_tree()
					and l.text != ""
					and l.get_global_rect().intersects(n.get_global_rect().grow(-1.0))
				):
					misses.append(
						"label '%s' under %s at %d%%" % [l.text, n.id, roundi(scale * 100.0)]
					)
		for i: int in nodes.size():
			for j: int in range(i + 1, nodes.size()):
				if nodes[i].get_global_rect().grow(-1.0).intersects(nodes[j].get_global_rect()):
					misses.append(
						"%s touches %s at %d%%" % [nodes[i].id, nodes[j].id, roundi(scale * 100.0)]
					)
	PlayerSettings.ui_scale = PlayerSettings.UI_SCALES[0]
	PlayerSettings.apply()
	t.root.size = window
	await _frames(2)
	(
		check
		. call(
			misses.is_empty(),
			(
				"the %s fits the TV at every UI scale (on screen, 28 px, no overlaps, clear of crawl): %s"
				% [what, misses]
			)
		)
	)


## The reveal measures against the new stage's city (D-039): the Colossus topples size x tier
## height floors, taller than the Behemoth's reveal tower (D-135: three steps, two reveals).
func reveal_stage_city() -> void:
	var tuning := Content.tuning()
	var behemoth: Dictionary = CityGrowth.tuning_for(tuning, 2)["city"]
	var colossus: Dictionary = CityGrowth.tuning_for(tuning, 3)["city"]
	var species := Content.species_def("reptilian")
	var first := EvolutionReveal.new()
	first.setup(species, {"size": 1}, {"size": 2}, behemoth)
	var reveal := EvolutionReveal.new()
	reveal.setup(species, {"size": 2}, {"size": 3}, colossus)
	var want := mini(3 * Num.i(colossus["tier_height"]), Num.i(colossus["max_height"]))
	check.call(
		reveal.tower_floors == want and want > first.tower_floors,
		(
			"the Colossus's reveal tower is %d floors from its stage's city (Behemoth's %d)"
			% [reveal.tower_floors, first.tower_floors]
		)
	)
	first.free()
	reveal.free()


## The reveal's size lines stay on screen on the TV at the largest UI scale (lead review 2).
func reveal_fits() -> void:
	var window := t.root.size
	t.root.size = TV_SIZE
	PlayerSettings.ui_scale = PlayerSettings.UI_SCALES[-1]
	PlayerSettings.apply()
	var reveal := EvolutionReveal.new()
	reveal.setup(
		Content.species_def("reptilian"), {"size": 1}, {"size": 2}, Content.section("city")
	)
	t.root.add_child(reveal)
	await _frames(3)
	var frame_before := reveal.view.size
	var hint_before := reveal.skip_hint.get_global_rect().position
	await _frames(EvolutionReveal.SWAP_FRAME + 1)
	var hint_after := reveal.skip_hint.get_global_rect().position
	check.call(
		hint_after == hint_before,
		"the reveal's skip prompt stays put through the swap: %s, %s" % [hint_before, hint_after]
	)
	check.call(
		reveal.view.size == frame_before and frame_before.y > 0.0,
		(
			"the reveal's frame keeps one size through the swap: %s, %s"
			% [frame_before, reveal.view.size]
		)
	)
	var rect := reveal.lines.get_global_rect()
	var on := t.root.get_visible_rect().encloses(rect) and reveal.lines.text != ""
	check.call(reveal.roar.playing, "the evolved kaiju roars as it is revealed")
	reveal.finish()
	PlayerSettings.ui_scale = PlayerSettings.UI_SCALES[0]
	PlayerSettings.apply()
	t.root.size = window
	await _frames(2)
	check.call(on, "the reveal's size lines stay on screen at 125%% on the TV: %s" % [rect])


## True when the node's name wraps inside a word ("Regeneratio / n", lead review 3) or its
## level-and-price line wraps at all ("0/1 BUY / 1400").
func _breaks_a_word(b: Button) -> bool:
	var status := TextParagraph.new()
	status.add_string(
		b.text.get_slice(String.chr(10), 1),
		b.get_theme_font("font"),
		b.get_theme_font_size("font_size")
	)
	status.width = b.size.x - b.get_theme_stylebox("normal").get_minimum_size().x
	if status.get_line_count() > 1:
		return true
	var name := b.text.get_slice(String.chr(10), 0)
	var line := TextParagraph.new()
	line.add_string(name, b.get_theme_font("font"), b.get_theme_font_size("font_size"))
	line.width = b.size.x - b.get_theme_stylebox("normal").get_minimum_size().x
	line.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	line.break_flags |= TextServer.BREAK_ADAPTIVE
	for i: int in range(1, line.get_line_count()):
		var start := line.get_line_range(i).x
		if start > 0 and name[start - 1] != " ":
			return true
	return false


## Notes every visible label, button and rich text under `root` that says OLD_CURRENCY or is
## drawn in a face that is not ours.
func listen(root: Node, where: String) -> void:
	for node: Node in root.find_children("*", "Control", true, false):
		var text := ""
		if node is Label:
			text = (node as Label).text
		elif node is Button:
			text = (node as Button).text
		elif node is RichTextLabel:
			text = (node as RichTextLabel).get_parsed_text()
		if text == "" or not (node as Control).is_visible_in_tree():
			continue
		var line := "%s: %s" % [where, text.get_slice(String.chr(10), 0)]
		if text.containsn(OLD_CURRENCY):
			said.append(line)
		var slot := "normal_font" if node is RichTextLabel else "font"
		var face := (node as Control).get_theme_font(slot)
		if face == null or not face.resource_path.begins_with(OUR_FONTS):
			foreign.append(line)


## D-056: the screens listen() heard, and every node's description, call the currency biomass.
func currency_named() -> void:
	for up: Dictionary in Content.upgrades():
		if str(up.get("desc", "")).containsn(OLD_CURRENCY):
			said.append("node %s: %s" % [up["id"], up["desc"]])
	check.call(
		said.is_empty(), "no screen or node says %s (D-056 biomass): %s" % [OLD_CURRENCY, said]
	)


## D-058: every text listen() heard is drawn in one of our faces, never the engine default.
func fonts_ours() -> void:
	check.call(
		foreign.is_empty(),
		(
			"every screen's text is in our own fonts (D-058): %d not: %s"
			% [foreign.size(), foreign.slice(0, 6)]
		)
	)
	foreign.clear()


## A world hint that pops during the end beat: how many still show two frames later (0 wanted:
## nothing behind the headline).
static func late_hints(runner: SceneTree, rampage: Rampage) -> int:
	var city: CityView = GuiInput.find_script(rampage, CityView)
	var at := rampage.sim.kaiju_pos
	city.float_text("LATE HINT", Vector3(at.x, 4.0, at.y), Color.WHITE)
	await runner.process_frame
	await runner.process_frame
	var hints := city.find_children("*", "Label3D", true, false).filter(
		func(n: Node) -> bool: return (n as Label3D).visible and (n as Label3D).text != ""
	)
	return hints.size()


## The news crawl reads: white on its strip at body-text contrast, and one cycle of headlines is
## at least as wide as the strip even with a single short headline, so no headline shows twice
## at once (screen critic round 2).
func crawl_reads(screen: Node, what: String) -> void:
	var crawl: NewsTicker = null
	for node: Node in screen.find_children("*", "Control", true, false):
		if node is NewsTicker:
			crawl = node
	var ratio := UiKit.contrast(Color.WHITE, crawl.strip.color)
	check.call(
		ratio >= 4.5, "the %s crawl's text is %.2f:1 on its strip (4.5 wanted)" % [what, ratio]
	)
	var window := t.root.size
	t.root.size = TV_SIZE
	var short := NewsTicker.new(PackedStringArray(["ONE HEADLINE"]))
	short.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	t.root.add_child(short)
	await _frames(3)
	var cycle := short.unit_width()
	var span := short.visible_width()
	short.queue_free()
	t.root.size = window
	await _frames(2)
	check.call(
		cycle >= span,
		"a one-headline crawl never shows it twice: cycle %.0f px, strip %.0f px" % [cycle, span]
	)
