class_name ControlsCard
extends PanelContainer
## The controls, keyboard and pad, on one broadcast card (b2-10): shown once at the start of
## the first rampage (RampageHud) and from Settings > CONTROLS. Never on the HUD otherwise.

## The card's width (px at 1080p): tuning "ui" controls_card width.
var width: float


func _init() -> void:
	var cfg: Dictionary = UiKit.ui()["controls_card"]
	width = Num.f(cfg["width"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(width, 0)
	add_theme_stylebox_override("panel", UiKit.panel_box())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	col.add_child(UiKit.header("CONTROLS", UiKit.SIZE_HEAD))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for heading: String in ["", "KEYBOARD", "PAD"]:
		grid.add_child(UiKit.label(heading, UiKit.SIZE_BODY, UiKit.WARN))
	for entry: Array in rows():
		var action := UiKit.label(str(entry[0]), UiKit.SIZE_BODY, UiKit.TEXT)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(action)
		grid.add_child(UiKit.label(str(entry[1]), UiKit.SIZE_BODY, UiKit.MUTED))
		grid.add_child(UiKit.label(str(entry[2]), UiKit.SIZE_BODY, UiKit.MUTED))


## PlayerSettings.CONTROLS without the rows of species the build does not offer (a row tied to
## a species is its 4th entry).
static func rows() -> Array[Array]:
	var out: Array[Array] = []
	var controls: Array[Array] = PlayerSettings.CONTROLS
	for entry: Array in controls:
		if entry.size() > 3 and not Demo.allows(str(entry[3])):
			continue
		out.append(entry)
	return out
