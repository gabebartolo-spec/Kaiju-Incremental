class_name SpecimenCard
extends Control
## The lab card before a new specimen's first rise (D-260: "Lab card + a short headline", about
## 2 s): the kaiju died, so the next one out of the lab is one number up. A broadcast card on the
## backdrop with the specimen's name and the headline, e.g. "K-01 LOST · K-02 RELEASED" (copy in
## tuning "news" specimen; the dot is drawn, a small square, as our fonts have none). Shown by Main
## between the tree and the rampage; `done` after tuning "ui" specimen_card seconds.

signal done

## The middle dot between the headline's halves, as text (headline_text).
const DOT := " · "

## The card's title and the headline's two halves (read by the suites and captures).
var title: Label
var lost: Label
var released: Label
var _left := 0.0
var _finished := false


## `specimen`: the number of the specimen about to rise (the save's "specimen").
func _init(specimen: int) -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left = Num.f(UiKit.ui()["specimen_card"]["seconds"])
	var copy: Dictionary = Content.section("news")["specimen"]
	add_child(UiKit.backdrop())
	var centre := CenterContainer.new()
	UiKit.full_rect(centre)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var card := UiKit.panel()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(card)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", Num.i(UiKit.ui()["specimen_card"]["gap"]))
	card.add_child(col)
	var header := UiKit.header(fill(str(copy["title"]), specimen))
	col.add_child(header)
	title = header.get_child(0)
	var halves: Array = copy["headline"]
	col.add_child(_headline(fill(str(halves[0]), specimen), fill(str(halves[1]), specimen)))


## `text` with "{lost}" and "{next}" as two-digit specimen numbers (the one lost, `specimen`).
static func fill(text: String, specimen: int) -> String:
	var gone := "%02d" % maxi(1, specimen - 1)
	return text.replace("{lost}", gone).replace("{next}", "%02d" % specimen)


## The headline as one line of text, e.g. "K-01 LOST · K-02 RELEASED".
func headline_text() -> String:
	return lost.text + DOT + released.text


## Both halves in hazard yellow, a square dot between them.
func _headline(left: String, right: String) -> Control:
	var cfg: Dictionary = UiKit.ui()["specimen_card"]
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Num.i(cfg["dot_gap"]))
	lost = UiKit.label(left, UiKit.SIZE_HEAD, UiKit.ACCENT)
	row.add_child(lost)
	var dot := ColorRect.new()
	dot.color = UiKit.ACCENT
	dot.custom_minimum_size = Vector2.ONE * Num.f(cfg["dot"])
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)
	released = UiKit.label(right, UiKit.SIZE_HEAD, UiKit.ACCENT)
	row.add_child(released)
	return row


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 and not _finished:
		_finished = true
		done.emit()
