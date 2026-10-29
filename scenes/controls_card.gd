class_name ControlsCard
extends PanelContainer
## The controls, keyboard and pad, on one broadcast card (b2-10): shown once at the start of
## the first rampage (RampageHud). Settings > CONTROLS lists and rebinds them
## (ControlsMenu). Never on the HUD otherwise.

## The first-run card lists only these (the full list stays in Settings > CONTROLS).
const FIRST_RUN: Array[String] = ["Move", "Signature attack", "Leap"]
## Extra room under the full controls list (px at 1080p).
const BOTTOM_PAD := 20

## The card's width (px at 1080p): tuning "ui" controls_card width.
var width: float
## True for the short first-run card.
var compact: bool


func _init(p_compact: bool = false) -> void:
	compact = p_compact
	var cfg: Dictionary = UiKit.ui()["controls_card"]
	width = Num.f(cfg["width"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(Num.f(cfg["first_run_width"]) if compact else width, 0)
	add_theme_stylebox_override("panel", UiKit.panel_box())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	col.add_child(UiKit.header(tr("CONTROLS"), UiKit.SIZE_HEAD))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for heading: String in ["", tr("KEYBOARD"), tr("PAD")]:
		grid.add_child(UiKit.label(heading, UiKit.SIZE_BODY, UiKit.WARN))
	for entry: Array in rows(compact):
		var action := UiKit.label(KeyBinds.shown(str(entry[0])), UiKit.SIZE_BODY, UiKit.TEXT)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(action)
		grid.add_child(UiKit.label(KeyBinds.shown(str(entry[1])), UiKit.SIZE_BODY, UiKit.MUTED))
		grid.add_child(UiKit.label(KeyBinds.shown(str(entry[2])), UiKit.SIZE_BODY, UiKit.MUTED))
	if not compact:
		var tail := Control.new()
		tail.custom_minimum_size = Vector2(0, BOTTOM_PAD)
		tail.name = "Tail"
		col.add_child(tail)
	if compact:
		var prompt := UiKit.label(tr("PRESS ANY KEY"), UiKit.SIZE_BODY, UiKit.ACCENT)
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(prompt)


## PlayerSettings.CONTROLS without the rows of species the build does not offer (a row tied to
## a species is its 4th entry); `first_run` keeps only the FIRST_RUN rows.
static func rows(first_run: bool = false) -> Array[Array]:
	var out: Array[Array] = []
	var controls: Array[Array] = PlayerSettings.CONTROLS
	for entry: Array in controls:
		if entry.size() > 3 and not Demo.allows(str(entry[3])):
			continue
		if first_run and not FIRST_RUN.has(str(entry[0])):
			continue
		out.append(KeyBinds.row_text(entry))  # the player's own keys where rebound (D-259)
	return out
