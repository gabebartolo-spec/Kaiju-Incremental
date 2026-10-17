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

## The side panel's width: the details, the stats and RAMPAGE, all without scrolling.
const SIDE_WIDTH := 330
const NBSP := " "
## Stat, how it reads in play, format ("inv" shows 1/value per second), short name for the
## two-column summary.
const STAT_LINES: Array[Array] = [
	["hp", "Health", "%d", "Health"],
	["stomp_damage", "Stomp power", "%.0f", "Stomp"],
	["stomp_radius", "Stomp reach", "%.1f", "Reach"],
	["stomp_interval", "Stomps / sec", "inv", "Stomps/s"],
	["speed", "Speed", "%.1f", "Speed"],
	["armor", "Armour", "%.1f", "Armour"],
	["run_seconds", "Rampage time", "%ds", "Time"],
	["ability_damage", "Signature power", "%.0f", "Signature"],
	["ability_cooldown", "Signature recharge", "%.1fs", "Recharge"],
	["size", "Size", "%d", "Size"],
]
## Stats only some nodes change: shown in a node's details, not the summary.
const EXTRA_STATS: Array[Array] = [
	["regen", "Healing / sec", "%.1f"],
	["rubble_mult", "Biomass earned", "x%.2f"],
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
var _area: TreeArea
var _rubble_label: Label
var _info_title: Label
var _info_role: Label
var _info_body: RichTextLabel
var _info_status: Label
var _stats_title: Label
var _stats_grid: GridContainer
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
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	side.add_theme_constant_override("separation", 12)
	var info := UiKit.panel()
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(info)
	var info_col := VBoxContainer.new()
	info.add_child(info_col)
	_info_title = UiKit.label("", UiKit.SIZE_HEAD, UiKit.TEXT)
	_info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_title)
	_info_role = UiKit.label("", UiKit.SIZE_SMALL, UiKit.WARN)
	info_col.add_child(_info_role)
	_info_body = UiKit.rich(UiKit.SIZE_SMALL, UiKit.MUTED.lightened(0.2))
	info_col.add_child(_info_body)
	_info_status = UiKit.label("", UiKit.SIZE_SMALL, UiKit.TEXT)
	_info_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_col.add_child(_info_status)
	var stats_panel := UiKit.panel()
	side.add_child(stats_panel)
	var stats_col := VBoxContainer.new()
	stats_panel.add_child(stats_col)
	_stats_title = UiKit.label("", UiKit.SIZE_SMALL, UiKit.WARN)
	stats_col.add_child(_stats_title)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 12)
	stats_col.add_child(_stats_grid)
	for entry: Array in STAT_LINES:
		_stats_grid.add_child(UiKit.label(str(entry[3]), UiKit.SIZE_SMALL, UiKit.MUTED))
		var value := UiKit.label("", UiKit.SIZE_SMALL, UiKit.TEXT)
		value.name = str(entry[0])
		_stats_grid.add_child(value)
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
	_info_body.clear()
	_info_body.append_text(str(def["desc"]))
	var stats := UpgradeTree.run_stats(base_stats, species, tree)
	var effects: Dictionary = def.get("effects", {})
	var steps := 0 if tree.is_maxed(id) else 1
	for stat: String in effects:
		var now := Num.f(stats.get(stat, 0.0))
		_info_body.append_text("\n%s  %s" % [_stat_name(stat), _fmt(stat, now)])
		if steps > 0:
			_info_body.append_text("  ")
			_info_body.add_image(UiKit.arrow(), UiKit.SIZE_SMALL, 0, UiKit.GOOD)
			_info_body.append_text("  " + _fmt(stat, now + Num.f(effects[stat])))
	if role == "evolve" and steps > 0:
		var stage := KaijuModel.stage_for(Num.i(stats.get("size", 1)) + 1)
		_info_body.append_text("\nGrows into the %s." % stage)
		# No-break spaces keep "fall to you." together when the line wraps (no orphan "you").
		_info_body.append_text("\nTowers one tier taller now fall%sto%syou." % [NBSP, NBSP])
	if role == "ultimate":
		_info_body.append_text(
			"\nPress E / pad Y in a rampage; recharges in %ds." % roundi(_ultimate_cooldown)
		)
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
	if tree.can_buy(id, rubble):
		return head + "Cost %d biomass  -  press%sto%sbuy" % [tree.cost(id), NBSP, NBSP]
	return head + "Cost %d biomass  -  %d more needed" % [tree.cost(id), tree.cost(id) - rubble]


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
	_rubble_label.text = "BIOMASS  %d" % rubble
	for id: String in tree.order:
		node_button(id).show_state(tree, rubble)
	_area.queue_redraw()
	var stats := UpgradeTree.run_stats(base_stats, species, tree)
	_stats_title.text = (
		"%s  -  evolution %d%%"
		% [
			str(species["name"]).to_upper(),
			roundi(100.0 * tree.levels_owned() / maxf(1.0, tree.levels_total()))
		]
	)
	for entry: Array in STAT_LINES:
		var value: Label = _stats_grid.get_node(str(entry[0]))
		value.text = _fmt(str(entry[0]), Num.f(stats.get(str(entry[0]), 0.0)))
	if _selected != "":
		_select(_selected)


func node_button(id: String) -> UpgradeNode:
	return _area.buttons[id]
