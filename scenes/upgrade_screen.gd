class_name UpgradeScreen
extends Control
## The evolution tree between rampages. Spend rubble on nodes, see what each changes, then
## start the next rampage. Nodes are laid out by their data `pos`; lines join prerequisites.

signal start_pressed
signal bought(id: String)

const CELL := Vector2(172, 150)
const NODE_SIZE := Vector2(160, 116)
const STAT_LINES: Array[Array] = [
	["Health", "hp", "%d"],
	["Stomp power", "stomp_damage", "%.0f"],
	["Stomp reach", "stomp_radius", "%.1f"],
	["Stomps / sec", "stomp_interval", "inv"],
	["Speed", "speed", "%.1f"],
	["Armour", "armor", "%.1f"],
	["Rampage time", "run_seconds", "%ds"],
	["Signature power", "ability_damage", "%.0f"],
	["Signature recharge", "ability_cooldown", "%.1fs"],
	["Size", "size", "%d"]
]

var tree: UpgradeTree
var rubble: int
var species: Dictionary
var base_stats: Dictionary
var _buttons: Dictionary = {}
var _rubble_label: Label
var _info_title: Label
var _info_body: Label
var _stats_label: Label
var _selected := ""


func setup(p_tree: UpgradeTree, p_rubble: int, p_species: Dictionary, p_base: Dictionary) -> void:
	tree = p_tree
	rubble = p_rubble
	species = p_species
	base_stats = p_base


func _ready() -> void:
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
	col.add_child(header)
	var title := UiKit.label("EVOLUTION TREE", 48, UiKit.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_rubble_label = UiKit.label("", UiKit.SIZE_HEAD, UiKit.WARN)
	header.add_child(_rubble_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	col.add_child(body)

	var area := _TreeLines.new()
	area.screen = self
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size = Vector2(CELL.x * 8, CELL.y * 5)
	body.add_child(area)
	for id: String in tree.order:
		var def: Dictionary = tree.defs[id]
		var pos: Array = def["pos"]
		var b := Button.new()
		b.position = Vector2(Num.f(pos[0]) * CELL.x, Num.f(pos[1]) * CELL.y)
		b.size = NODE_SIZE
		b.add_theme_font_size_override("font_size", UiKit.SIZE_SMALL)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_node_pressed.bind(id))
		b.focus_entered.connect(_select.bind(id))
		b.mouse_entered.connect(_select.bind(id))
		area.add_child(b)
		_buttons[id] = b

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(380, 0)
	side.add_theme_constant_override("separation", 14)
	body.add_child(side)
	var info := UiKit.panel()
	info.custom_minimum_size = Vector2(0, 230)
	side.add_child(info)
	var info_col := VBoxContainer.new()
	info.add_child(info_col)
	_info_title = UiKit.label("", UiKit.SIZE_HEAD, UiKit.TEXT)
	_info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_title)
	_info_body = UiKit.label("", UiKit.SIZE_BODY, UiKit.MUTED)
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_body)
	var stats_panel := UiKit.panel()
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(stats_panel)
	_stats_label = UiKit.label("", UiKit.SIZE_SMALL, UiKit.TEXT)
	stats_panel.add_child(_stats_label)
	var go := UiKit.button("RAMPAGE  >", UiKit.SIZE_HEAD)
	go.custom_minimum_size = Vector2(0, 84)
	go.pressed.connect(func() -> void: start_pressed.emit())
	side.add_child(go)
	go.grab_focus.call_deferred()
	_selected = tree.order[0]
	_refresh()


func _on_node_pressed(id: String) -> void:
	var price := tree.buy(id, rubble)
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
	var lines: Array[String] = [str(def["desc"])]
	var effects: Dictionary = def.get("effects", {})
	for stat: String in effects:
		var per := Num.f(effects[stat])
		lines.append(
			(
				"%s%s %s per level"
				% ["+" if per >= 0.0 else "", str(snappedf(per, 0.01)), _stat_name(stat)]
			)
		)
	lines.append("Level %d / %d" % [tree.level(id), tree.max_level(id)])
	if tree.is_maxed(id):
		lines.append("MAXED")
	elif not tree.is_unlocked(id):
		var names: Array[String] = []
		var requires: Array = def.get("requires", [])
		for req: String in requires:
			var req_def: Dictionary = tree.defs[req]
			names.append(str(req_def["name"]))
		lines.append("Needs: " + ", ".join(names))
	else:
		lines.append("Cost: %d rubble" % tree.cost(id))
	_info_body.text = "\n".join(lines)


func _stat_name(stat: String) -> String:
	for entry: Array in STAT_LINES:
		if entry[1] == stat:
			return str(entry[0]).to_lower()
	return stat.replace("_", " ")


func _refresh() -> void:
	_rubble_label.text = "RUBBLE  %d" % rubble
	for id: String in tree.order:
		var b: Button = _buttons[id]
		var def: Dictionary = tree.defs[id]
		var state := _state(id)
		var cost_text := (
			"MAX"
			if tree.is_maxed(id)
			else ("%d" % tree.cost(id) if tree.is_unlocked(id) else "locked")
		)
		b.text = (
			"%s\n%d/%d   %s" % [str(def["name"]), tree.level(id), tree.max_level(id), cost_text]
		)
		var fill: Color = {
			"maxed": Color("8a6d1f"),
			"buy": Color("2f6b2a"),
			"poor": UiKit.PANEL,
			"locked": Color("15191e")
		}[state]
		var edge: Color = {
			"maxed": UiKit.WARN, "buy": UiKit.GOOD, "poor": UiKit.PANEL_EDGE, "locked": UiKit.LOCKED
		}[state]
		b.add_theme_stylebox_override("normal", UiKit.box(fill, edge, 3, 8))
		b.add_theme_stylebox_override("hover", UiKit.box(fill.lightened(0.15), Color.WHITE, 3, 8))
		b.add_theme_stylebox_override("focus", UiKit.box(fill.lightened(0.15), Color.WHITE, 5, 8))
		b.add_theme_stylebox_override("pressed", UiKit.box(fill.darkened(0.2), Color.WHITE, 3, 8))
		b.add_theme_color_override(
			"font_color", UiKit.LOCKED.lightened(0.3) if state == "locked" else UiKit.TEXT
		)
	var stats := UpgradeTree.run_stats(base_stats, species, tree)
	var lines: Array[String] = [
		(
			"%s  -  evolution %d%%"
			% [
				str(species["name"]).to_upper(),
				roundi(100.0 * tree.levels_owned() / maxf(1.0, tree.levels_total()))
			]
		)
	]
	for entry: Array in STAT_LINES:
		var value := Num.f(stats.get(str(entry[1]), 0.0))
		var fmt := str(entry[2])
		var shown := (
			"%.1f" % (1.0 / maxf(0.1, value))
			if fmt == "inv"
			else fmt % (Num.i(value) if fmt.contains("%d") else value)
		)
		lines.append("%s:  %s" % [str(entry[0]), shown])
	_stats_label.text = "\n".join(lines)
	if _selected != "":
		_select(_selected)


func _state(id: String) -> String:
	if tree.is_maxed(id):
		return "maxed"
	if not tree.is_unlocked(id):
		return "locked"
	return "buy" if tree.can_buy(id, rubble) else "poor"


func node_centre(id: String) -> Vector2:
	var b: Button = _buttons[id]
	return b.position + NODE_SIZE * 0.5


## Draws the prerequisite lines under the node buttons.
class _TreeLines:
	extends Control
	var screen: UpgradeScreen

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for id: String in screen.tree.order:
			var def: Dictionary = screen.tree.defs[id]
			var requires: Array = def.get("requires", [])
			for req: String in requires:
				var owned := screen.tree.level(req) > 0
				draw_line(
					screen.node_centre(req),
					screen.node_centre(id),
					UiKit.GOOD if owned else UiKit.LOCKED,
					4.0,
					true
				)
