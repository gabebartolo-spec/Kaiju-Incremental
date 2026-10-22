class_name UpgradeScreen
extends Control
## The evolution tree between rampages. Spend rubble on nodes, see what each changes in play
## (each stat now, an arrow, after the next level), then start the next rampage. TreeArea lays
## the nodes out by their data `pos` to fill the screen; the species' own branch sits on a band
## of its own, ending in its ultimate (D-040) as the capstone. Reads the tree; buying goes
## through it.

signal start_pressed
signal bought(id: String)
signal menu_pressed

## The stat rows' "now" column: one width for every row, so the arrows sit in one column.
const NOW_WIDTH := 64
const NBSP := " "
var tree: UpgradeTree
var rubble: int
var species: Dictionary
var base_stats: Dictionary
## The node details panel beside the tree: one fixed width for every node (b2-23, tuning "ui"
## tooltip_width), so picking a long-named node never reshapes the screen.
var side_panel: Control
var _area: TreeArea
var _rubble_label: Label
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

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	col.add_child(header)
	var title := UiKit.label("EVOLUTION TREE", 48, UiKit.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_rubble_label = UiKit.label("", UiKit.SIZE_HEAD, UiKit.WARN)
	header.add_child(_rubble_label)
	var menu := UiKit.button("MENU", UiKit.SIZE_BODY, UiKit.PANEL_EDGE)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	header.add_child(menu)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	col.add_child(body)
	_area = TreeArea.new()
	var roles: Dictionary = {}
	for id: String in tree.order:
		roles[id] = role_of(id)
	_area.setup(tree, species, roles)
	_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area.node_pressed.connect(_on_node_pressed)
	_area.node_selected.connect(_select)
	body.add_child(_area)
	body.add_child(_build_side())
	_selected = tree.order[0]
	_refresh()


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
	_info_title = UiKit.label("", UiKit.SIZE_HEAD, UiKit.TEXT)
	_info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_title)
	_info_role = UiKit.label("", UiKit.SIZE_BODY, UiKit.WARN)
	_info_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_role)
	_info_body = UiKit.rich(UiKit.SIZE_BODY, UiKit.MUTED.lightened(0.2))
	info_col.add_child(_info_body)
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
	var go := UiKit.button("RAMPAGE  >", UiKit.SIZE_HEAD)
	go.custom_minimum_size = Vector2(0, 80)
	go.pressed.connect(func() -> void: start_pressed.emit())
	side.add_child(go)
	go.grab_focus.call_deferred()
	return side


## "ultimate": a species node nothing else needs (its branch's capstone); "evolve": grows the
## kaiju a size; "branch": the rest of the species branch; "plain": the shared tree.
func role_of(id: String) -> String:
	var def: Dictionary = tree.defs[id]
	var effects: Dictionary = def.get("effects", {})
	if effects.has("size"):
		return "evolve"
	if str(def.get("species", "")) == "":
		return "plain"
	for other: String in tree.order:
		var other_def: Dictionary = tree.defs[other]
		var requires: Array = other_def.get("requires", [])
		if requires.has(id):
			return "branch"
	return "ultimate"


func _on_node_pressed(id: String) -> void:
	var price := tree.buy(id, rubble)
	Sfx.ui("ui_confirm" if price > 0 else "ui_deny")
	if price > 0:
		rubble -= price
		bought.emit(id)
		get_node("/root/EventBus").emit_signal("upgrade_bought", id)
	_select(id)
	_refresh()


func _select(id: String) -> void:
	_selected = id
	var def: Dictionary = tree.defs[id]
	_info_title.text = str(def["name"])
	var role := role_of(id)
	_info_role.text = {
		"plain": "",
		"branch": "",
		"evolve": "EVOLUTION",
		"ultimate": "ULTIMATE",
	}[role]
	_info_body.clear()
	_info_body.append_text(UpgradeTree.desc_for(def, str(species["id"])))
	var stats := UpgradeTree.run_stats(base_stats, species, tree)
	var steps := 0 if tree.is_maxed(id) else 1
	if role == "evolve" and steps > 0:
		var stage := KaijuModel.stage_for(Num.i(stats.get("size", 1)) + 1)
		_info_body.append_text("\nGrows into the %s." % stage)
		# No-break spaces keep "fall to you." together when the line wraps (no orphan "you").
		_info_body.append_text("\nTowers one tier taller now fall%sto%syou." % [NBSP, NBSP])
	if role == "ultimate":
		_info_body.append_text(
			"\nPress E / pad Y in a rampage; recharges in %ds." % roundi(_ultimate_cooldown)
		)
	_show_stats(UpgradeTree.effects_for(def, str(species["id"])), stats, steps)
	_info_status.text = _status_line(id)
	var b := node_button(id)
	var tint: Color = {"buy": UiKit.GOOD, "poor": UiKit.BAD, "maxed": UiKit.WARN}.get(
		b.state, UiKit.MUTED
	)
	_info_status.add_theme_color_override("font_color", tint)


func _status_line(id: String) -> String:
	var head := "Level %d / %d   " % [tree.level(id), tree.max_level(id)]
	if tree.is_maxed(id):
		return head + "MAXED"
	if not tree.is_unlocked(id):
		var def: Dictionary = tree.defs[id]
		var names: Array[String] = []
		var requires: Array = def.get("requires", [])
		for req: String in requires:
			if tree.level(req) < 1:
				var req_def: Dictionary = tree.defs[req]
				names.append(str(req_def["name"]))
		return head + "Needs: " + ", ".join(names)
	# Three short lines, so no wrap ever leaves a dash or a lone word at a line end.
	var nl := String.chr(10)
	var have := ("Cost %d" + nl + "You have %d biomass" + nl) % [tree.cost(id), rubble]
	if tree.can_buy(id, rubble):
		return head + have + "Enter / pad A to buy"
	return head + have + "%d more needed" % (tree.cost(id) - rubble)


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
		var line := UiKit.label(str(entry.get("line", stat)) + ":", UiKit.SIZE_BODY, UiKit.MUTED)
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
	var unit := str(entry.get("unit", "")) if with_unit else ""
	if fmt == "inv":
		return ("%.1f" % (1.0 / maxf(0.1, value))) + unit
	if fmt.contains("%d"):
		return (fmt % roundi(value)) + unit
	return (fmt % value) + unit


func _refresh() -> void:
	_rubble_label.text = "BIOMASS  %d" % rubble
	for id: String in tree.order:
		node_button(id).show_state(tree, rubble)
	_area.queue_redraw()
	if _selected != "":
		_select(_selected)


func node_button(id: String) -> UpgradeNode:
	return _area.buttons[id]
