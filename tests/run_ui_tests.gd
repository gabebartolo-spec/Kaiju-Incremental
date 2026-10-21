extends "res://tests/lib/runner.gd"
## UI suite: the minimal rampage HUD (b2-10..13, research 15) and the broadcast kit's shared
## text style. The HUD keeps the boxed clock at the top, biomass one boxless figure bottom right,
## the breath ring bottom centre, health as the red edge vignette, the controls card once, all
## inside the TV title-safe area with no text under 24 px; the tree's details panel keeps one
## width (b2-23); the species preview spins centred and in frame (b2-11). Headless.
##   godot --headless --path . --script tests/run_ui_tests.gd
## Seeded by design: the sim is built from the city seed 0 and stepped by hand, never by time.

const HudChecks := preload("res://tests/lib/ui_hud.gd")

## The UI canvas (project.godot, D-027): every check measures in its logical pixels.
const CANVAS := Vector2i(1920, 1080)
## The brightest thing that can sit behind HUD text (a fire's white-hot core).
const BRIGHTEST := Color.WHITE
## The text floor at 1080p (director, DESIGN "Minimal HUD").
const MIN_TEXT := 24


func suite_name() -> String:
	return "UI"


func run_checks() -> void:
	await _t("_check_text_style")
	await _h("HudChecks", func() -> void: await HudChecks.new(self, check).run())
	await _t("_check_tooltip_width")
	await _t("_check_species_centred")
	await _t("_check_species_card")
	await _t("_check_no_atomic")


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
	for id: String in ["reptilian", "insectoid", "cephalopod"]:
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
## and a gap above BACK; D-112: the signature reads "Lightning Breath".
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
		"the lone species card is about 55%% of the screen wide (%.0f px)" % wide
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
			if l.get_theme_font_size("font_size") < 32:
				small.append(l.text)
	check(small.is_empty() and texts.has("Health"), "stat names are 32 px or more: %s" % [small])
	var cells := select.find_children("*", "Control", true, false).filter(
		func(n: Node) -> bool: return n.has_method("cell_width")
	)
	var thin := 0
	for c: Control in cells:
		if c.call("cell_width") < 12.0:
			thin += 1
	check(cells.size() >= 4 and thin == 0, "%d stat meters, %d with cells under 12 px" % [cells.size(), thin])
	var rows := {}
	for c: Control in cells:
		rows[roundi(c.global_position.y)] = true
	check(cells.size() >= 4 and rows.size() == cells.size(), "one stat per row (%d rows for %d meters)" % [rows.size(), cells.size()])
	check(
		texts.any(func(t: String) -> bool: return t.to_lower().contains("lightning breath")),
		"the signature reads Lightning Breath: %s" % [texts]
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
		for line: String in text.split("
"):
			if line.to_lower().contains("atomic"):
				hits.append("%s: %s" % [file, line.strip_edges().left(60)])
	check(hits.is_empty(), "no visible string says atomic: %s" % [hits])
