extends RefCounted
## The UI suite's title-menu checks (tests/run_ui_tests.gd): the director's own layout of
## 2026-10-23. Under the logo one row holds a wide Continue Game button (the save's kaiju and
## rampages) and a smaller New Kaiju?; with no save one wide New Kaiju takes Continue's place; a
## settings gear stands top-left and "Run for your life!?" bottom-right above the ticker; nothing
## else (no stacked Settings or Quit, no subtitle line). Focus order Continue, New Kaiju, gear,
## exit; hovering moves the focus; every button is a worn plate and its text 24 px or more.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const FocusOrder := preload("res://tests/lib/focus_order.gd")
const TitleLayout := preload("res://tests/lib/ui_title_layout.gd")
const CANVAS := Vector2i(1920, 1080)
const SUMMARY := "Reptilian, 7 rampages"
## The ticker along the bottom edge, and how far the corner buttons may stand from the screen's.
const TICKER := 56.0
const CORNER_MAX := 120.0
## The most of a plate's height (top and bottom each) a scratch may reach into: the label's band
## is the middle 60%.
const SCUFF_BAND := 0.2
## The ROADMAP's TV title-safe margin at the sides: 192 px at 4K, 96 at 1080p.
const SAFE_SIDE := 96.0
## Towers are wider than this; the lattice tower's 1 m beacon is a stand-in too, not a tower: it
## stands BEACON_RISE over the lattice tower's roof, high up.
const TOWER_MIN_WIDTH := 4.0
const LATTICE_MIN_Y := 20.0
const BEACON_RISE := 1.0

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


## D-158 option C: the title's far shore stands no tower, the lattice tower included, over tuning
## "title" "tower_cap" (one value, so the Colossus clears everything), while the game's own far
## shore (no cap) does: the same check fails on it, so it can fail.
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


## The top of the tallest far-shore tower or lattice tower (m) of a title-sized city whose far
## towers are capped at `cap` (0 = no cap).
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
		if at.z > far_z:
			continue
		if dim.x >= TOWER_MIN_WIDTH:
			top = maxf(top, at.y + dim.y * 0.5)
		elif at.y > LATTICE_MIN_Y:
			top = maxf(top, at.y - BEACON_RISE)
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
		fresh != null and fresh.text.strip_edges() != "",
		"with a save a labelled New Kaiju button stands beside Continue: %s" % [_texts(title)]
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
	FocusOrder.run(check, title, [cont, fresh, gear, exit], "with a save")
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


## The screen critic's fixes (2026-10-23, rounds 1 and 2) as rules (D-385): the row ends where the
## logo does, under it and inside its left edge, no two title controls overlap, each plate's label
## fits its plate, the gear's left edge on the column's and the exit's right margin the same, 14 px
## (28 at 4K) or more round each label, no scratches in the label's band or on the tape, no focus
## pointer and no fine inner frame on the plates.
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
	var lr := logo.get_global_rect() if logo != null else Rect2()
	check.call(
		logo != null and cr.position.x >= lr.position.x and cr.position.y >= lr.end.y,
		"the row stands under the logo, inside its left edge (%s under %s)" % [cr, lr]
	)
	TitleLayout.no_overlap(
		check, title, [logo, _button(title, "CONTINUE"), _button(title, "NEW KAIJU")]
	)
	var cramped: Array[String] = []
	for b: Button in [_button(title, "CONTINUE"), _button(title, "NEW KAIJU")]:
		if b.get_combined_minimum_size().y > b.size.y + 0.5:
			cramped.append(b.text)
	check.call(cramped.is_empty(), "every plate's label fits its plate: %s" % [cramped])
	# Director 2026-10-25: "shift the settings button further into the corner".
	check.call(
		(
			absf(gr.position.x - TitleScreen.GEAR_CORNER) <= 1.5
			and absf(gr.position.y - TitleScreen.GEAR_CORNER) <= 1.5
		),
		"the gear sits in the top-left corner, %d px in (%s)" % [TitleScreen.GEAR_CORNER, gr]
	)
	var exit := _button(title, "RUN FOR YOUR LIFE")
	var margin := CANVAS.x - (exit.get_global_rect().end.x - HazardBox.PLATE_SHADOW.x)
	check.call(
		absf(margin - cr.position.x) <= 1.5,
		"the exit's right margin is the row's left one (%d vs %d)" % [margin, cr.position.x]
	)
	var tag := ""
	var tag_x := 0.0
	for found: Node in title.find_children("*", "Label", true, false):
		if (found as Label).text == "BREAKING":
			# The ink's left edge: the tag is centred in its black box (director 2026-10-25).
			var lab := found as Label
			var ink := lab.get_theme_font("font").get_string_size(
				lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lab.get_theme_font_size("font_size")
			)
			var r := lab.get_global_rect()
			tag_x = r.position.x + (r.size.x - ink.x) * 0.5
			var box := (lab.get_parent() as Control).get_global_rect()
			check.call(
				(
					lab.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
					and absf(r.position.x - box.position.x) <= 0.5
					and absf(r.size.x - box.size.x) <= 0.5
				),
				"BREAKING is centred in its black box (%s in %s)" % [r, box]
			)
			tag = "BREAKING"
	check.call(
		(
			logo.get_global_rect().position.x >= SAFE_SIDE
			and cr.position.x >= SAFE_SIDE
			and margin >= SAFE_SIDE
			and tag == "BREAKING"
			and tag_x >= SAFE_SIDE
		),
		(
			"logo, plates, exit and the ticker's tag stand inside the TV title-safe margin"
			+ (
				" (%d px, 192 at 4K): %d %d %d %d %d"
				% [
					SAFE_SIDE,
					logo.get_global_rect().position.x,
					cr.position.x,
					gr.position.x,
					margin,
					tag_x
				]
			)
		)
	)
	TitleLayout.label_room(check, [_button(title, "CONTINUE"), _button(title, "NEW KAIJU")])
	var tape := (_button(title, "CONTINUE").get_theme_stylebox("normal") as HazardBox).band_size
	var plate := Rect2(Vector2.ZERO, cr.size)
	var lines := HazardBox.scuff_lines(plate, tape)
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
			return (
				minf(l[0].x, l[1].x) < plate.position.x + tape
				or maxf(l[0].x, l[1].x) > plate.end.x - tape
			)
	)
	check.call(on_tape.is_empty(), "no scratch runs onto the tape (%d do)" % on_tape.size())
	var focus := (_button(title, "CONTINUE")).get_theme_stylebox("focus") as HazardBox
	check.call(
		not focus.chevron, "the title's Continue plate has no focus pointer to crowd its frame"
	)


func _without_save() -> void:
	var title := await _title("")
	var fresh := _button(title, "NEW KAIJU")
	var gear := title.find_child("Gear", true, false) as Button
	var exit := _button(title, "RUN FOR YOUR LIFE")
	check.call(
		_button(title, "CONTINUE") == null and fresh != null and fresh.text.strip_edges() != "",
		"with no save one labelled New Kaiju replaces Continue: %s" % [_texts(title)]
	)
	if fresh != null and gear != null and exit != null:
		# Director 2026-10-25: "make the 'new kaiju' button significantly smaller".
		check.call(
			fresh.size.x < 400.0 and fresh.size.y <= TitleScreen.ALONE_HEIGHT + 1.0,
			"the lone New Kaiju is a small plate, not the row's width (%s)" % [fresh.size]
		)
		var no_tape := true
		for found: Node in title.find_children("*", "", true, false):
			if found is Control and (found as Control).get_global_rect().position.y < 1.0:
				var c := found as Control
				if (
					c.get_global_rect().size.y < 30.0
					and c.get_global_rect().size.x >= CANVAS.x - 1.0
				):
					no_tape = false
		check.call(no_tape, "no hazard tape runs along the top edge (director 2026-10-25)")
		FocusOrder.run(check, title, [fresh, gear, exit], "with no save")
	title.queue_free()
	await t.process_frame
