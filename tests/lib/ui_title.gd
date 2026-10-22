extends RefCounted
## The UI suite's title-menu checks (tests/run_ui_tests.gd): the director's own layout of
## 2026-10-23. Under the logo one row holds a wide Continue Game button (the save's kaiju and
## rampages) and a smaller New Kaiju?; with no save one wide New Kaiju takes Continue's place; a
## settings gear stands top-left and "Run for your life!?" bottom-right above the ticker; nothing
## else (no stacked Settings or Quit, no subtitle line). Focus order Continue, New Kaiju, gear,
## exit; hovering moves the focus; every button is a worn plate and its text 24 px or more.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const CANVAS := Vector2i(1920, 1080)
const SUMMARY := "Reptilian, 7 rampages"
## The ticker along the bottom edge, and how far the corner buttons may stand from the screen's.
const TICKER := 56.0
const CORNER_MAX := 120.0
## Room each side of a label (px at 1080p; 28 at 4K) and the tape bands on a plate (two).
const LABEL_ROOM := 14.0
const NEWLINE := "\n"
const PLATE_BANDS := 2.0
## The most of a plate's height (top and bottom each) a scratch may reach into: the label's band
## is the middle 60%.
const SCUFF_BAND := 0.2
## The row's left edge stands this far (px at 1080p, the least and the most) in from the logo's box:
## the plate's outline lands on the logo's ink (measured on a 4K capture: 127 vs 128 px).
const INSET_FROM := 5.0
const INSET_TO := 7.0
## Towers are wider than this; the lattice tower's 1 m beacon is a stand-in too, not a tower.
const TOWER_MIN_WIDTH := 4.0

var t: SceneTree
var check: Callable


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check


func run() -> void:
	var window := t.root.size
	t.root.size = CANVAS
	await _with_save()
	await _without_save()
	t.root.size = window
	await _far_tower_cap()


## D-158 option C: the title's far shore stands no tower over tuning "title" "tower_cap" (one value,
## so the Colossus clears every tower), while the game's own far shore (no cap) does: the same check
## fails on it, so it can fail.
func _far_tower_cap() -> void:
	var cap := Num.f(Content.section("title")["tower_cap"])
	var game := await _far_top(0.0)
	var title := await _far_top(cap)
	check.call(
		game > cap + 1.0, "the uncapped far shore has a tower over %d m (%.1f m)" % [cap, game]
	)
	check.call(
		title > 0.0 and title <= cap + 0.01,
		"the title's far shore has no tower over its %d m cap (%.1f m)" % [cap, title]
	)


## The top of the tallest far-shore tower (m) of a title-sized city whose far towers are capped at
## `cap` (0 = no cap).
func _far_top(cap: float) -> float:
	var cfg := Content.section("title")
	var tuning := CityGrowth.tuning_for(Content.tuning(), Num.i(cfg["city_tier"]))
	var city: Dictionary = tuning["city"]
	city["far_tower_cap"] = cap
	var layout := CityGrowth.layout(
		Content.tuning(), Num.i(cfg["city_tier"]), Seeds.make("city", 0)
	)
	var sim := RampageSim.new({}, tuning, layout, Seeds.make("army", 0))
	var holder := Node3D.new()
	t.root.add_child(holder)
	var ground := CityGround.new(sim.city)
	holder.add_child(ground)
	var skyline := CitySkyline.new(ground, Seeds.make("skyline", 0))
	holder.add_child(skyline)
	await t.process_frame
	var far_z := Num.f(sim.city["coast_z"]) - Num.f(sim.city["bay_width"])
	var top := 0.0
	for box: Dictionary in skyline.stand_ins():
		var at: Vector3 = box["at"]
		var dim: Vector3 = box["size"]
		if at.z <= far_z and dim.x >= TOWER_MIN_WIDTH:
			top = maxf(top, at.y + dim.y * 0.5)
	holder.free()
	return top


## A title built on the 1080p canvas (no live city: the 3D backdrop needs a renderer).
func _title(summary: String) -> TitleScreen:
	var title := TitleScreen.new()
	title.live_city = false
	title.setup(summary)
	t.root.add_child(title)
	await t.process_frame
	await t.process_frame
	return title


func _button(title: Node, prefix: String) -> Button:
	return GuiInput.button(title, prefix)


func _texts(title: Node) -> Array[String]:
	var texts: Array[String] = []
	for found: Node in title.find_children("*", "Button", true, false):
		var b := found as Button
		if b.is_visible_in_tree():
			texts.append(b.text)
	return texts


func _with_save() -> void:
	var title := await _title(SUMMARY)
	var cont := _button(title, "CONTINUE")
	var fresh := _button(title, "NEW KAIJU")
	var gear := title.find_child("Gear", true, false) as Button
	var exit := _button(title, "RUN FOR YOUR LIFE")
	check.call(
		cont != null and cont.text.contains(SUMMARY.to_upper()),
		"Continue Game carries the save's kaiju and rampages: %s" % [_texts(title)]
	)
	check.call(
		fresh != null and fresh.text == "NEW KAIJU?",
		"with a save the second button asks New Kaiju?: %s" % [_texts(title)]
	)
	check.call(gear != null and gear.text == "", "a textless settings gear button exists")
	check.call(exit != null, "the exit button says Run for your life!?")
	if cont == null or fresh == null or gear == null or exit == null:
		title.queue_free()
		return
	var cr := cont.get_global_rect()
	var fr := fresh.get_global_rect()
	check.call(
		is_equal_approx(cr.position.y, fr.position.y) and cr.end.x < fr.position.x,
		"Continue and New Kaiju? share one row, Continue on the left (%s, %s)" % [cr, fr]
	)
	check.call(
		cr.size.x > fr.size.x,
		"Continue is the wide primary button (%d vs %d)" % [cr.size.x, fr.size.x]
	)
	var gone: Array[String] = []
	for text: String in _texts(title):
		if text.begins_with("SETTINGS") or text.begins_with("QUIT"):
			gone.append(text)
	check.call(gone.is_empty(), "no stacked Settings or Quit button remains: %s" % [gone])
	var stray := false
	for found: Node in title.find_children("*", "Label", true, false):
		var label := found as Label
		if label.is_visible_in_tree() and label.text == SUMMARY:
			stray = true
	check.call(not stray, "the save summary is inside Continue, not a line under it")
	var gr := gear.get_global_rect()
	check.call(
		gr.position.x < CORNER_MAX and gr.position.y < CORNER_MAX and gr.size.x == gr.size.y,
		"the gear is a small square top-left (%s)" % [gr]
	)
	var er := exit.get_global_rect()
	check.call(
		(
			CANVAS.x - er.end.x < CORNER_MAX
			and CANVAS.y - TICKER - er.end.y < CORNER_MAX
			and er.end.y <= CANVAS.y - TICKER
		),
		"the exit button sits bottom-right just above the ticker (%s)" % [er]
	)
	_row_fits(title, cr, fr, gr)
	check.call(
		fr.end.x <= CANVAS.x * 0.4,
		"the button row stays in the left 40%% of the screen (ends at %d)" % int(fr.end.x)
	)
	_focus_order(title, [cont, fresh, gear, exit], "with a save")
	gear.grab_focus()
	cont.mouse_entered.emit()
	check.call(cont.has_focus() and not gear.has_focus(), "hovering Continue moves the focus to it")
	var small: Array[String] = []
	var flat: Array[String] = []
	for b: Button in [cont, fresh, gear, exit]:
		if b.get_theme_font_size("font_size") < 24:
			small.append(b.text)
		var box := b.get_theme_stylebox("normal") as HazardBox
		if box == null or not box.plated:
			flat.append(b.name)
	check.call(small.is_empty(), "every title button's text is 24 px or more: %s" % [small])
	check.call(flat.is_empty(), "every title button is a worn plate: %s" % [flat])
	title.queue_free()
	await t.process_frame


## The screen critic's fixes (2026-10-23, rounds 1 and 2): the row ends where the logo does and
## starts at its yellow (ROW_INSET in), Continue about 70% of it, the Continue plate's face 100 px
## (200 px at 4K, 9% of the height) or more, the gear's left edge on the column's and the exit's
## right margin the same, 14 px (28 at 4K) or more round each label, no scratches in the label's
## band, no focus pointer and no fine inner frame on the plates.
func _row_fits(title: Node, cr: Rect2, fr: Rect2, gr: Rect2) -> void:
	var logo: Label
	for found: Node in title.find_children("*", "Label", true, false):
		if (found as Label).text == "KAIJU EVOLUTION":
			logo = found as Label
	var row := fr.end.x - cr.position.x
	check.call(
		(
			logo != null
			and absf(row + TitleScreen.ROW_INSET - logo.get_combined_minimum_size().x) <= 2.0
		),
		(
			"the button row ends where the logo does, inset to its yellow (%d + %d vs %d)"
			% [row, TitleScreen.ROW_INSET, logo.get_combined_minimum_size().x if logo else 0]
		)
	)
	var in_from_logo := cr.position.x - logo.get_global_rect().position.x
	check.call(
		in_from_logo >= INSET_FROM and in_from_logo <= INSET_TO,
		(
			"the row starts %d px in from the logo's box, on its ink (%d..%d)"
			% [in_from_logo, INSET_FROM, INSET_TO]
		)
	)
	var share := cr.size.x / row
	check.call(share >= 0.65 and share <= 0.8, "Continue takes about 3/4 of the row (%.2f)" % share)
	var face := cr.size.y - HazardBox.PLATE_SHADOW.y
	check.call(
		face >= CANVAS.y * 0.0925 and face <= CANVAS.y * 0.1,
		"the Continue plate's face is 9-10%% of the height, 200 px or more at 4K (%d)" % face
	)
	check.call(
		absf(gr.position.x - cr.position.x) <= 1.5,
		"the gear's left edge is on the column's (%d vs %d)" % [gr.position.x, cr.position.x]
	)
	var exit := _button(title, "RUN FOR YOUR LIFE")
	var margin := CANVAS.x - (exit.get_global_rect().end.x - HazardBox.PLATE_SHADOW.x)
	check.call(
		absf(margin - cr.position.x) <= 1.5,
		"the exit's right margin is the row's left one (%d vs %d)" % [margin, cr.position.x]
	)
	_label_room([_button(title, "CONTINUE"), _button(title, "NEW KAIJU")])
	var lines := HazardBox.scuff_lines(Rect2(0, 0, 400, cr.size.y), 22.0)
	var strip := cr.size.y * SCUFF_BAND + HazardBox.PLATE_BEVEL + 1.0
	var crossing := lines.filter(
		func(l: PackedVector2Array) -> bool:
			return (
				(l[0].y > strip and l[0].y < cr.size.y - strip)
				or (l[1].y > strip and l[1].y < cr.size.y - strip)
			)
	)
	check.call(
		lines.size() == HazardBox.SCUFFS and crossing.is_empty(),
		(
			"no scratch reaches the label's band of a plate (%d of %d cross)"
			% [crossing.size(), lines.size()]
		)
	)
	var on_tape := lines.filter(
		func(l: PackedVector2Array) -> bool:
			return l[0].x < 22.0 or l[1].x < 22.0 or l[0].x > 378.0 or l[1].x > 378.0
	)
	check.call(on_tape.is_empty(), "no scratch runs onto the tape (%d do)" % on_tape.size())
	var focus := (_button(title, "CONTINUE")).get_theme_stylebox("focus") as HazardBox
	check.call(
		not focus.chevron, "the title's Continue plate has no focus pointer to crowd its frame"
	)


## Each plate leaves 14 px (28 at 4K) or more between its tape and its widest label line.
func _label_room(buttons: Array) -> void:
	var tight: Array[String] = []
	for found: Variant in buttons:
		var b: Button = found
		var box := b.get_theme_stylebox("normal") as HazardBox
		var font := b.get_theme_font("font")
		var size := b.get_theme_font_size("font_size")
		var widest := 0.0
		for line: String in b.text.split(NEWLINE):
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		var face := b.size.x - HazardBox.PLATE_SHADOW.x
		var room := (face - PLATE_BANDS * box.band_size - widest) / 2.0
		if room < LABEL_ROOM:
			tight.append("%s %.1f px" % [b.text, room])
	check.call(tight.is_empty(), "every title label has 14 px or more each side: %s" % [tight])


func _without_save() -> void:
	var title := await _title("")
	var fresh := _button(title, "NEW KAIJU")
	var gear := title.find_child("Gear", true, false) as Button
	var exit := _button(title, "RUN FOR YOUR LIFE")
	check.call(
		_button(title, "CONTINUE") == null and fresh != null and fresh.text == "NEW KAIJU",
		"with no save one wide New Kaiju replaces Continue: %s" % [_texts(title)]
	)
	if fresh != null and gear != null and exit != null:
		check.call(
			fresh.size.x > 500.0,
			"that New Kaiju takes Continue's place and size (%d)" % fresh.size.x
		)
		_focus_order(title, [fresh, gear, exit], "with no save")
	title.queue_free()
	await t.process_frame


## Tab order: each button's focus_next is the next one in `order`, wrapping round.
func _focus_order(title: Node, order: Array, label: String) -> void:
	var good := true
	for i: int in order.size():
		var here: Button = order[i]
		var next: Button = order[(i + 1) % order.size()]
		if here.get_node_or_null(here.focus_next) != next:
			good = false
	check.call(good, "focus order %s is Continue/New Kaiju, gear, exit (%s)" % [label, title.name])
