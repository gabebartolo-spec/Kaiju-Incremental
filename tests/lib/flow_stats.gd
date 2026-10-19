extends RefCounted
## The flow suite's stats-panel checks (D-077): the evolution tree's side panel speaks plain
## words. Selecting a node shows the stats that node changes, each by its line from data/tuning.json
## "stat_text" ("Stomps hit harder"), and nothing else; no raw software term shows anywhere.

## Terms the old summary panel showed that read as software, not play (screen critic, D-077).
const RAW_TERMS: Array[String] = ["Stomps/s", "Armour", "Recharge", "Size", "/sec"]


## Selects every node in turn (by focus, as the pad does) and checks what the screen says.
static func plain(runner: SceneTree, check: Callable, screen: UpgradeScreen) -> void:
	var lines: Dictionary = Content.section("stat_text")
	var raw: Array[String] = []
	var wrong: Array[String] = []
	var buy_rows: Dictionary = {}
	for id: String in screen.tree.order:
		screen.node_button(id).grab_focus()
		await runner.process_frame
		var shown := _side_text(screen)
		buy_rows[_buy_row(screen)] = id
		# A node's own name is the player's word, not a stat label ("Signature Recharge").
		var words := shown
		for other: String in screen.tree.order:
			var other_def: Dictionary = screen.tree.defs[other]
			words = words.replace(str(other_def.get("name", "")), "")
		for term: String in RAW_TERMS:
			if words.contains(term) and not raw.has(term):
				raw.append(term)
		if shown.contains("_"):
			raw.append("%s: an underscore (raw key)" % id)
		for key: String in lines:
			var entry: Dictionary = lines[key]
			if entry.get("hidden", false):
				continue
			var node_def: Dictionary = screen.tree.defs[id]
			var node_effects := UpgradeTree.effects_for(node_def, str(screen.species["id"]))
			var changes := node_effects.has(key)
			if shown.contains(str(entry["line"])) != changes:
				wrong.append("%s %s %s" % [id, "misses" if changes else "shows", key])
		var def: Dictionary = screen.tree.defs[id]
		var effects := UpgradeTree.effects_for(def, str(screen.species["id"]))
		for key: String in effects:
			if not lines.has(key):
				wrong.append("%s: no stat_text line for %s" % [id, key])
	check.call(raw.is_empty(), "the tree shows no raw stat terms (D-077): %s" % [raw])
	check.call(
		wrong.is_empty() and not lines.is_empty(),
		"each node's panel names exactly the stats it changes (D-077): %s" % [wrong.slice(0, 6)]
	)
	check.call(
		buy_rows.size() == 1,
		"level, cost and the buy line sit at one height on every node (D-077): %s" % [buy_rows]
	)


## Where the panel's "Level n / m" block ends on screen, rounded to the pixel.
static func _buy_row(screen: UpgradeScreen) -> int:
	for node: Node in screen.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text.begins_with("Level "):
			return roundi(label.get_global_rect().end.y)
	return -1


## Every visible text on the screen outside the tree's nodes (the side panels and header).
static func _side_text(screen: UpgradeScreen) -> String:
	var out := PackedStringArray()
	for node: Node in screen.find_children("*", "Control", true, false):
		if node is UpgradeNode or not (node as Control).is_visible_in_tree():
			continue
		if node is Label:
			out.append((node as Label).text)
		elif node is RichTextLabel:
			out.append((node as RichTextLabel).get_parsed_text())
	return "\n".join(out)
