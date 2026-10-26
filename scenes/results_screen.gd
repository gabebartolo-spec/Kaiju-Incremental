class_name ResultsScreen
extends CanvasLayer
## After the end beat: what the rampage did, counted up line by line over the wrecked city,
## each line against the best rampage before this one (D-259: biomass and best combo, the
## destruction tally, the body count, personal bests with a NEW RECORD stamp; the bests live in
## the save slot). The headline across the top says how it ended (D-263, D-265; tuning "results"
## "endings"). Reads the result; decides nothing. Confirm during the count finishes it at once;
## EVOLVE then reports `continued`.

signal continued

## Stat key, label, how the value is shown ("int", "pct", "storeys" or "combo") and its group.
const ROWS: Array[Array] = [
	["rubble", "Biomass earned", "int", "biomass"],
	["best_combo", "Best combo", "combo", "biomass"],
	["toppled", "Towers toppled", "int", "destruction"],
	["tallest_topple", "Tallest tower toppled", "storeys", "destruction"],
	["destruction", "City destroyed", "pct", "destruction"],
	["landmarks", "Landmarks felled", "int", "destruction"],
	["civilians", "People eaten", "int", "body"],
	["tanks", "Tanks", "int", "body"],
	["helis", "Helicopters", "int", "body"],
	["agents", "Agents", "int", "body"],
]
## Group id, heading, rows per line: biomass across the top, then the tally beside the body count.
const GROUPS: Array[Array] = [
	["biomass", "BIOMASS", 2],
	["destruction", "DESTRUCTION", 1],
	["body", "BODY COUNT", 1],
]
## What a stat the run did not report shows (best combo until the combo system feeds it).
const NO_VALUE := "-"
## The headline when the end reason has no row in tuning "results" "endings".
const DEFAULT_HEADLINE := "RAMPAGE REPORT"
const STAMP_TEXT := "NEW RECORD"
## The stamp's tilt (degrees) and border (px at 1080p).
const STAMP_TILT := -6.0
const STAMP_BORDER := 3
## Frames each line takes to count up, and the gap before the next starts (frame-paced, so a
## capture or a test sees the same screen whatever the machine).
const COUNT_FRAMES := 26
const ROW_GAP_FRAMES := 8
const LAYER := 20
## The card's width, a stat column's widths and the gap between the two columns (px at 1080p).
const CARD_WIDTH := 1300
const VALUE_WIDTH := 150
const BADGE_WIDTH := 200
const COLUMN_GAP := 48
## Space under EVOLVE inside the card (px at 1080p).
const BOTTOM_PAD := 20
## The stat the headline under the title compares with the best (its row shows no best badge).
const VERDICT_STAT := "rubble"

var result: Dictionary
var previous_best: Dictionary
## Frames since the count began; counting is done once every row has landed.
var frame := 0
## The confirm button's text once the count is done ("CONTINUE  >" before the demo's thanks).
var go_label := "EVOLVE  >"
## The headline across the top (read by the tests and captures).
var title: Label
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
	centre.offset_bottom = -NewsTicker.HEIGHT
	add_child(centre)
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	centre.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var strip := UiKit.header(headline(str(result.get("reason", ""))))
	title = strip.get_child(0) as Label
	col.add_child(strip)
	_verdict = UiKit.label(verdict(), UiKit.SIZE_HEAD, UiKit.WARN)
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict.modulate.a = 0.0
	col.add_child(_verdict)
	_add_groups(col)
	_go = UiKit.button("EVOLVE", UiKit.SIZE_HEAD)
	_go.custom_minimum_size = Vector2(0, 80)
	_go.pressed.connect(_on_go)
	col.add_child(_go)
	_add_pad(col)
	_go.grab_focus.call_deferred()
	var crawl := NewsTicker.new(news(result))
	crawl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	crawl.offset_top = -NewsTicker.HEIGHT
	add_child(crawl)


## The headline for a rampage that ended for `reason` (the sim's end reason).
static func headline(reason: String) -> String:
	var endings: Dictionary = Content.section("results")["endings"]
	var ending: Dictionary = endings.get(reason, {})
	return str(ending.get("headline", DEFAULT_HEADLINE))


## Biomass across the top, then the destruction tally beside the body count. Rows are made in
## ROWS order, so _values and _badges line up with ROWS.
func _add_groups(col: VBoxContainer) -> void:
	var sections: Dictionary[String, VBoxContainer] = {}
	for group: Array in GROUPS:
		sections[str(group[0])] = _section(str(group[1]), Num.i(group[2]))
	col.add_child(sections["biomass"])
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", COLUMN_GAP)
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	pair.add_child(sections["destruction"])
	pair.add_child(sections["body"])
	col.add_child(pair)
	for row: Array in ROWS:
		var grid := sections[str(row[3])].get_child(1) as GridContainer
		_add_row(grid, row)


## A group: its heading over a grid of `per_line` rows side by side.
func _section(heading: String, per_line: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 4)
	box.add_child(UiKit.label(heading, UiKit.SIZE_BODY, UiKit.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 3 * per_line
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	return box


func _add_row(grid: GridContainer, row: Array) -> void:
	var name_label := UiKit.label(str(row[1]), UiKit.SIZE_BODY, UiKit.MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	var value := UiKit.label(_shown(row, 0.0), UiKit.SIZE_HEAD, UiKit.TEXT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	grid.add_child(value)
	_values.append(value)
	var badge := UiKit.label(_best_text(row), UiKit.SIZE_BODY, UiKit.MUTED)
	badge.custom_minimum_size = Vector2(BADGE_WIDTH, 0)
	badge.modulate.a = 0.0
	grid.add_child(badge)
	_badges.append(badge)


## Space under EVOLVE, inside the card.
func _add_pad(col: Container) -> void:
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, BOTTOM_PAD)
	col.add_child(pad)


## The evening news about this rampage, for the crawl under the report: the city's reaction,
## not the table again (data/tuning.json "news.report": per stat, the first line whose "min"
## the rampage reached; "{n}" is the stat's value), closed by the ending's own line.
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
	var endings: Dictionary = Content.section("results")["endings"]
	var ending: Dictionary = endings.get(str(r.get("reason", "")), {})
	if ending.has("close"):
		lines.append(str(ending["close"]))
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
	# A record on another row beside "short of your best" would read as a contradiction.
	for row: Array in ROWS:
		if str(row[0]) != VERDICT_STAT and is_new_best(str(row[0])):
			return "%d SHORT OF YOUR BEST BIOMASS, BUT NEW RECORDS" % ceili(best - rubble)
	return "%d BIOMASS SHORT OF YOUR BEST" % ceili(best - rubble)


## True when this rampage beat the best before it on `key` (never on a first rampage, never on
## a stat the run did not report).
func is_new_best(key: String) -> bool:
	if previous_best.is_empty() or not result.has(key):
		return false
	return Num.f(result[key]) > Num.f(previous_best.get(key, 0.0))


## The rows that carry a NEW RECORD stamp once the count is done (read by the tests).
func records() -> Array[String]:
	var out: Array[String] = []
	for row: Array in ROWS:
		if str(row[0]) != VERDICT_STAT and is_new_best(str(row[0])):
			out.append(str(row[0]))
	return out


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
		if record and str(row[0]) != VERDICT_STAT and _badges[n].text != STAMP_TEXT:
			_stamp(_badges[n])
	_verdict.modulate.a = 0.0 if counting() else 1.0
	_go.text = "SKIP" if counting() else go_label


## Turns a row's best badge into the NEW RECORD stamp: alert red, boxed, tilted.
func _stamp(badge: Label) -> void:
	badge.text = STAMP_TEXT
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", UiKit.ALERT)
	var box := UiKit.box(Color(0, 0, 0, 0), UiKit.ALERT, STAMP_BORDER)
	box.set_content_margin_all(4)
	badge.add_theme_stylebox_override("normal", box)
	badge.pivot_offset = badge.size * 0.5
	badge.rotation_degrees = STAMP_TILT


func _shown(row: Array, value: float) -> String:
	if not result.has(str(row[0])):
		return NO_VALUE
	match str(row[2]):
		"pct":
			return "%d%%" % floori(value * 100.0)
		"storeys":
			return "%d STOREYS" % floori(value) if floori(value) != 1 else "1 STOREY"
		"combo":
			return "x%.1f" % value
	return "%d" % floori(value)


## Every row shows the best before this rampage (none at all on a first rampage, none for a stat
## the run did not report).
func _best_text(row: Array) -> String:
	# The headline under the title already compares this row with the best: say it once.
	var key := str(row[0])
	if previous_best.is_empty() or key == VERDICT_STAT or not result.has(key):
		return ""
	return "best " + _shown(row, Num.f(previous_best.get(key, 0.0)))
