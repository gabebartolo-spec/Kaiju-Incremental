extends RefCounted
## The UI suite's tree checks (tests/run_ui_tests.gd): every species' evolution tree at the
## 100% canvas and the 125% one (1536x864): node text 24 px or more that reads and fits, the
## locked outline at 4.5:1; the map (D-275) opens at the default zoom on the newest node you can
## buy, and the side panel's text is the nodes' size or more (critic r1 item 4, r2 item 4).

const CANVAS := Vector2i(1920, 1080)

var t: SceneTree
var check: Callable


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check


func run() -> void:
	await _tree_text()
	await _tree_layout()
	await _tree_fx()


## Critic r1 item 4: tree node text is 24 px or more at 1080p, every state's text, the locked
## outline read at 4.5:1 on what is behind them, and no node's text overflows its box, at the 100%
## canvas and the 125% one (1536x864).
func _tree_text() -> void:
	var window := t.root.size
	var bad: Array[String] = []
	var small := 99
	for size: Vector2i in [CANVAS, Vector2i(1536, 864)]:
		t.root.size = size
		for id: String in ["reptilian"]:
			var tree := UpgradeTree.new(Content.upgrades(), {}, id)
			var screen := UpgradeScreen.new()
			screen.setup(tree, 400, Content.species_def(id), Content.section("kaiju"))
			t.root.add_child(screen)
			await t.process_frame
			await t.process_frame
			for node: String in tree.order:
				var b := screen.node_button(node)
				var fs := b.get_theme_font_size("font_size")
				if size == CANVAS:
					small = mini(small, fs)
				if b.get_minimum_size().y > b.size.y + 1.0:
					bad.append("%s/%s overflows at %s" % [id, node, size])
				var fill := b.get_theme_stylebox("normal") as HazardBox
				var ratio := UiKit.contrast(b.get_theme_color("font_color"), fill.fill)
				if ratio < 4.5:
					bad.append("%s %s text %.1f:1" % [node, b.state, ratio])
				if (
					b.state == "locked"
					and UiKit.contrast(fill.edge, UiKit.BG) < 4.5
					and node == tree.order[0]
				):
					bad.append("locked outline %.1f:1" % UiKit.contrast(fill.edge, UiKit.BG))
			screen.queue_free()
			await t.process_frame
	t.root.size = window
	check.call(
		small >= 24, "tree node text is at least 24 px at 1080p (was 22) (smallest %d)" % small
	)
	check.call(
		bad.is_empty(), "tree text reads and fits at 100%% and 125%%: %s" % [bad.slice(0, 12)]
	)
	check.call(
		UiKit.contrast(UiKit.LOCKED, UiKit.BG) >= 4.5,
		(
			"the locked outline colour reads 4.5:1 on the screen (%.1f)"
			% UiKit.contrast(UiKit.LOCKED, UiKit.BG)
		)
	)


## D-396, the fixture: with tree.skin.fx on, a buy sets the juice going (motes, a surge or a
## flash playing; the kaiju at the centre), the cell fills toward its level and the counter counts
## down; with it off, the buy changes the state alone: nothing plays, the liquid and the counter
## jump, no specimen. Half a second of frames at 60 fps, delta-driven (no clock).
func _tree_fx() -> void:
	var fx: Dictionary = Content.section("tree")["skin"]["fx"]
	var was: Variant = fx["enabled"]
	var seen: Dictionary = {}
	for on: bool in [true, false]:
		fx["enabled"] = on
		var tree := UpgradeTree.new(Content.upgrades(), {}, "reptilian")
		var screen := UpgradeScreen.new()
		screen.setup(tree, 400, Content.species_def("reptilian"), Content.section("kaiju"))
		t.root.add_child(screen)
		await t.process_frame
		await t.process_frame
		var area: TreeArea = screen.get("_area")
		var id := screen.newest_buyable()
		var counter: Label = screen.get("_rubble_label")
		screen.node_button(id).pressed.emit()
		await t.process_frame
		var playing := area.fx.busy()
		var liquid_at_once := screen.node_button(id).liquid
		var counter_at_once := counter.text
		for i: int in 30:
			area.fx.advance(1.0 / 60.0)
			await t.process_frame
		seen[on] = {
			"playing": playing,
			"liquid_jumped": is_equal_approx(liquid_at_once, 1.0 / float(tree.max_level(id))),
			"counter_jumped": counter_at_once == tr("BIOMASS  %d") % screen.rubble,
			"liquid_rising": screen.node_button(id).liquid > 0.0,
			"specimen": area.specimen != null,
			"bought": tree.level(id) == 1,
		}
		screen.queue_free()
		await t.process_frame
	fx["enabled"] = was
	var on_s: Dictionary = seen[true]
	var off_s: Dictionary = seen[false]
	check.call(
		(
			on_s["playing"]
			and on_s["liquid_rising"]
			and on_s["specimen"]
			and not on_s["liquid_jumped"]
			and not on_s["counter_jumped"]
			and on_s["bought"]
		),
		"tree fx on: a buy plays juice, fills the cell, counts the biomass down: %s" % [on_s]
	)
	check.call(
		(
			not off_s["playing"]
			and off_s["liquid_jumped"]
			and off_s["counter_jumped"]
			and not off_s["specimen"]
			and off_s["bought"]
		),
		"tree fx off: the buy alone, nothing plays, no specimen: %s" % [off_s]
	)


## The map opens at the default zoom (text 24 px at 1080p, nodes unscaled) centred, as near as the
## clamps allow, on the newest node you can buy (D-275); the side panel's text is the nodes' size
## or more (critic r2 item 4). At 100% and 125%.
func _tree_layout() -> void:
	var window := t.root.size
	var bad: Array[String] = []
	var body := 99
	for size: Vector2i in [CANVAS, Vector2i(1536, 864)]:
		t.root.size = size
		var tree := UpgradeTree.new(Content.upgrades(), {}, "reptilian")
		var screen := UpgradeScreen.new()
		screen.setup(tree, 400, Content.species_def("reptilian"), Content.section("kaiju"))
		t.root.add_child(screen)
		await t.process_frame
		await t.process_frame
		var area: TreeArea = screen.get("_area")
		var newest := screen.newest_buyable()
		var want := TreeView.new(area.layout.bounds, area.size, area.view.fit_margin)
		var newest_at: Vector2 = area.layout.centres[newest]
		want.look_at(newest_at)
		if not is_equal_approx(area.view.zoom, TreeView.DEFAULT_ZOOM):
			bad.append("opens at zoom %.2f at %s" % [area.view.zoom, size])
		if area.view.centre.distance_to(want.centre) > 1.0:
			bad.append("opens on %s not %s at %s" % [area.view.centre, newest, size])
		if not tree.can_buy(newest, 400):
			bad.append("%s is not buyable with 400 at %s" % [newest, size])
		var info: RichTextLabel = screen.get("_info_body")
		body = mini(body, info.get_theme_font_size("normal_font_size"))
		screen.queue_free()
		await t.process_frame
	t.root.size = window
	check.call(
		bad.is_empty(), "the map opens at the default zoom on the newest buyable node: %s" % [bad]
	)
	check.call(body >= 24, "the side panel text is 24 px or more (%d)" % body)
