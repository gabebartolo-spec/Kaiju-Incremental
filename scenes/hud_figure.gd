class_name HudFigure
extends RefCounted
## A HUD figure's measures (moved out of RampageHud for its 400-line cap).


## How far an outlined number of font `size` drawn in `label` (null: the fallback font) has its
## visible bottom (outline included) above its box's bottom (px).
static func gap(size: int, label: Label) -> float:
	var font := ThemeDB.fallback_font
	var face := UiKit.font_for(size)
	if face != null:
		font = face
	else:
		var themed := label.get_theme_font("font") if label != null else null
		font = themed if themed != null else ThemeDB.fallback_font
	return font.get_descent(size) - UiKit.outline_px(size)
