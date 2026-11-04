class_name ThreatReadout
extends PanelContainer
## The globe's Threat Level plate (D-422, D-462; director 2026-11-04): a thin bordered plate like
## the mission panel's, label in hazard yellow, the value coloured by how near the cap it is
## (calm at 0, alarm red toward 100; 99 and 100 are the same red on purpose: the level holds at 99
## until the capital opens, so only the number changes) and the cap it counts to. Its size, edge and
## colour ramp are data (tuning ui "threat_readout"). Sits at the title-safe corner
## (UiKit.safe_margin).

## The palette names the ramp may use (UiKit colours).
const PALETTE := {
	"GOOD": UiKit.GOOD,
	"WARN": UiKit.WARN,
	"ORANGE": UiKit.ORANGE,
	"ALERT": UiKit.ALERT,
	"TEXT": UiKit.TEXT,
	"ACCENT": UiKit.ACCENT,
}

var _value: Label
## The border, drawn over the text so no glyph or shadow ever breaks it.
var _edge: Panel


func _init() -> void:
	var cfg := config()
	var box := UiKit.box(UiKit.PANEL, UiKit.PANEL, 0)
	box.set_content_margin_all(0)
	box.content_margin_left = Num.f(cfg["pad"])
	box.content_margin_right = Num.f(cfg["pad"])
	add_theme_stylebox_override("panel", box)
	custom_minimum_size.y = Num.f(cfg["height"])
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = UiKit.safe_margin()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Num.i(cfg["gap"]))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	var size := Num.i(cfg["font"])
	row.add_child(_plain(UiKit.label(tr("THREAT"), size, UiKit.ACCENT)))
	_value = _plain(UiKit.label("", size))
	# Fixed to the widest reading so the plate's edge never jumps as the number changes.
	var font := _value.get_theme_font("font")
	var widest := font.get_string_size("100%", HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	_value.custom_minimum_size.x = ceilf(widest.x)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_value)
	row.add_child(_plain(UiKit.label("/ %d%%" % roundi(Campaign.THREAT_FULL), size, UiKit.MUTED)))
	_edge = Panel.new()
	_edge.top_level = true
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := UiKit.box(Color(0, 0, 0, 0), UiKit.ACCENT, Num.i(cfg["border"]))
	ring.draw_center = false
	_edge.add_theme_stylebox_override("panel", ring)
	add_child(_edge)
	set_notify_transform(true)
	show_level(0.0)


func _notification(what: int) -> void:
	var moved := (
		what == NOTIFICATION_RESIZED
		or what == NOTIFICATION_TRANSFORM_CHANGED
		or what == NOTIFICATION_ENTER_TREE
		or what == NOTIFICATION_VISIBILITY_CHANGED
	)
	if _edge != null and moved:
		_edge.global_position = global_position
		_edge.size = size
		_edge.visible = visible


## The plate's text sits flat on its plate: no drop shadow to spill past the border.
func _plain(l: Label) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l


## The value as shown, e.g. "22%".
func value_text() -> String:
	return _value.text


## The value's colour now.
func value_colour() -> Color:
	return _value.get_theme_color("font_color")


## The plate's data (tuning ui "threat_readout").
static func config() -> Dictionary:
	return UiKit.ui()["threat_readout"]


## The border's colour (the overlay's ring).
func edge_colour() -> Color:
	return (_edge.get_theme_stylebox("panel") as StyleBoxFlat).border_color


## Shows the Threat Level as a whole percent, truncated: 100 reads only once the capital is open
## (D-422 holds it at 99 at most until then), in the colour for that level.
func show_level(threat: float) -> void:
	_value.text = "%d%%" % floori(threat)
	_value.add_theme_color_override("font_color", colour_for(threat))


## The value's colour at a Threat Level: the ramp's stops blended, clamped at the ends.
static func colour_for(threat: float) -> Color:
	var ramp: Array = config()["ramp"]
	var first: Array = ramp[0]
	var out: Color = PALETTE[str(first[1])]
	if threat <= Num.f(first[0]):
		return out
	for n: int in range(1, ramp.size()):
		var stop: Array = ramp[n]
		var prev: Array = ramp[n - 1]
		var lo := Num.f(prev[0])
		var hi := Num.f(stop[0])
		var colour: Color = PALETTE[str(stop[1])]
		if threat >= hi:
			out = colour
			continue
		var from: Color = PALETTE[str(prev[1])]
		return from.lerp(colour, (threat - lo) / (hi - lo))
	return out
