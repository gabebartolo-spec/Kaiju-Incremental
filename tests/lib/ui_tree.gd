extends RefCounted
## The UI suite's tree checks (tests/run_ui_tests.gd): every species' evolution tree at the
## 100% canvas and the 125% one (1536x864): node text 24 px or more that reads and fits, the
## locked outline and the species band caption at 4.5:1, and the band and caption clear of
## every node and line (critic r1 item 4, r2 item 4).

const CANVAS := Vector2i(1920, 1080)

var t: SceneTree
var check: Callable


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check


func run() -> void:
	await _tree_text()
	await _tree_layout()


## Critic r1 item 4: tree node text is 24 px or more at 1080p, every state's text, the locked
## outline and the branch caption read at 4.5:1 on what is behind them, and no node's text
## overflows its box, at the 100% canvas and the 125% one (1536x864).
func _tree_text() -> void:
	var window := t.root.size
	var bad: Array[String] = []
	var small := 99
	for size: Vector2i in [CANVAS, Vector2i(1536, 864)]:
		t.root.size = size
		for id: String in ["reptilian", "insectoid", "cephalopod"]:
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
			var area: TreeArea = screen.get("_area")
			var cap: Label = area.get("_caption")
			var band: ColorRect = area.get("_band")
			var under := Color(UiKit.BG).lerp(Color(band.color, 1.0), band.color.a)
			var cr := UiKit.contrast(cap.get_theme_color("font_color"), under)
			if cr < 4.5:
				bad.append("%s caption %.1f:1" % [id, cr])
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


## Critic r2 item 4: the species band starts below the row above it (no node straddles it), its
## caption touches no node and no line, reads "<Species> powers: only the <Species> can grow
## these", and the side panel's text is the nodes' size or more. At 100% and 125%.
func _tree_layout() -> void:
	var window := t.root.size
	var bad: Array[String] = []
	var copy := ""
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
		var band: ColorRect = area.get("_band")
		var cap: Label = area.get("_caption")
		copy = cap.text
		var caprect := Rect2(cap.position, cap.get_combined_minimum_size())
		for node: String in tree.order:
			var b := screen.node_button(node)
			var r := Rect2(b.position, b.size)
			var starts_above := r.position.y < band.position.y and r.end.y > band.position.y
			if starts_above:
				bad.append("%s straddles the band at %s" % [node, size])
			if r.intersects(caprect):
				bad.append("%s covers the caption at %s" % [node, size])
			var def: Dictionary = tree.defs[node]
			var requires: Array = def.get("requires", [])
			for req: String in requires:
				var from := screen.node_button(req)
				var a := from.position + from.size / 2.0
				var z := b.position + b.size / 2.0
				if _segment_hits(a, z, caprect):
					bad.append("line %s-%s crosses the caption at %s" % [req, node, size])
		if caprect.end.y > area.size.y:
			bad.append("the caption leaves the tree area at %s" % size)
		var info: RichTextLabel = screen.get("_info_body")
		body = mini(body, info.get_theme_font_size("normal_font_size"))
		screen.queue_free()
		await t.process_frame
	t.root.size = window
	check.call(
		bad.is_empty(),
		"the species band and caption are clear of nodes and lines: %s" % [bad.slice(0, 8)]
	)
	check.call(
		copy == "Reptilian powers: only the Reptilian can grow these", "the band reads: %s" % copy
	)
	check.call(body >= 24, "the side panel text is 24 px or more (%d)" % body)


## True when the segment a-b passes through `r` (sampled along its length).
func _segment_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	for i: int in 41:
		if r.has_point(a.lerp(b, i / 40.0)):
			return true
	return false
