class_name MissionPanel
extends PanelContainer
## The globe's mission panel (Overworld plan row G5; director 2026-11-01: "Compact card", D-432): a
## card sized to its text, centred down the right margin, so the continent the camera flew to stays
## in view. It names the continent and its growth stage in game words, the Threat its
## conquest adds and the three bonuses it offers (D-421), and LAUNCH starts its mission.
## The city preview and landmarks come with plan rows C1..C5 (director: "Leave them out").

signal launched(id: String)

const GAP := 16  # px between the panel's lines
const PERCENT := 100.0

## The continent shown ("" while hidden).
var id := ""

var _lines: VBoxContainer
var _launch: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_box())
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_right = -UiKit.safe_margin().x
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	add_child(column)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", GAP)
	column.add_child(_lines)
	_launch = UiKit.button("LAUNCH", UiKit.SIZE_HEAD)
	_launch.pressed.connect(func() -> void: launched.emit(id))
	column.add_child(_launch)
	visible = false


## Shows one continent's mission (a Content.continents() row). `after`: the Threat Level its
## conquest would leave, shown beside what it adds so the line reads in the corner readout's own
## units (D-462); negative leaves it out.
func show_for(def: Dictionary, after := -1.0) -> void:
	id = str(def["id"])
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	_lines.add_child(UiKit.header(tr(str(def["name"])).to_upper(), UiKit.SIZE_HEAD))
	var stage: int = def["stage"]
	_lines.add_child(UiKit.label(tr(Content.stage_word(stage)), UiKit.SIZE_BODY, UiKit.MUTED))
	var threat: float = def["threat"]
	var line := tr("Threat +%d%%") % roundi(threat)
	if after >= 0.0:
		line += tr(" (to %d%%)") % floori(after)
	var tint := ThreatReadout.colour_for(after) if after >= 0.0 else UiKit.ALERT
	_lines.add_child(UiKit.label(line, UiKit.SIZE_BODY, tint))
	var offered: Array = def["bonuses"]
	for pick: Dictionary in offered:
		_lines.add_child(UiKit.label(bonus_text(pick, self), UiKit.SIZE_BODY, UiKit.TEXT))
	visible = true
	reset_size.call_deferred()  # shrink to this continent's lines


func hide_panel() -> void:
	id = ""
	visible = false


func launch_button() -> Button:
	return _launch


## A bonus in plain words from data (D-077, D-432): "Moves 10% faster", the percent inside each
## stat's phrase (Content.bonus_line); a bonus the director has not picked yet (no scale) says so.
static func bonus_text(pick: Dictionary, node: Node) -> String:
	var scale: Dictionary = pick["scale"]
	var parts: PackedStringArray = []
	for stat: String in scale:
		var line: String = Content.bonus_line(stat)
		var frac: float = scale[stat]
		if line != "":
			parts.append(node.tr(line) % roundi(frac * PERCENT))
	if parts.is_empty():
		return node.tr("Bonus to be designed")
	return ", ".join(parts)
