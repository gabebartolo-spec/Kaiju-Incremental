extends RefCounted
## The far stand-in buildings carry the same rooftop tank mix as the playable ones (director
## 2026-10-27, D-352: "keep SOME of the wooden towers, but mix it up with the white ones"; picked
## "Mostly white"): about 3 roofs in 4 a white solar water heater (a white tank lying on its side
## over a dark panel), the rest a short wooden tower (a barrel taller than wide, 6 cells of the 12
## the tower stands). Read off the skyline's plain boxes by colour, tallied over every city of the
## run, so one lucky roll cannot pass or fail it.

const WOOD := Color("6a5040")  # a tower's barrel
const WHITE := Color("e6e8e4")  # a heater's tank
const GLASS := Color("1b2538")  # a heater's panel
const WHITE_MIN := 0.65
const WHITE_MAX := 0.85
const MIN_TANKS := 60  # across the run: enough roofs for the share to mean something
const BARREL_CELLS := 6  # the barrel's height in cells (8 to a storey), give or take one
const MIN_ASPECT := 1.1  # barrel height over width: taller than wide
const HEATER_LONG := 2.0  # the white tank is this many times longer than high
const SHOWN := 3


## Adds this skyline's tanks to `tally` ({"wood", "white", "glass", "tower", "heater"}: counts and
## the first few wrong shapes as strings).
static func add(skyline: CitySkyline, label: String, tally: Dictionary) -> void:
	for box: Dictionary in skyline.plain_drawn():
		if box["concrete"]:
			continue
		var c: Color = box["c"]
		var t: Transform3D = box["t"]
		var s := t.basis.get_scale()
		if c.is_equal_approx(WOOD):
			_count(tally, "wood")
			var cells := s.y * 8.0
			if absf(cells - BARREL_CELLS) > 1.0 or s.y < s.x * MIN_ASPECT:
				_note(tally, "tower", "%s: barrel %.1f x %.1f cells" % [label, s.x * 8, cells])
		elif c.is_equal_approx(WHITE):
			_count(tally, "white")
			if s.x < maxf(s.y, s.z) * HEATER_LONG:
				_note(tally, "heater", "%s: tank %.2f x %.2f x %.2f" % [label, s.x, s.y, s.z])
		elif c.is_equal_approx(GLASS):
			_count(tally, "glass")


static func verdict(tally: Dictionary, check: Callable) -> void:
	var white := Num.i(tally.get("white", 0))
	var wood := Num.i(tally.get("wood", 0))
	var all := white + wood
	var share := float(white) / maxf(1.0, float(all))
	var line := "far stand-ins' rooftop tanks: %d white heaters, %d wooden towers (%.2f white, bar"
	line += " %.2f to %.2f, at least %d tanks)"
	check.call(
		all >= MIN_TANKS and share >= WHITE_MIN and share <= WHITE_MAX,
		line % [white, wood, share, WHITE_MIN, WHITE_MAX, MIN_TANKS]
	)
	var glass := Num.i(tally.get("glass", 0))
	var panels := "a dark panel under each white heater: %d panels, %d heaters"
	check.call(glass == white, panels % [glass, white])
	var tower: Array = tally.get("tower_notes", [])
	check.call(tower.is_empty(), "wooden towers taller than wide, 6 cells of barrel: %s" % [tower])
	var heater: Array = tally.get("heater_notes", [])
	check.call(
		heater.is_empty(), "heater tanks lie on their side, 2x as long as high: %s" % [heater]
	)


static func _count(tally: Dictionary, key: String) -> void:
	tally[key] = Num.i(tally.get(key, 0)) + 1


static func _note(tally: Dictionary, key: String, text: String) -> void:
	var notes: Array = tally.get(key + "_notes", [])
	if notes.size() < SHOWN:
		notes.append(text)
	tally[key + "_notes"] = notes
