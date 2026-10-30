extends RefCounted
## The title menu's plate layout checks for tests/lib/ui_title.gd: nothing overlaps, and every
## label has room on its plate (split out to keep files small).

const GuiInput := preload("res://tests/lib/gui_input.gd")
## Room each side of a label (px at 1080p; 28 at 4K) and the tape bands on a plate (two).
const LABEL_ROOM := 14.0
const NEWLINE := "\n"
const PLATE_BANDS := 2.0


## No two of `parts` (the logo and the row's plates) and the corner buttons overlap.
static func no_overlap(check: Callable, title: Node, parts: Array) -> void:
	var all: Array[Control] = []
	for found: Variant in parts + [title.find_child("Gear", true, false)]:
		if found is Control:
			var c: Control = found
			all.append(c)
	var exit := GuiInput.button(title, "RUN FOR YOUR LIFE")
	if exit != null:
		all.append(exit)
	var hits: Array[String] = []
	for i: int in all.size():
		for j: int in range(i + 1, all.size()):
			if all[i].get_global_rect().grow(-1.0).intersects(all[j].get_global_rect()):
				hits.append("%s / %s" % [all[i].name, all[j].name])
	check.call(all.size() >= 4 and hits.is_empty(), "no two title controls overlap: %s" % [hits])


## Each plate leaves 14 px (28 at 4K) or more between its tape and its widest label line.
static func label_room(check: Callable, buttons: Array) -> void:
	var tight: Array[String] = []
	for found: Variant in buttons:
		var b: Button = found
		var box := b.get_theme_stylebox("normal") as HazardBox
		var font := b.get_theme_font("font")
		var size := b.get_theme_font_size("font_size")
		var widest := 0.0
		for line: String in b.text.split(NEWLINE):
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		var face := b.size.x - HazardBox.PLATE_SHADOW.x
		var room := (face - PLATE_BANDS * box.band_size - widest) / 2.0
		if room < LABEL_ROOM:
			tight.append("%s %.1f px" % [b.text, room])
	check.call(tight.is_empty(), "every title label has 14 px or more each side: %s" % [tight])
