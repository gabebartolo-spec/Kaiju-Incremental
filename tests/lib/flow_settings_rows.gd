extends RefCounted
## The settings menu's rows as the screen critic asked (round 2, D-145): the two-button rows split
## the sliders' span in equal halves and every right edge, time of day included, is the sliders'
## right edge; 10 px between button rows; 20 px above CONTROLS and between the table and BACK;
## every cycling button shows its < > cue. Read from real layout rects at 1x, in canvas px.

const GuiInput := preload("res://tests/lib/gui_input.gd")
const NAMES: Array[String] = ["_fullscreen", "_scale", "_graphics", "_fps", "_time", "_weather"]
const ROW_GAP := 10.0
const BLOCK_GAP := 20.0
const EPS := 0.5


static func run(check: Callable, menu: SettingsMenu) -> void:
	var rects: Array[Rect2] = []
	for name: String in NAMES:
		var b: Button = menu.get(name)
		rects.append(b.get_global_rect())
		check.call(
			b.text.begins_with("< ") and b.text.ends_with(" >"),
			"settings: %s shows its < > cue ('%s')" % [name, b.text]
		)
	var fullscreen := rects[0]
	var scale := rects[1]
	var graphics := rects[2]
	var fps := rects[3]
	var time := rects[4]
	var weather := rects[5]
	var right := menu.effects.get_global_rect().end.x
	for r: Rect2 in [scale, fps, time, weather]:
		check.call(
			absf(r.end.x - right) < EPS, "settings: a right edge is the sliders' (%s)" % r.end.x
		)
	check.call(
		absf(fullscreen.size.x - scale.size.x) < EPS and absf(graphics.size.x - fps.size.x) < EPS,
		"settings: each two-button row splits its span in equal halves"
	)
	check.call(
		(
			absf(scale.position.x - fps.position.x) < EPS
			and absf(fullscreen.position.x - graphics.position.x) < EPS
		),
		(
			"settings: both two-button rows share one split (%s, %s)"
			% [scale.position.x, fps.position.x]
		)
	)
	check.call(
		(
			absf(time.position.x - fullscreen.position.x) < EPS
			and absf(time.end.x - scale.end.x) < EPS
			and absf(weather.position.x - fullscreen.position.x) < EPS
			and absf(weather.end.x - scale.end.x) < EPS
		),
		"settings: time of day and weather span the same columns edge to edge"
	)
	check.call(
		(
			absf(graphics.position.y - fullscreen.end.y - ROW_GAP) < EPS
			and absf(time.position.y - graphics.end.y - ROW_GAP) < EPS
			and absf(weather.position.y - time.end.y - ROW_GAP) < EPS
		),
		(
			"settings: 10 px between button rows (%s, %s, %s)"
			% [
				graphics.position.y - fullscreen.end.y,
				time.position.y - graphics.end.y,
				weather.position.y - time.end.y
			]
		)
	)
	_blocks(check, menu, weather)


static func _blocks(check: Callable, menu: SettingsMenu, time: Rect2) -> void:
	var controls: Label
	var last_row: Label
	var back: Button = GuiInput.button(menu, "BACK")
	for found: Node in menu.find_children("*", "Label", true, false):
		var l := found as Label
		if l.text == "CONTROLS":
			controls = l
		elif l.text == "Back":
			last_row = l
	check.call(
		controls != null and controls.get_global_rect().position.y - time.end.y >= BLOCK_GAP - EPS,
		"settings: 20 px or more above the CONTROLS heading"
	)
	check.call(
		(
			last_row != null
			and back != null
			and (
				back.get_global_rect().position.y - last_row.get_global_rect().end.y
				>= BLOCK_GAP - EPS
			)
		),
		"settings: 20 px or more between the table and BACK"
	)
	var names: Array[String] = []
	for found: Node in menu.find_children("*", "Label", true, false):
		names.append((found as Label).text)
	check.call(
		names.has("Graphics and FPS") and not names.has("Graphics and frame cap"),
		"settings: the GPU row is named Graphics and FPS"
	)
