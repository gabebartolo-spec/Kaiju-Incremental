class_name UpgradeReadout
extends RefCounted
## The upgrade screen's readout (UpgradeScreen): the stats a node changes and its status line.


static func status_line(u: UpgradeScreen, id: String) -> String:
	var head := u.tr("Level %d / %d") % [u.tree.level(id), u.tree.max_level(id)] + "   "
	if u.tree.is_maxed(id):
		return head + u.tr("MAXED")
	if not u.tree.is_unlocked(id):
		var def: Dictionary = u.tree.defs[id]
		var names: Array[String] = []
		var requires: Array = def.get("requires", [])
		for req: String in requires:
			if u.tree.level(req) < 1:
				var req_def: Dictionary = u.tree.defs[req]
				names.append(u.tr(str(req_def["name"])))
		# Owned from an older save in a ring that is not open yet: nothing named to buy first.
		if names.is_empty():
			return head + u.tr("Not yet")
		return head + u.tr("Needs: %s") % ", ".join(names)
	# Three short lines, so no wrap ever leaves a dash or a lone word at a line end.
	var nl := String.chr(10)
	var have := (
		(u.tr("Cost %d") + nl + u.tr("You have %d biomass") + nl) % [u.tree.cost(id), u.rubble]
	)
	if u.tree.can_buy(id, u.rubble):
		return head + have + u.tr("Enter / pad A to buy")
	return head + have + u.tr("%d more needed") % (u.tree.cost(id) - u.rubble)


## Only the stats this node changes, each in plain words from data (D-077): the words, then
## "13  ->  16" under them, the new value brighter than the old and the unit written once.
static func show_stats(
	u: UpgradeScreen, effects: Dictionary, stats: Dictionary, steps: int
) -> void:
	for child: Node in u._info_stats.get_children():
		u._info_stats.remove_child(child)
		child.queue_free()
	var words: Dictionary = Content.section("stat_text")
	for stat: String in effects:
		var entry: Dictionary = words.get(stat, {})
		if entry.get("hidden", false):
			continue
		var now := Num.f(stats.get(stat, 0.0))
		var line := UiKit.label(
			u.tr("%s:") % u.tr(str(entry.get("line", stat))), UiKit.SIZE_BODY, UiKit.MUTED
		)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		u._info_stats.add_child(line)
		# The values under the words; the "now" column is one fixed width, so arrows line up.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		u._info_stats.add_child(row)
		var was := UiKit.label(u._fmt(entry, now, steps == 0), UiKit.SIZE_BODY, UiKit.MUTED)
		was.custom_minimum_size = Vector2(UpgradeScreen.NOW_WIDTH, 0)
		row.add_child(was)
		if steps > 0:
			var arrow := TextureRect.new()
			arrow.texture = UiKit.arrow()
			arrow.modulate = UiKit.GOOD
			arrow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			row.add_child(arrow)
			var after := u._fmt(entry, now + Num.f(effects[stat]), true)
			row.add_child(UiKit.label(after, UiKit.SIZE_BODY, UiKit.TEXT))
	u._info_stats.visible = u._info_stats.get_child_count() > 0
