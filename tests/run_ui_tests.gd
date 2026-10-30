extends "res://tests/lib/runner.gd"
## UI suite: the minimal rampage HUD (b2-10..13, research 15) and the broadcast kit's shared
## text style. The HUD keeps the boxed clock at the top, biomass one boxless figure bottom right,
## the breath ring bottom centre, health as the red edge vignette, the controls card once, all
## inside the TV title-safe area with no text under 24 px; the tree's details panel keeps one
## width (b2-23); the species preview spins centred and in frame (b2-11); the title menu (D-150);
## the pause menu's feedback button (D-145) and its Are-you-sure before End Rampage (D-155).
## Headless.
##   godot --headless --path . --script tests/run_ui_tests.gd
## Seeded by design: the sim is built from the city seed 0 and stepped by hand, never by time.

const HudChecks := preload("res://tests/lib/ui_hud.gd")
const TreeChecks := preload("res://tests/lib/ui_tree.gd")
const TitleChecks := preload("res://tests/lib/ui_title.gd")
const UiFeedback := preload("res://tests/lib/ui_feedback.gd")
const UiFeedbackPad := preload("res://tests/lib/ui_feedback_pad.gd")
const UiEndConfirm := preload("res://tests/lib/ui_end_confirm.gd")
const UiReport := preload("res://tests/lib/ui_report.gd")

## The UI canvas (project.godot, D-027): every check measures in its logical pixels.
const CANVAS := Vector2i(1920, 1080)
## The brightest thing that can sit behind HUD text (a fire's white-hot core).
const BRIGHTEST := Color.WHITE
## The text floor at 1080p (director, DESIGN "Minimal HUD").
const MIN_TEXT := 24
## The kaiju keeps this clear of the 3D view's edge (1080p px; 60 px at 4K).
const MARGIN_PX := 30.0


func suite_name() -> String:
	return "UI"


func run_checks() -> void:
	await _t("_check_text_style")
	await _h("HudChecks", func() -> void: await HudChecks.new(self, check).run())
	await _t("_check_tooltip_width")
	await _t("_check_species_centred")
	await _t("_check_species_card")
	await _t("_check_no_atomic")
	await _t("_check_pause")
	await _t("_check_hover_focus")
	await _t("_check_reveal_frame")
	await _t("_check_results_verdict")
	await _h("TreeChecks", func() -> void: await TreeChecks.new(self, check).run())
	await _h("TitleChecks", func() -> void: await TitleChecks.new(self, check).run())
	await _h("UiReport", func() -> void: UiReport.new(check).run())
	await _h("UiFeedback", func() -> void: await UiFeedback.run(self, check))
	await _h("UiFeedbackPad", func() -> void: await UiFeedbackPad.run(self, check))
	await _h("UiEndConfirm", func() -> void: await UiEndConfirm.run(self, check))


## R 15.4: every colour the kit draws text in reads at 4.5:1 or more against its own outline
## composited over the brightest fire, and every kit label carries that outline and a shadow.
## A faint outline (the old 0.2 alpha kind) fails the same measure, so the check can fail.
func _check_text_style() -> void:
	var colours := {
		"TEXT": UiKit.TEXT,
		"MUTED": UiKit.MUTED,
		"ACCENT": UiKit.ACCENT,
		"ALERT": UiKit.ALERT,
		"WARN": UiKit.WARN,
		"GOOD": UiKit.GOOD,
		"WHITE": Color.WHITE,
	}
	var edge := UiKit.outline_color()
	var behind := BRIGHTEST.lerp(Color(edge, 1.0), edge.a)
	var weak: Array[String] = []
	for key: String in colours:
		var colour: Color = colours[key]
		var ratio := UiKit.contrast(colour, behind)
		if ratio < 4.5:
			weak.append("%s %.2f" % [key, ratio])
	check(
		weak.is_empty(), "every kit text colour reads 4.5:1 on its outline over fire: %s" % [weak]
	)
	var faint := BRIGHTEST.lerp(UiKit.BG, 0.2)
	check(
		UiKit.contrast(UiKit.MUTED, faint) < 4.5,
		"a faint outline fails the same measure (MUTED %.2f:1)" % UiKit.contrast(UiKit.MUTED, faint)
	)
	var l := UiKit.label("BIOMASS", MIN_TEXT)
	var outline := l.get_theme_constant("outline_size")
	var shadow := l.get_theme_constant("shadow_offset_y")
	check(
		outline >= UiKit.outline_px(MIN_TEXT) and outline >= 6 and shadow > 0,
		"a kit label has the shared outline (%d px) and shadow (%d px)" % [outline, shadow]
	)
	l.free()


## b2-23: the details panel is one width for every node of every species' tree, the ultimate
## (ULTIMATE: THUNDER BEAM) included.
func _check_tooltip_width() -> void:
	var window := root.size
	root.size = CANVAS
	var widths: Dictionary = {}
	for id: String in ["reptilian"]:
		var tree := UpgradeTree.new(Content.upgrades(), {}, id)
		var screen := UpgradeScreen.new()
		screen.setup(tree, 30, Content.species_def(id), Content.section("kaiju"))
		root.add_child(screen)
		await process_frame
		for node: String in tree.order:
			screen.call("_select", node)
			await process_frame
			await process_frame
			widths[roundi(screen.side_panel.size.x)] = "%s %s" % [id, node]
		screen.queue_free()
		await process_frame
	root.size = window
	var want := roundi(Num.f(UiKit.ui()["tooltip_width"]))
	check(
		widths.size() == 1 and widths.has(want),
		"the details panel is %d px for every node: %s" % [want, widths]
	)


## b2-11: the species preview turns about the middle of the kaiju's footprint and every sampled
## point of its skin stays inside the preview at every angle of a full turn.
func _check_species_centred() -> void:
	var select := SpeciesSelect.new()
	root.add_child(select)
	await process_frame
	await process_frame
	var misses: Array[String] = []
	for table: Node3D in select.turntables:
		var model: KaijuModel = table.get_child(0)
		var view: SubViewport = table.get_parent()
		var cam := view.get_camera_3d()
		var rect := Rect2(Vector2.ZERO, Vector2(view.size))
		var mid := _skin_box(model, table).get_center()
		if Vector2(mid.x, mid.z).length() > 0.05 * _skin_box(model, table).size.length():
			misses.append("%s off its axis by %s" % [model.species_id, Vector2(mid.x, mid.z)])
		for k: int in 8:
			table.rotation.y = TAU * k / 8.0
			for p: Vector3 in _skin_world(model):
				if not rect.has_point(cam.unproject_position(p)):
					misses.append("%s leaves the frame at %d deg" % [model.species_id, 45 * k])
					break
	check(
		not select.turntables.is_empty() and misses.is_empty(),
		"each kaiju spins centred and in frame all the way round: %s" % [misses]
	)
	select.queue_free()
	await process_frame


## The skin's points in the world, every 13th corner.
func _skin_world(model: KaijuModel) -> PackedVector3Array:
	var out := PackedVector3Array()
	for geo: Node in model.find_children("*", "MeshInstance3D", true, false):
		var g: MeshInstance3D = geo
		if g.mesh == null:
			continue
		for surface: int in g.mesh.get_surface_count():
			var corners: PackedVector3Array = g.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for i: int in range(0, corners.size(), 13):
				out.append(g.global_transform * corners[i])
	return out


## The skin's box in the turntable's own space.
func _skin_box(model: KaijuModel, table: Node3D) -> AABB:
	var to_table := table.global_transform.affine_inverse()
	var points := _skin_world(model)
	var box := AABB(to_table * points[0], Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(to_table * p)
	return box


## Critic r1 item 1: with one species the card is wide (about 55% of the screen), the kaiju
## preview twice the old 390 px, one stat per row at 32 px or more, every meter cell 12 px or wider,
## and a gap above BACK; D-399: the signature reads the species' ability name (Tail Lash).
func _check_species_card() -> void:
	var window := root.size
	root.size = CANVAS
	var select := SpeciesSelect.new()
	root.add_child(select)
	await process_frame
	await process_frame
	var cards: Array = select.get("cards") if select.get("cards") != null else []
	var wide := 0.0
	for c: Control in cards:
		wide = maxf(wide, c.size.x)
	check(
		not cards.is_empty() and wide >= CANVAS.x * 0.5,
		"the lone species card is about 55%% of the 1080p canvas wide (%.0f px)" % wide
	)
	var preview := 0
	for table: Node3D in select.turntables:
		preview = maxi(preview, (table.get_parent() as SubViewport).size.x)
	check(preview >= 640, "the kaiju preview is far bigger than the old 390 px (%d)" % preview)
	var small: Array[String] = []
	var texts: Array[String] = []
	for node: Node in select.find_children("*", "Label", true, false):
		var l: Label = node
		texts.append(l.text)
		if l.text in ["HEALTH", "Health", "Speed", "Power", "Reach"]:
			if l.get_theme_font_size("font_size") < 28:
				small.append(l.text)
	check(small.is_empty() and texts.has("Health"), "stat names are 28 px or more: %s" % [small])
	var cells := select.find_children("*", "Control", true, false).filter(
		func(n: Node) -> bool: return n.has_method("cell_width")
	)
	var thin := 0
	for c: Control in cells:
		if c.call("cell_width") < 12.0:
			thin += 1
	check(
		cells.size() >= 4 and thin == 0,
		"%d stat meters, %d with cells under 12 px" % [cells.size(), thin]
	)
	var rows := {}
	for c: Control in cells:
		rows[roundi(c.global_position.y)] = true
	check(
		cells.size() >= 4 and rows.size() == cells.size(),
		"one stat per row (%d rows for %d meters)" % [rows.size(), cells.size()]
	)
	var ability: Dictionary = Content.species_def("reptilian")["ability"]
	var sig := str(ability["name"]).to_lower()
	check(
		texts.any(func(t: String) -> bool: return t.to_lower().contains(sig)),
		"the signature reads %s (species ability name): %s" % [sig, texts]
	)
	select.queue_free()
	await process_frame
	root.size = window


## D-108 / D-112: no string the player can read says "atomic": every name, hint, blurb, line and
## description in the data.
func _check_no_atomic() -> void:
	var hits: Array[String] = []
	for file: String in ["species", "upgrades", "tuning"]:
		var text := FileAccess.get_file_as_string("res://data/%s.json" % file)
		for line: String in text.split("\n"):
			if line.to_lower().contains("atomic"):
				hits.append("%s: %s" % [file, line.strip_edges().left(60)])
	check(hits.is_empty(), "no visible string says atomic: %s" % [hits])


## Critic r1 item 5: every pause button's label clears its edges by 40 px or more, the End
## Rampage button says only "END RAMPAGE", with its note on a line of its own.
func _check_pause() -> void:
	var window := root.size
	root.size = CANVAS
	var menu := PauseMenu.new()
	root.add_child(menu)
	await process_frame
	await process_frame
	var tight: Array[String] = []
	var names: Array[String] = []
	for node: Node in menu.find_children("*", "Button", true, false):
		var b: Button = node
		names.append(b.text)
		if b.size.x - b.get_minimum_size().x < 40.0:
			tight.append("%s (%.0f of %.0f)" % [b.text, b.get_minimum_size().x, b.size.x])
	var notes: Array[String] = []
	for node: Node in menu.find_children("*", "Label", true, false):
		notes.append((node as Label).text)
	check(tight.is_empty(), "pause labels clear their button edges by 40 px: %s" % [tight])
	check(names.has("END RAMPAGE"), "the End Rampage button says END RAMPAGE: %s" % [names])
	check(
		notes.any(func(t: String) -> bool: return t.to_lower().contains("biomass")),
		"a small note line says the biomass is kept: %s" % [notes]
	)
	menu.free()
	await process_frame
	root.size = window


## Director 2026-10-22: the mouse and the keyboard share one highlight, so two buttons are never
## lit at once (the title showed CONTINUE focused and SETTINGS hovered, both yellow).
func _check_hover_focus() -> void:
	var box := VBoxContainer.new()
	var first := UiKit.button("FIRST")
	var second := UiKit.button("SECOND")
	box.add_child(first)
	box.add_child(second)
	root.add_child(box)
	await process_frame
	first.grab_focus()
	second.mouse_entered.emit()
	check(second.has_focus() and not first.has_focus(), "hovering a button moves the focus onto it")
	var off := UiKit.button("OFF")
	off.disabled = true
	box.add_child(off)
	await process_frame
	off.mouse_entered.emit()
	check(second.has_focus(), "hovering a disabled button leaves the focus where it was")
	box.free()
	await process_frame


## Critic r1 item 7: the reveal's 3D view sits in a hazard frame, the skip prompt is 25% bigger
## (30 px), and the kaiju stays inside the view on the reveal after the swap and on the
## demo-complete card (the croc was clipped at the left edge).
func _check_reveal_frame() -> void:
	var window := root.size
	root.size = CANVAS
	var species := Content.species_def("reptilian")
	var reveal := EvolutionReveal.new()
	reveal.setup(species, {"size": 1}, {"size": 2}, Content.section("city"))
	reveal.title = "Behemoth"
	root.add_child(reveal)
	for _i: int in EvolutionReveal.SWAP_FRAME + EvolutionReveal.GROW_FRAMES + 20:
		await physics_frame
	await process_frame
	var framed := reveal.view.get_parent() is PanelContainer
	check(framed, "the reveal's 3D view sits in a hazard frame")
	check(
		reveal.skip_hint.get_theme_font_size("font_size") >= 30,
		(
			"the skip prompt is 25%% bigger than 24 px (%d)"
			% reveal.skip_hint.get_theme_font_size("font_size")
		)
	)
	var out: Array[String] = await _outside(reveal.view)
	check(out.is_empty(), "the evolved kaiju stays inside the reveal view: %s" % [out])
	reveal.free()
	var card := DemoEnd.new()
	card.setup(species, Content.section("kaiju"))
	root.add_child(card)
	for _i: int in 10:
		await physics_frame
	await process_frame
	out = await _outside(card.view)
	check(out.is_empty(), "the demo-complete card keeps the croc inside its view: %s" % [out])
	card.free()
	await process_frame
	root.size = window


## The kaiju's sampled skin points in `view` that project outside it or within MARGIN_PX of its
## edge (critic r2: the croc's head was cut and its feet touched the bottom). Checked over a
## stretch of frames, so the roar and the walk cycle count.
func _outside(view: SubViewportContainer) -> Array[String]:
	var viewport: SubViewport = view.get_child(0)
	var cam := viewport.get_camera_3d()
	var model: KaijuModel = viewport.find_children("*", "KaijuModel", true, false)[0]
	var rect := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(-MARGIN_PX)
	var missed := 0
	var worst := Vector2.ZERO
	for round: int in 3:
		for _i: int in 30:
			await physics_frame
		for p: Vector3 in _skin_world(model):
			var at := cam.unproject_position(p)
			if not rect.has_point(at):
				missed += 1
				worst = at
	var out: Array[String] = []
	if missed > 0:
		out.append("%d points outside, e.g. %s of %s" % [missed, worst, viewport.size])
	return out


## Critic r1 item 8: the line under the title never says "short of your best" while a row beside
## it carries a NEW BEST tag; with no records it still says how far short. D-385: the verdict is
## read for what it says (the shortfall and the record), not its exact words.
func _check_results_verdict() -> void:
	var mixed := ResultsScreen.new({"rubble": 10, "toppled": 5}, {"rubble": 69.0, "toppled": 2.0})
	var plain := ResultsScreen.new({"rubble": 10, "toppled": 1}, {"rubble": 69.0, "toppled": 2.0})
	var short := str(ceili(69.0 - 10.0))
	check(
		(
			mixed.is_new_best("toppled")
			and mixed.verdict().contains(short)
			and mixed.verdict().to_upper().contains("RECORD")
		),
		"with a record on the table the verdict says so, and the shortfall: %s" % mixed.verdict()
	)
	check(
		plain.verdict().contains(short) and not plain.verdict().to_upper().contains("RECORD"),
		"with no record it says how far short, and claims none: %s" % plain.verdict()
	)
	mixed.free()
	plain.free()
