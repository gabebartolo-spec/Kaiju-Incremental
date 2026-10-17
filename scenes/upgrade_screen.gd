class_name UpgradeScreen
extends Control
## The evolution tree between rampages. Spend rubble on nodes, see what each changes in play
## (the stat now -> after the next level), then start the next rampage. Nodes are laid out by
## their data `pos`; lines join prerequisites. The species' own branch sits on a band of its
## own, ending in its ultimate (D-040) as the capstone. Reads the tree; buying goes through it.

signal start_pressed
signal bought(id: String)
signal menu_pressed

const CELL := Vector2(172, 128)
## The species' own branch (docs/SPECIES.md) sits on this row, on a band of its own.
const BRANCH_ROW := 5
const COLUMNS := 8
const BRANCH_TINT_ALPHA := 0.18
## The tree's width: the last column's capstone and a small edge. At 1080p (100%) it fits
## beside the side panel at full size; at larger UI scales it shrinks to fit (never scrolls).
const AREA_WIDTH := CELL.x * (COLUMNS - 1) + UpgradeNode.CAPSTONE_SIZE.x + 4
## Stat, how it reads in play, format ("inv" shows 1/value per second).
const STAT_LINES: Array[Array] = [
	["hp", "Health", "%d"],
	["stomp_damage", "Stomp power", "%.0f"],
	["stomp_radius", "Stomp reach", "%.1f"],
	["stomp_interval", "Stomps / sec", "inv"],
	["speed", "Speed", "%.1f"],
	["armor", "Armour", "%.1f"],
	["run_seconds", "Rampage time", "%ds"],
	["ability_damage", "Signature power", "%.0f"],
	["ability_cooldown", "Signature recharge", "%.1fs"],
	["size", "Size", "%d"],
]
## Stats only some nodes change: shown in a node's details, not the summary.
const EXTRA_STATS: Array[Array] = [
	["regen", "Healing / sec", "%.1f"],
	["rubble_mult", "Rubble earned", "x%.2f"],
	["ability_range", "Signature reach", "%.1f"],
	["tail_damage", "Tail sweep power", "%.0f"],
	["tail_reach", "Tail reach", "%.1f"],
	["tail_floors", "Floors the tail cuts", "%d"],
	["momentum", "Momentum", "%.1f"],
	["beam_dps", "Atomic Beam damage / sec", "%.0f"],
	["glide_seconds", "Glide time", "%.1fs"],
	["climb", "Climbing", "%d"],
	["brood_count", "Young per clutch", "%d"],
	["limbs", "Free tentacles", "%d"],
	["squeeze", "Squeeze", "%.1f"],
	["throw_damage", "Throw damage", "%.0f"],
	["ink_dps", "Ink damage / sec", "%.0f"],
]

var tree: UpgradeTree
var rubble: int
var species: Dictionary
var base_stats: Dictionary
var _buttons: Dictionary = {}
var _rubble_label: Label
var _info_title: Label
var _info_role: Label
var _info_body: Label
var _info_status: Label
var _stats_label: Label
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
	var fit := Control.new()
	fit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(fit)
	var area := _build_tree_area()
	fit.add_child(area)
	fit.resized.connect(func() -> void: _fit_tree(fit, area))
	body.add_child(_build_side())
	_selected = tree.order[0]
	_refresh()


## Shrinks the whole tree (never grows it) so every node, the branch band and its capstone
## stay on screen at every UI scale (D-027: the 4K TV at 125%).
func _fit_tree(fit: Control, area: Control) -> void:
	var need := area.custom_minimum_size
	var k := minf(1.0, minf(fit.size.x / need.x, fit.size.y / need.y))
	area.scale = Vector2(k, k)


func _build_tree_area() -> Control:
	var area := _TreeLines.new()
	area.screen = self
	area.custom_minimum_size = Vector2(AREA_WIDTH, CELL.y * (BRANCH_ROW + 1) + 72)
	var band := ColorRect.new()
	var colors: Dictionary = species["colors"]
	band.color = Color(Color(str(colors["eye"])), BRANCH_TINT_ALPHA)
	band.position = Vector2(-8, BRANCH_ROW * CELL.y - 14)
	band.size = Vector2(AREA_WIDTH + 8, UpgradeNode.CAPSTONE_SIZE.y + 28)
	area.add_child(band)
	var branch := UiKit.label(
		(
			"%s BRANCH  -  only the %s can grow these"
			% [str(species["name"]).to_upper(), str(species["name"]).to_lower()]
		),
		UiKit.SIZE_SMALL,
		Color(str(colors["eye"])).lightened(0.3)
	)
	branch.position = Vector2(0, BRANCH_ROW * CELL.y + UpgradeNode.CAPSTONE_SIZE.y + 18)
	area.add_child(branch)
	for id: String in tree.order:
		var def: Dictionary = tree.defs[id]
		var pos: Array = def["pos"]
		var b := UpgradeNode.new(id, role_of(id))
		b.position = Vector2(Num.f(pos[0]) * CELL.x, Num.f(pos[1]) * CELL.y)
		if b.role == "ultimate":
			b.position -= (UpgradeNode.CAPSTONE_SIZE - UpgradeNode.SIZE) * 0.5
		b.pressed.connect(_on_node_pressed.bind(id))
		b.focus_entered.connect(_select.bind(id))
		b.mouse_entered.connect(_select.bind(id))
		area.add_child(b)
		_buttons[id] = b
	return area


func _build_side() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(420, 0)
	side.add_theme_constant_override("separation", 14)
	var info := UiKit.panel()
	side.add_child(info)
	var info_col := VBoxContainer.new()
	info.add_child(info_col)
	_info_title = UiKit.label("", UiKit.SIZE_HEAD, UiKit.TEXT)
	_info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_title)
	_info_role = UiKit.label("", UiKit.SIZE_SMALL, UiKit.WARN)
	info_col.add_child(_info_role)
	_info_body = UiKit.label("", UiKit.SIZE_BODY, UiKit.MUTED)
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_body)
	_info_status = UiKit.label("", UiKit.SIZE_BODY, UiKit.TEXT)
	_info_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_status)
	# The stats scroll when the screen is short (UI scale 125% on a TV), so RAMPAGE stays on screen.
	var stats_scroll := ScrollContainer.new()
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(stats_scroll)
	var stats_panel := UiKit.panel()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_scroll.add_child(stats_panel)
	_stats_label = UiKit.label("", UiKit.SIZE_SMALL, UiKit.TEXT)
	stats_panel.add_child(_stats_label)
	var go := UiKit.button("RAMPAGE  >", UiKit.SIZE_HEAD)
	go.custom_minimum_size = Vector2(0, 84)
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
		"branch": "%s BRANCH" % str(species["name"]).to_upper(),
		"evolve": "EVOLUTION",
		"ultimate": "ULTIMATE  -  %s BRANCH CAPSTONE" % str(species["name"]).to_upper(),
	}[role]
	var lines: Array[String] = [str(def["desc"])]
	var stats := UpgradeTree.run_stats(base_stats, species, tree)
	var effects: Dictionary = def.get("effects", {})
	var steps := 0 if tree.is_maxed(id) else 1
	for stat: String in effects:
		var now := Num.f(stats.get(stat, 0.0))
		var after := now + Num.f(effects[stat]) * steps
		lines.append(
			(
				"%s  %s"
				% [
					_stat_name(stat),
					_fmt(stat, now) + ("  ->  " + _fmt(stat, after) if steps else "")
				]
			)
		)
	if role == "evolve" and steps > 0:
		var stage := KaijuModel.stage_for(Num.i(stats.get("size", 1)) + 1)
		lines.append("Grows into the %s: towers one tier taller now fall to you" % stage)
	if role == "ultimate":
		lines.append("Press E / pad Y in a rampage; recharges in %ds" % roundi(_ultimate_cooldown))
	_info_body.text = "\n".join(lines)
	_info_status.text = _status_line(id)
	var b: UpgradeNode = _buttons[id]
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
	if tree.can_buy(id, rubble):
		return head + "Cost %d rubble  -  press to buy" % tree.cost(id)
	return head + "Cost %d rubble  -  %d more needed" % [tree.cost(id), tree.cost(id) - rubble]


func _stat_name(stat: String) -> String:
	for entry: Array in STAT_LINES + EXTRA_STATS:
		if entry[0] == stat:
			return str(entry[1])
	return stat.replace("_", " ").capitalize()


func _fmt(stat: String, value: float) -> String:
	var fmt := "%.1f"
	for entry: Array in STAT_LINES + EXTRA_STATS:
		if entry[0] == stat:
			fmt = str(entry[2])
	if fmt == "inv":
		return "%.1f" % (1.0 / maxf(0.1, value))
	if fmt.contains("%d"):
		return fmt % roundi(value)
	return fmt % value


func _refresh() -> void:
	_rubble_label.text = "RUBBLE  %d" % rubble
	for id: String in tree.order:
		var b: UpgradeNode = _buttons[id]
		b.show_state(tree, rubble)
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
		lines.append(
			"%s:  %s" % [str(entry[1]), _fmt(str(entry[0]), Num.f(stats.get(str(entry[0]), 0.0)))]
		)
	_stats_label.text = "\n".join(lines)
	if _selected != "":
		_select(_selected)


func node_button(id: String) -> UpgradeNode:
	return _buttons[id]


func node_centre(id: String) -> Vector2:
	var b: Button = _buttons[id]
	return b.position + b.size * 0.5


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
