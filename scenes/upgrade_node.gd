class_name UpgradeNode
extends Button
## One node of the evolution tree. Its look says at a glance what it is and whether you can
## have it: green and "BUY n" when affordable, the price dimmed when not (the side panel says how
## much is missing), a dimmed box when locked, gold when maxed; evolutions edged gold, the
## species' ultimate edged magenta and taller as its branch's capstone, with its button.

## Text size range: the largest that fits the node's width, never below FONT_MIN (at 4K and the
## largest UI scale FONT_MIN still clears the TV's 28 px cap-height bar).
const FONT_MAX := 22
const FONT_MIN := 18
const PAD := 2
## The thickest border each kind of node draws (focused): its text keeps clear of it.
const MAX_BORDER := {"plain": 5, "branch": 5, "evolve": 7, "ultimate": 8}
const FILL := {
	"maxed": Color("8a6d1f"), "buy": Color("2f6b2a"), "poor": UiKit.PANEL, "locked": Color("15191e")
}
const EDGE := {
	"maxed": UiKit.WARN, "buy": UiKit.GOOD, "poor": UiKit.PANEL_EDGE, "locked": UiKit.LOCKED
}
const ULTIMATE_EDGE := Color("ff3df0")
## The widest level-and-price line a node shows (prices from 10 000 up read "12k").
const WIDEST_STATUS := "0/5  BUY 8888"

var id: String
## "plain", "branch" (species branch), "evolve" (grows the kaiju) or "ultimate" (capstone).
var role := "plain"
var state := "locked"
var _name := ""


func _init(p_id: String, p_role: String, p_name: String) -> void:
	id = p_id
	role = p_role
	_name = p_name
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Sizes the node and picks the largest font at which every word of its name fits the width
## and all its lines (name, level and price, the ultimate's button) fit the height.
func place(at: Vector2, box: Vector2) -> void:
	var font := get_theme_font("font")
	var room := text_width(box.x)
	var pick := FONT_MIN
	for px: int in range(FONT_MAX, FONT_MIN - 1, -1):
		var name_lines := 1
		var line := ""
		var fits := font.get_string_size(WIDEST_STATUS, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= room
		for word: String in _name.split(" "):
			if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
				fits = false
			var joined := word if line == "" else line + " " + word
			if font.get_string_size(joined, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
				name_lines += 1
				line = word
			else:
				line = joined
		var lines := name_lines + (2 if role == "ultimate" else 1)
		if fits and lines * font.get_height(px) + 2.0 * PAD <= box.y:
			pick = px
			break
	add_theme_font_size_override("font_size", pick)
	position = at
	size = box


## The width the button lays its text out in, for a node `width` wide (its box margins and a
## little slack for the text server's rounding).
func text_width(width: float) -> float:
	return width - 2.0 * (PAD + Num.f(MAX_BORDER[role])) - 2.0


## A price as a node shows it: in full below 10 000, else in thousands ("32k").
static func short_price(price: int) -> String:
	return str(price) if price < 10000 else "%dk" % floori(price / 1000.0)


## Redraws the node from the tree and the rubble in hand.
func show_state(tree: UpgradeTree, rubble: int) -> void:
	if tree.is_maxed(id):
		state = "maxed"
	elif not tree.is_unlocked(id):
		state = "locked"
	else:
		state = "buy" if tree.can_buy(id, rubble) else "poor"
	var price := short_price(tree.cost(id))
	var status: String = {"maxed": "MAXED", "locked": "", "buy": "BUY " + price, "poor": price}[state]
	var tag := "\n[E / Y]" if role == "ultimate" else ""
	text = "%s\n%d/%d  %s%s" % [_name, tree.level(id), tree.max_level(id), status, tag]
	var fill: Color = FILL[state]
	var edge: Color = EDGE[state]
	var width := 3
	if role == "evolve" and state != "maxed":
		edge = UiKit.WARN if state != "locked" else edge
		width = 5
	elif role == "ultimate":
		edge = ULTIMATE_EDGE if state != "locked" else ULTIMATE_EDGE.darkened(0.5)
		width = 6
	for look: String in ["normal", "hover", "focus", "pressed"]:
		var box_fill := fill
		var box_edge := edge
		var box_width := width
		if look != "normal":
			box_edge = Color.WHITE
			box_fill = fill.darkened(0.2) if look == "pressed" else fill.lightened(0.15)
			box_width = width + (2 if look == "focus" else 0)
		var style := UiKit.box(box_fill, box_edge, box_width, 8)
		# The border is drawn inside the box: keep the text clear of the thickest one.
		style.set_content_margin_all(PAD + Num.f(MAX_BORDER[role]))
		add_theme_stylebox_override(look, style)
	# Locked and unaffordable read as dimmed, but stay well above 4.5:1 on their fills.
	var font := UiKit.TEXT if state in ["buy", "maxed"] else UiKit.MUTED.lightened(0.25)
	for key: String in ["font_color", "font_hover_color", "font_focus_color"]:
		add_theme_color_override(key, font)
