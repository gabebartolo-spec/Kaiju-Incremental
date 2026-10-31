class_name MissionPanel
extends PanelContainer
## The globe's mission panel (Overworld plan row G5, director 2026-11-01: "Right side column"): a
## full-height card down the right third of the screen, so the continent the camera flew to stays
## in view on the left. It names the continent and its growth stage in game words, the Threat its
## conquest adds and the three bonuses it offers (WIN ONE:, D-421), and LAUNCH starts its mission.
## The city preview and landmarks come with plan rows C1..C5 (director: "Leave them out").

signal launched(id: String)

const WIDTH := 1.0 / 3.0  # of the screen, from the right edge
const GAP := 16  # px between the panel's lines
const PERCENT := 100.0

## The continent shown ("" while hidden).
var id := ""

var _lines: VBoxContainer
var _launch: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_box())
	anchor_left = 1.0 - WIDTH
	anchor_right = 1.0
	anchor_bottom = 1.0
	var safe := UiKit.safe_margin()
	offset_top = safe.y
	offset_right = -safe.x
	offset_bottom = -safe.y
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	add_child(column)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", GAP)
	_lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_lines)
	_launch = UiKit.button("LAUNCH", UiKit.SIZE_HEAD)
	_launch.pressed.connect(func() -> void: launched.emit(id))
	column.add_child(_launch)
	visible = false


## Shows one continent's mission (a Content.continents() row).
func show_for(def: Dictionary) -> void:
	id = str(def["id"])
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	_lines.add_child(UiKit.header(tr(str(def["name"])).to_upper(), UiKit.SIZE_HEAD))
	var stage: int = def["stage"]
	_lines.add_child(UiKit.label(tr(Content.stage_word(stage)), UiKit.SIZE_BODY, UiKit.MUTED))
	var threat: float = def["threat"]
	_lines.add_child(UiKit.label(tr("Threat +%d%%") % roundi(threat), UiKit.SIZE_BODY, UiKit.ALERT))
	_lines.add_child(UiKit.label(tr("WIN ONE:"), UiKit.SIZE_BODY, UiKit.ACCENT))
	var offered: Array = def["bonuses"]
	for pick: Dictionary in offered:
		var line := UiKit.label(bonus_text(pick, self), UiKit.SIZE_BODY, UiKit.TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lines.add_child(line)
	visible = true


func hide_panel() -> void:
	id = ""
	visible = false


func launch_button() -> Button:
	return _launch


## A bonus in plain words from data (D-077): "+15% Stomps hit harder", one line per stat it
## scales; a bonus the director has not picked yet (no scale) says so.
static func bonus_text(pick: Dictionary, node: Node) -> String:
	var words: Dictionary = Content.section("stat_text")
	var scale: Dictionary = pick["scale"]
	var parts: PackedStringArray = []
	for stat: String in scale:
		var entry: Dictionary = words.get(stat, {})
		var frac: float = scale[stat]
		parts.append("+%d%% %s" % [roundi(frac * PERCENT), node.tr(str(entry.get("line", stat)))])
	if parts.is_empty():
		return node.tr("Bonus to be designed")
	return ", ".join(parts)
