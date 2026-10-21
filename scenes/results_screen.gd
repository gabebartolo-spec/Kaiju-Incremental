class_name ResultsScreen
extends CanvasLayer
## After the end beat: what the rampage did, counted up line by line over the wrecked city,
## each line against the best rampage before this one. Reads the result; decides nothing.
## Confirm during the count finishes it at once; EVOLVE then reports `continued`.

signal continued

## Stat key, label, how the value is shown ("int" or "pct").
const ROWS: Array[Array] = [
	["rubble", "Biomass devoured", "int"],
	["destruction", "City destroyed", "pct"],
	["toppled", "Buildings toppled", "int"],
	["tallest_topple", "Tallest tower toppled (floors)", "int"],
	["civilians", "Civilians crushed", "int"],
	["tanks", "Tanks crushed", "int"],
	["helis", "Helicopters downed", "int"],
]
## Frames each line takes to count up, and the gap before the next starts (frame-paced, so a
## capture or a test sees the same screen whatever the machine).
const COUNT_FRAMES := 36
const ROW_GAP_FRAMES := 12
const LAYER := 20
## The stat the headline under the title compares with the best (its row shows no best badge).
const VERDICT_STAT := "rubble"

var result: Dictionary
var previous_best: Dictionary
## Frames since the count began; counting is done once every row has landed.
var frame := 0
var _values: Array[Label] = []
var _badges: Array[Label] = []
var _verdict: Label
var _go: Button


## previous_best: the save's best record before this rampage ({} on a first rampage).
func _init(p_result: Dictionary, p_previous_best: Dictionary) -> void:
	result = p_result
	previous_best = p_previous_best
	layer = LAYER


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	UiKit.full_rect(dim)
	add_child(dim)
	var centre := CenterContainer.new()
	UiKit.full_rect(centre)
	add_child(centre)
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(880, 0)
	centre.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var title := UiKit.label("RAMPAGE REPORT", UiKit.SIZE_TITLE, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_verdict = UiKit.label(verdict(), UiKit.SIZE_HEAD, UiKit.WARN)
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict.modulate.a = 0.0
	col.add_child(_verdict)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for row: Array in ROWS:
		var name_label := UiKit.label(str(row[1]), UiKit.SIZE_BODY, UiKit.MUTED)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var value := UiKit.label(_shown(row, 0.0), UiKit.SIZE_HEAD, UiKit.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(170, 0)
		grid.add_child(value)
		_values.append(value)
		var badge := UiKit.label(_best_text(row), UiKit.SIZE_SMALL, UiKit.MUTED)
		badge.custom_minimum_size = Vector2(230, 0)
		badge.modulate.a = 0.0
		grid.add_child(badge)
		_badges.append(badge)
	_go = UiKit.button("EVOLVE  >", UiKit.SIZE_HEAD)
	_go.custom_minimum_size = Vector2(0, 80)
	_go.pressed.connect(_on_go)
	col.add_child(_go)
	_go.grab_focus.call_deferred()
	var crawl := NewsTicker.new(news(result))
	crawl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	crawl.offset_top = -NewsTicker.HEIGHT
	add_child(crawl)


## The evening news about this rampage, for the crawl under the report: the city's reaction,
## not the table again (data/tuning.json "news.report": per stat, the first line whose "min"
## the rampage reached; "{n}" is the stat's value).
static func news(r: Dictionary) -> PackedStringArray:
	var cfg := Content.section("news")
	var lines := PackedStringArray()
	var done: Dictionary = {}
	var report: Array = cfg.get("report", [])
	for entry: Dictionary in report:
		var stat := str(entry["stat"])
		var value := Num.f(r.get(stat, 0))
		if done.has(stat) or value < Num.f(entry["min"]):
			continue
		done[stat] = true
		lines.append(str(entry["line"]).replace("{n}", str(floori(value))))
	lines.append(str(cfg.get("close", "")))
	return lines


func _process(_delta: float) -> void:
	if counting():
		frame += 1
	_show_frame()


## True until every row has counted up.
func counting() -> bool:
	return frame < _total_frames()


## Finishes the count at once (confirm pressed early).
func skip() -> void:
	frame = _total_frames()
	_show_frame()


## The line under the title: did this rampage beat the best before it, on rubble?
func verdict() -> String:
	var rubble := Num.f(result.get("rubble", 0))
	if previous_best.is_empty():
		return "YOUR FIRST RAMPAGE"
	var best := Num.f(previous_best.get("rubble", 0.0))
	if rubble > best:
		if best <= 0.0:
			return "BIGGER THAN EVER"
		return "BIGGER THAN LAST TIME  +%d%% BIOMASS" % roundi(100.0 * (rubble - best) / best)
	return "%d BIOMASS SHORT OF YOUR BEST" % ceili(best - rubble)


## True when this rampage beat the best before it on `key` (never on a first rampage).
func is_new_best(key: String) -> bool:
	if previous_best.is_empty():
		return false
	return Num.f(result.get(key, 0.0)) > Num.f(previous_best.get(key, 0.0))


func _on_go() -> void:
	if counting():
		skip()
		return
	continued.emit()


func _total_frames() -> int:
	return ROWS.size() * (COUNT_FRAMES + ROW_GAP_FRAMES)


func _show_frame() -> void:
	for n: int in ROWS.size():
		var row: Array = ROWS[n]
		var t := clampf(float(frame - n * (COUNT_FRAMES + ROW_GAP_FRAMES)) / COUNT_FRAMES, 0.0, 1.0)
		var target := Num.f(result.get(str(row[0]), 0.0))
		_values[n].text = _shown(row, target * ease(t, 0.4))
		var landed := t >= 1.0
		var record := landed and is_new_best(str(row[0]))
		_values[n].add_theme_color_override("font_color", UiKit.GOOD if record else UiKit.TEXT)
		_badges[n].modulate.a = 1.0 if landed else 0.0
		if record and str(row[0]) != VERDICT_STAT:
			_badges[n].text = "NEW BEST"
			_badges[n].add_theme_color_override("font_color", UiKit.GOOD)
	_verdict.modulate.a = 0.0 if counting() else 1.0
	_go.text = "SKIP" if counting() else "EVOLVE  >"


func _shown(row: Array, value: float) -> String:
	if str(row[2]) == "pct":
		return "%d%%" % floori(value * 100.0)
	return "%d" % floori(value)


## Every row shows the best before this rampage (none at all on a first rampage).
func _best_text(row: Array) -> String:
	# The headline under the title already compares this row with the best: say it once.
	if previous_best.is_empty() or str(row[0]) == VERDICT_STAT:
		return ""
	return "best " + _shown(row, Num.f(previous_best.get(str(row[0]), 0.0)))
