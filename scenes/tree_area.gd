class_name TreeArea
extends Control
## The evolution tree's nodes, laid out to fill this control at whatever size the screen gives
## it (never scaled, so text keeps its size on the TV at every UI scale): the columns share the
## width and the rows the height, the species branch's row sits on its own tinted band with the
## ultimate as its taller capstone, and lines join each node to its prerequisites.

signal node_pressed(id: String)
signal node_selected(id: String)

const COLUMNS := 8
## The species' own branch (docs/SPECIES.md) is the bottom row.
const BRANCH_ROW := 5
const GAP := Vector2(8, 16)
## The capstone is this much taller than a node (its extra "[E / Y]" line).
const CAPSTONE_EXTRA := 28.0
const BRANCH_TINT_ALPHA := 0.18
## Smallest the area may get and still fit a node's three lines of text.
const MIN_SIZE := Vector2(COLUMNS * 120, (BRANCH_ROW + 1) * 100)

var tree: UpgradeTree
var buttons: Dictionary = {}
var _species: Dictionary
var _roles: Dictionary
var _band: ColorRect


## roles: id -> "plain" / "branch" / "evolve" / "ultimate" (UpgradeScreen.role_of).
func setup(p_tree: UpgradeTree, species: Dictionary, roles: Dictionary) -> void:
	tree = p_tree
	_species = species
	_roles = roles


func _ready() -> void:
	custom_minimum_size = MIN_SIZE
	var colors: Dictionary = _species["colors"]
	var eye := Color(str(colors["eye"]))
	_band = ColorRect.new()
	_band.color = Color(eye, BRANCH_TINT_ALPHA)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	for id: String in tree.order:
		var def: Dictionary = tree.defs[id]
		var b := UpgradeNode.new(id, str(_roles[id]), str(def["name"]))
		b.pressed.connect(func() -> void: node_pressed.emit(id))
		b.focus_entered.connect(func() -> void: node_selected.emit(id))
		b.mouse_entered.connect(func() -> void: node_selected.emit(id))
		add_child(b)
		buttons[id] = b
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var cell := Vector2(size.x / COLUMNS, size.y / (BRANCH_ROW + 1))
	var box := cell - GAP
	for id: String in tree.order:
		var def: Dictionary = tree.defs[id]
		var pos: Array = def["pos"]
		var at := Vector2(Num.f(pos[0]) * cell.x, Num.f(pos[1]) * cell.y) + GAP * 0.5
		var b: UpgradeNode = buttons[id]
		if b.role == "ultimate":
			b.place(at, box + Vector2(0, CAPSTONE_EXTRA))
		else:
			b.place(at, box)
	# The band starts below the row above it (its boxes end GAP.y / 2 short of the row line).
	_band.position = Vector2(0, BRANCH_ROW * cell.y)
	_band.size = Vector2(size.x, cell.y + CAPSTONE_EXTRA)
	queue_redraw()


func _draw() -> void:
	for id: String in tree.order:
		var def: Dictionary = tree.defs[id]
		var requires: Array = def.get("requires", [])
		for req: String in requires:
			var owned := tree.level(req) > 0
			draw_line(_centre(req), _centre(id), UiKit.GOOD if owned else UiKit.LOCKED, 4.0, true)


func _centre(id: String) -> Vector2:
	var b: Button = buttons[id]
	return b.position + b.size * 0.5
