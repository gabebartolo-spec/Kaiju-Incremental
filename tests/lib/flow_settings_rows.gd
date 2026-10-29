extends RefCounted
## The settings menu's rows as rules (D-385: no member names, pixel gaps or row copy): on the
## director's 4K TV no two controls overlap, every one stands on screen, every button shows a
## label, and Tab from the card's first control reaches every visible button and slider.

const FlowLayout := preload("res://tests/lib/flow_layout.gd")
## Rects may share an edge; anything deeper than this (px) is an overlap.
const EPS := 0.5
## More focus steps than any settings card has controls.
const MAX_STEPS := 64


static func run(t: SceneTree, check: Callable, menu: SettingsMenu) -> void:
	var window := t.root.size
	t.root.size = FlowLayout.TV_SIZE
	for _i: int in 3:
		await t.process_frame
	var view := t.root.get_visible_rect()
	var parts: Array[Control] = []
	for found: Node in menu.find_children("*", "Control", true, false):
		var c := found as Control
		var shown := c.is_visible_in_tree() and not _inside_button(c, menu)
		if shown and (c is Button or c is Slider or (c is Label and (c as Label).text != "")):
			parts.append(c)
	var overlaps: Array[String] = []
	var off: Array[String] = []
	var blank: Array[String] = []
	for i: int in parts.size():
		var r := parts[i].get_global_rect()
		if not view.grow(EPS).encloses(r):
			off.append(_name(parts[i]))
		if parts[i] is Button and (parts[i] as Button).text.strip_edges() == "":
			blank.append(str(parts[i].name))
		for j: int in range(i + 1, parts.size()):
			if r.grow(-EPS).intersects(parts[j].get_global_rect().grow(-EPS)):
				overlaps.append("%s / %s" % [_name(parts[i]), _name(parts[j])])
	check.call(parts.size() > 1, "settings: the card draws its rows (%d controls)" % parts.size())
	check.call(overlaps.is_empty(), "settings: no two rows or controls overlap: %s" % [overlaps])
	check.call(off.is_empty(), "settings: every row stands on screen: %s" % [off])
	check.call(blank.is_empty(), "settings: every button shows its label: %s" % [blank])
	_reachable(check, parts)
	t.root.size = window
	for _i: int in 2:
		await t.process_frame


## Focus order (find_next_valid_focus, the walk Tab takes) from the card's first button or slider
## reaches every visible button and slider on it.
static func _reachable(check: Callable, parts: Array[Control]) -> void:
	var focusable: Array[Control] = []
	for c: Control in parts:
		if c is Button or c is Slider:
			focusable.append(c)
	var seen: Array[Control] = []
	var at: Control = null
	if not focusable.is_empty():
		at = focusable[0]
	for _i: int in MAX_STEPS:
		if at == null or seen.has(at):
			break
		seen.append(at)
		at = at.find_next_valid_focus()
	var missed: Array[String] = []
	for c: Control in focusable:
		if not seen.has(c):
			missed.append(_name(c))
	check.call(
		not focusable.is_empty() and missed.is_empty(),
		"settings: every row is reachable by focus (missed %s)" % [missed]
	)


static func _inside_button(c: Control, menu: Node) -> bool:
	var up := c.get_parent()
	while up != null and up != menu:
		if up is Button:
			return true
		up = up.get_parent()
	return false


static func _name(c: Control) -> String:
	var text: Variant = c.get("text")
	if text is String:
		return "%s '%s'" % [c.name, text]
	return str(c.name)
