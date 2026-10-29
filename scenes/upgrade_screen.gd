class_name UpgradeScreen
extends Control
## The evolution tree between rampages. Spend rubble on nodes, see what each changes in play
## (each stat now, an arrow, after the next level), then start the next rampage. TreeArea lays
## the nodes out on polar rings, the baby's ring at the centre, under a camera that zooms and
## pans (D-275); it opens on the newest node you can buy. Reads the tree; buying goes through it.

signal start_pressed
signal bought(id: String)
signal menu_pressed
signal endless_pressed

## The stat rows' "now" column: one width for every row, so the arrows sit in one column.
const NOW_WIDTH := 64
const NBSP := " "
var tree: UpgradeTree
## Set before the screen is added: the final upgrade is owned, so Endless mode is offered (D-156).
var endless_unlocked := false
var rubble: int
var species: Dictionary
var base_stats: Dictionary
## The node details panel beside the tree: one fixed width for every node (b2-23, tuning "ui"
## tooltip_width), so picking a long-named node never reshapes the screen.
var side_panel: Control
var _area: TreeArea
var _rubble_label: Label
## The biomass the counter shows: it counts down to `rubble` after a buy (tuning fx fill_s).
var _rubble_shown := -1
var _rubble_tween: Tween
## The readout's header: the specimen's species and growth stage.
var _specimen_label: Label
var _info_title: Label
var _info_role: Label
var _info_body: RichTextLabel
var _info_stats: VBoxContainer
var _info_status: Label
var _selected := ""
var _ultimate_cooldown := 0.0


func setup(p_tree: UpgradeTree, p_rubble: int, p_species: Dictionary, p_base: Dictionary) -> void:
	tree = p_tree
	rubble = p_rubble
	species = p_species
	base_stats = p_base


func _ready() -> void:
	_ultimate_cooldown = Num.f(Content.section("powers").get("ultimate_cooldown", 0.0))
	UiKit.full_rect(self)
	add_child(UiKit.backdrop())
	var root := MarginContainer.new()
	UiKit.full_rect(root)
	for side: String in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 32)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	root.add_child(col)
	_add_header(col)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	col.add_child(body)
	_area = TreeArea.new()
	_area.setup(tree, species, _roles())
	_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area.node_pressed.connect(_on_node_pressed)
	_area.node_selected.connect(_select)
	body.add_child(_area)
	body.add_child(_build_side())
	_selected = tree.order[0]
	_refresh()
	_area.centre_on(newest_buyable())


func _roles() -> Dictionary:
	var roles: Dictionary = {}
	for id: String in tree.order:
		roles[id] = role_of(id)
	return roles


## The title, the rubble counter and the MENU button across the top.
func _add_header(col: Control) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	col.add_child(header)
	var title := UiKit.label(tr("EVOLUTION TREE"), 48, UiKit.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_rubble_label = UiKit.label("", UiKit.SIZE_HEAD, UiKit.WARN)
	header.add_child(_rubble_label)
	var menu := UiKit.button(tr("MENU"), UiKit.SIZE_BODY, UiKit.PANEL_EDGE)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	header.add_child(menu)


func _build_side() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(Num.f(UiKit.ui()["tooltip_width"]), 0)
	side.size_flags_horizontal = Control.SIZE_SHRINK_END
	side_panel = side
	side.add_theme_constant_override("separation", 12)
	var info := UiKit.panel()
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(info)
	var info_col := VBoxContainer.new()
	info.add_child(info_col)
	_build_readout_head(info_col)
	# The node's stats sit half a line below its words, in columns: the arrows line up (D-077).
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UiKit.SIZE_BODY / 2.0)
	info_col.add_child(gap)
	_info_stats = VBoxContainer.new()
	_info_stats.add_theme_constant_override("separation", 2)
	info_col.add_child(_info_stats)
	# Level, cost and the buy line stay on the panel's bottom edge on every node.
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_col.add_child(push)
	_info_status = UiKit.label("", UiKit.SIZE_BODY, UiKit.TEXT)
	_info_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_status)
	var go := UiKit.button(tr("RAMPAGE  >"), UiKit.SIZE_HEAD)
	go.custom_minimum_size = Vector2(0, 80)
	go.pressed.connect(func() -> void: start_pressed.emit())
	side.add_child(go)
	_add_endless(side)
	go.grab_focus.call_deferred()
	return side


## The readout's head (D-395): the specimen line and its rule, then the node's name, role and words.
func _build_readout_head(info_col: VBoxContainer) -> void:
	_specimen_label = UiKit.label("", UiKit.SIZE_BODY, UiKit.ACCENT)
	_specimen_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_specimen_label)
	var rule := ColorRect.new()
	rule.color = Color(UiKit.ACCENT, 0.5)
	rule.custom_minimum_size = Vector2(0, 2)
	info_col.add_child(rule)
	_info_title = UiKit.label("", UiKit.SIZE_HEAD, UiKit.TEXT)
	_info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_title)
	_info_role = UiKit.label("", UiKit.SIZE_BODY, UiKit.WARN)
	_info_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_role)
	_info_body = UiKit.rich(UiKit.SIZE_BODY, UiKit.MUTED.lightened(0.2))
	info_col.add_child(_info_body)


## The final upgrade unlocks Endless mode (D-156): its button sits under RAMPAGE.
func _add_endless(side: Control) -> void:
	if not endless_unlocked:
		return
	var endless := UiKit.button(tr("ENDLESS MODE"), UiKit.SIZE_BODY, UiKit.PANEL_EDGE)
	endless.custom_minimum_size = Vector2(0, 64)
	endless.pressed.connect(func() -> void: endless_pressed.emit())
	side.add_child(endless)


## "ultimate": the species' ultimate (data "ultimate", its own button, D-040); "evolve": grows the
## kaiju a size; "branch": the rest of the species' own nodes; "plain": the shared tree.
func role_of(id: String) -> String:
	var def: Dictionary = tree.defs[id]
	var effects: Dictionary = def.get("effects", {})
	if effects.has("size"):
		return "evolve"
	if def.get("ultimate", false) == true:
		return "ultimate"
	return "plain" if str(def.get("species", "")) == "" else "branch"


## The node the tree opens on (D-275): the one that can be bought now in the outermost ring, the
## last in data order (the newest to open); else the outermost one still to buy; else the first.
func newest_buyable() -> String:
	var best := ""
	var fallback := ""
	for id: String in tree.order:
		if tree.can_buy(id, rubble):
			if best == "" or tree.ring(id) >= tree.ring(best):
				best = id
		elif tree.is_unlocked(id) and not tree.is_maxed(id):
			if fallback == "" or tree.ring(id) >= tree.ring(fallback):
				fallback = id
	if best != "":
		return best
	return fallback if fallback != "" else tree.order[0]


func _on_node_pressed(id: String) -> void:
	var rings_open := _rings_open()
	var price := tree.buy(id, rubble)
	if price <= 0:
		Sfx.ui("ui_deny")
	else:
		rubble -= price
		_play_bought(id, rings_open)
		bought.emit(id)
		get_node("/root/EventBus").emit_signal("upgrade_bought", id)
	_select(id)
	_refresh()


## The juice and sound of a buy: motes from the biomass counter into the node, Special K down its
## tubes; a rim flare when a ring opens; bolts and the evolution strike on a stage node.
func _play_bought(id: String, rings_before: int) -> void:
	var from := _rubble_label.get_global_rect().get_center() - _area.get_global_position()
	_area.play_buy(id, from)
	if tree.kind(id) == "stage":
		_area.play_evolve(id)
		Sfx.ui("tree_evolve")
	elif tree.is_maxed(id):
		Sfx.ui("tree_maxed")
	else:
		Sfx.ui("tree_buy")
	var rings_after := _rings_open()
	if rings_after > rings_before:
		_area.play_ring_open(rings_after)
		Sfx.ui("tree_ring_open")


## The outermost open ring (1-based, as UpgradeTree.ring).
func _rings_open() -> int:
	var n := 0
	for r: int in range(1, tree.rings.size() + 1):
		if tree.ring_open(r):
			n = r
	return n


func _select(id: String) -> void:
	_selected = id
	if node_button(id).shape_only:
		_show_shape()
		return
	var def: Dictionary = tree.defs[id]
	_info_title.text = tr(str(def["name"]))
	var role := role_of(id)
	_info_role.text = {
		"plain": "",
		"branch": "",
		"evolve": tr("EVOLUTION"),
		"ultimate": tr("ULTIMATE"),
	}[role]
	_info_body.clear()
	_info_body.append_text(tr(UpgradeTree.desc_for(def, str(species["id"]))))
	var stats := UpgradeTree.run_stats(base_stats, species, tree)
	var steps := 0 if tree.is_maxed(id) else 1
	if role == "evolve" and steps > 0:
		var stage := KaijuModel.stage_for(Num.i(stats.get("size", 1)) + 1)
		_info_body.append_text("\n" + _grows_into(stage))
		# No-break spaces keep "fall to you." together when the line wraps (no orphan "you").
		_info_body.append_text(
			"\n" + tr("Towers one tier taller now fall%sto%syou.") % [NBSP, NBSP]
		)
	if role == "ultimate":
		_info_body.append_text(
			(
				"\n"
				+ tr("Press E / pad Y in a rampage; recharges in %ds.") % roundi(_ultimate_cooldown)
			)
		)
	_show_stats(UpgradeTree.effects_for(def, str(species["id"])), stats, steps)
	_info_status.text = _status_line(id)
	var b := node_button(id)
	var tint: Color = {"buy": UiKit.GOOD, "poor": UiKit.BAD, "maxed": UiKit.WARN}.get(
		b.state, UiKit.MUTED
	)
	_info_status.add_theme_color_override("font_color", tint)


## A node in the next ring out keeps its secret: the panel shows its shape's "?" and nothing else.
func _show_shape() -> void:
	_info_title.text = UpgradeNode.SHAPE_TEXT
	_info_role.text = ""
	_info_body.clear()
	_show_stats({}, {}, 0)
	_info_status.text = ""


func _grows_into(stage: String) -> String:
	match stage:
		"baby":
			return tr("Grows into the baby.")
		"adolescent":
			return tr("Grows into the adolescent.")
	return tr("Grows into the adult.")


func _status_line(id: String) -> String:
	var head := tr("Level %d / %d") % [tree.level(id), tree.max_level(id)] + "   "
	if tree.is_maxed(id):
		return head + tr("MAXED")
	if not tree.is_unlocked(id):
		var def: Dictionary = tree.defs[id]
		var names: Array[String] = []
		var requires: Array = def.get("requires", [])
		for req: String in requires:
			if tree.level(req) < 1:
				var req_def: Dictionary = tree.defs[req]
				names.append(tr(str(req_def["name"])))
		# Owned from an older save in a ring that is not open yet: nothing named to buy first.
		if names.is_empty():
			return head + tr("Not yet")
		return head + tr("Needs: %s") % ", ".join(names)
	# Three short lines, so no wrap ever leaves a dash or a lone word at a line end.
	var nl := String.chr(10)
	var have := (tr("Cost %d") + nl + tr("You have %d biomass") + nl) % [tree.cost(id), rubble]
	if tree.can_buy(id, rubble):
		return head + have + tr("Enter / pad A to buy")
	return head + have + tr("%d more needed") % (tree.cost(id) - rubble)


## Only the stats this node changes, each in plain words from data (D-077): the words, then
## "13  ->  16" under them, the new value brighter than the old and the unit written once.
func _show_stats(effects: Dictionary, stats: Dictionary, steps: int) -> void:
	for child: Node in _info_stats.get_children():
		_info_stats.remove_child(child)
		child.queue_free()
	var words: Dictionary = Content.section("stat_text")
	for stat: String in effects:
		var entry: Dictionary = words.get(stat, {})
		if entry.get("hidden", false):
			continue
		var now := Num.f(stats.get(stat, 0.0))
		var line := UiKit.label(
			tr("%s:") % tr(str(entry.get("line", stat))), UiKit.SIZE_BODY, UiKit.MUTED
		)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_stats.add_child(line)
		# The values under the words; the "now" column is one fixed width, so arrows line up.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_info_stats.add_child(row)
		var was := UiKit.label(_fmt(entry, now, steps == 0), UiKit.SIZE_BODY, UiKit.MUTED)
		was.custom_minimum_size = Vector2(NOW_WIDTH, 0)
		row.add_child(was)
		if steps > 0:
			var arrow := TextureRect.new()
			arrow.texture = UiKit.arrow()
			arrow.modulate = UiKit.GOOD
			arrow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			row.add_child(arrow)
			var after := _fmt(entry, now + Num.f(effects[stat]), true)
			row.add_child(UiKit.label(after, UiKit.SIZE_BODY, UiKit.TEXT))
	_info_stats.visible = _info_stats.get_child_count() > 0


## A stat's value as its data line formats it ("inv" shows 1 / value, a rate), with its unit.
func _fmt(entry: Dictionary, value: float, with_unit: bool) -> String:
	var fmt := str(entry.get("fmt", "%.1f"))
	var unit := tr(str(entry.get("unit", ""))) if with_unit else ""
	if fmt == "inv":
		return ("%.1f" % (1.0 / maxf(0.1, value))) + unit
	if fmt.contains("%d"):
		return (fmt % roundi(value)) + unit
	return (fmt % value) + unit


func _refresh() -> void:
	_show_rubble()
	for id: String in tree.order:
		node_button(id).show_state(tree, rubble)
	var stage := tree.stage()
	_specimen_label.text = (
		tr("SPECIMEN  %s   STAGE %d / %d") % [tr(str(species["name"])).to_upper(), stage, 3]
	)
	_area.show_specimen(KaijuModel.stage_for(stage))
	_area.queue_redraw()
	if _selected != "":
		_select(_selected)


## The counter counts down to the new biomass over fill_s (at once with the fx off or first time).
func _show_rubble() -> void:
	var fx: Dictionary = Content.section("tree")["skin"]["fx"]
	if _rubble_tween != null:
		_rubble_tween.kill()
	if _rubble_shown < 0 or fx["enabled"] != true or not is_inside_tree():
		_set_rubble_shown(rubble)
		return
	_rubble_tween = create_tween()
	_rubble_tween.tween_method(_set_rubble_shown, _rubble_shown, rubble, Num.f(fx["fill_s"]))


func _set_rubble_shown(value: int) -> void:
	_rubble_shown = value
	_rubble_label.text = tr("BIOMASS  %d") % value


## Pans the tree so a node sits in the middle of the view.
func show_node(id: String) -> void:
	_area.centre_on(id)


func node_button(id: String) -> UpgradeNode:
	return _area.buttons[id]
