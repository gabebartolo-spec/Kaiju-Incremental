class_name UpgradeNode
extends Button
## One node of the evolution tree. Its look says at a glance what it is and whether you can
## have it: green and "BUY n" when affordable, how much rubble is missing when not, locked or
## maxed; evolutions edged gold, the species' ultimate drawn bigger as its branch's capstone.

const SIZE := Vector2(160, 108)
const CAPSTONE_SIZE := Vector2(200, 128)
const FILL := {
	"maxed": Color("8a6d1f"), "buy": Color("2f6b2a"), "poor": UiKit.PANEL, "locked": Color("15191e")
}
const EDGE := {
	"maxed": UiKit.WARN, "buy": UiKit.GOOD, "poor": UiKit.PANEL_EDGE, "locked": UiKit.LOCKED
}
const ULTIMATE_EDGE := Color("ff3df0")

var id: String
## "plain", "branch" (species branch), "evolve" (grows the kaiju) or "ultimate" (capstone).
var role := "plain"
var state := "locked"


func _init(p_id: String, p_role: String) -> void:
	id = p_id
	role = p_role
	size = CAPSTONE_SIZE if role == "ultimate" else SIZE
	add_theme_font_size_override("font_size", UiKit.SIZE_SMALL)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clip_text = true


## Redraws the node from the tree and the rubble in hand.
func show_state(tree: UpgradeTree, rubble: int) -> void:
	var def: Dictionary = tree.defs[id]
	if tree.is_maxed(id):
		state = "maxed"
	elif not tree.is_unlocked(id):
		state = "locked"
	else:
		state = "buy" if tree.can_buy(id, rubble) else "poor"
	var price := tree.cost(id)
	var status: String = {
		"maxed": "MAXED",
		"locked": "LOCKED",
		"buy": "BUY %d" % price,
		"poor": "%d  (need %d)" % [price, price - rubble],
	}[state]
	var tag := "\n[E / Y]" if role == "ultimate" else ""
	text = (
		"%s\n%d/%d   %s%s" % [str(def["name"]), tree.level(id), tree.max_level(id), status, tag]
	)
	var fill: Color = FILL[state]
	var edge: Color = EDGE[state]
	var width := 3
	if role == "evolve" and state != "maxed":
		edge = UiKit.WARN if state != "locked" else edge
		width = 5
	elif role == "ultimate":
		edge = ULTIMATE_EDGE if state != "locked" else ULTIMATE_EDGE.darkened(0.5)
		width = 6
	add_theme_stylebox_override("normal", UiKit.box(fill, edge, width, 8))
	add_theme_stylebox_override("hover", UiKit.box(fill.lightened(0.15), Color.WHITE, width, 8))
	add_theme_stylebox_override("focus", UiKit.box(fill.lightened(0.15), Color.WHITE, width + 2, 8))
	add_theme_stylebox_override("pressed", UiKit.box(fill.darkened(0.2), Color.WHITE, width, 8))
	var font := UiKit.LOCKED.lightened(0.3) if state == "locked" else UiKit.TEXT
	if state == "poor":
		font = UiKit.MUTED
	for key: String in ["font_color", "font_hover_color", "font_focus_color"]:
		add_theme_color_override(key, font)
