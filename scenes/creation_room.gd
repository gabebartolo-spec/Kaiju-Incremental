class_name CreationRoom
extends RefCounted
## The lab room round Kaiju Creation's bench (the director 2026-10-25: "change the black interior to
## a laboratory setting"; asked, "Dark high-tech lab": steel wall panels, shelving with sample jars,
## cable runs, a few glowing screens and status lights, today's cold blue light). Built in blocks
## like the set: a back wall and a left wall of steel panels with a rail, shelves of glowing sample
## jars, two cable runs on brackets and a conduit, wall screens with readouts, status LEDs and a
## cold strip light along the top. The room's block is room "voxel" (it stands behind the set, in
## the haze). Every size, place and colour: tuning "creation" "lab" "room".

var _vox := VoxelBuilder.new()
var _cfg: Dictionary = {}
var _v := 0.01


static func build(parent: Node3D) -> void:
	var room := CreationRoom.new()
	room._cfg = CreationSet.cfg()["room"]
	room._v = Num.f(room._cfg["voxel"])
	room._walls()
	room._shelves()
	room._cables()
	room._screens()
	room._strip()
	room._vox.inset = CreationSet.gapless()
	var glow := Num.f(CreationSet.cfg()["glow"])
	parent.add_child(room._vox.build({}, room._v, glow, Vector3.ZERO))
	room._lights(parent)


func _c(key: String) -> Color:
	var colors: Dictionary = _cfg["colors"]
	return Color(str(colors[key]))


func _n(metres: float) -> int:
	return roundi(metres / _v)


func _span(raw: Variant) -> Vector2i:
	var pair: Array = raw
	return Vector2i(_n(Num.f(pair[0])), _n(Num.f(pair[1])))


## A cell of the back wall's face (x along it, y up, `out` cells towards the bench).
func _back(x: int, y: int, out: int) -> Vector3i:
	return Vector3i(x, y, _n(Num.f(_cfg["back"]["z"])) + out)


## A cell of the left wall's face (z along it, y up, `out` cells towards the bench).
func _left(z: int, y: int, out: int) -> Vector3i:
	return Vector3i(_n(Num.f(_cfg["left"]["x"])) + out, y, z)


## Both walls: steel panels with dark seams, a rail at rail_y, and a status LED on some panels.
func _walls() -> void:
	var h := _n(Num.f(_cfg["height"]))
	var bx := _span(_cfg["back"]["x"])
	var lz := _span(_cfg["left"]["z"])
	for x: int in range(bx.x, bx.y + 1):
		for y: int in h:
			_panel_cell(_back(x, y, 0), x, y, _back(x, y, 1))
	for z: int in range(lz.x, lz.y + 1):
		for y: int in h:
			_panel_cell(_left(z, y, 0), z, y, _left(z, y, 1))


## One wall cell at `cell` (u along the wall, y up); `front` is the cell before it (rail, LED).
func _panel_cell(cell: Vector3i, u: int, y: int, front: Vector3i) -> void:
	var size: Array = _cfg["panel"]
	var pw := _n(Num.f(size[0]))
	var ph := _n(Num.f(size[1]))
	var rail := _n(Num.f(_cfg["rail_y"]))
	var seam := posmod(u, pw) == 0 or posmod(y, ph) == 0
	var which := absi(hash(Vector2i(floori(u / float(pw)), floori(y / float(ph)))))
	var tone := _c("panel").darkened(0.06 * (which % 3))
	_vox.put_color(cell, _c("seam") if seam else tone)
	if y == rail or y == rail + 1:
		_vox.put_color(front, _c("rail"))
	var led_at := posmod(u, pw) == pw - 3 and posmod(y, ph) == 3
	if led_at and which % 3 == 0:
		var leds: Array = _cfg["leds"]
		var pick := absi(hash(Vector2i(u, y))) % leds.size()
		_vox.put_color(front, Color(Color(str(leds[pick])), 0.0))


## Shelves on the back wall, each a board on two brackets with a row of sample jars.
func _shelves() -> void:
	var s: Dictionary = _cfg["shelves"]
	var xs := _span(s["x"])
	var depth := _n(Num.f(s["depth"]))
	for raw: Variant in s["ys"]:
		var y := _n(Num.f(raw))
		for x: int in range(xs.x, xs.y + 1):
			for d: int in range(1, depth + 1):
				_vox.put_color(_back(x, y, d), _c("shelf"))
		for x: int in [xs.x + 2, xs.y - 2]:
			for k: int in range(1, mini(depth, 6)):
				_vox.put_color(_back(x, y - k, depth + 1 - k - 1), _c("shelf"))
		var every := _n(Num.f(s["jar_every"]))
		for x: int in range(xs.x + 3, xs.y - 4, every):
			_jar(x, y + 1, 2 + absi(hash(Vector2i(x, y))) % maxi(depth - 6, 1))


## A sample jar standing on a shelf at (x, y), `out` cells from the wall: a dark cap, glass edges
## and a glowing liquid of one of the data's tints.
func _jar(x: int, y: int, out: int) -> void:
	var s: Dictionary = _cfg["shelves"]
	var size: Array = s["jar"]
	var w := Num.i(size[0])
	var h := Num.i(size[1])
	var tints: Array = s["tints"]
	var liquid := Color(Color(str(tints[absi(hash(Vector2i(y, x))) % tints.size()])), 0.0)
	var fill := h - 2 - absi(hash(Vector2i(x, y + 7))) % 3
	for dx: int in w:
		for dy: int in h:
			for dz: int in w:
				var corner := (dx == 0 or dx == w - 1) and (dz == 0 or dz == w - 1)
				var col := liquid if dy < fill and not corner else _c("glass")
				if dy == h - 1:
					col = _c("cap")
				_vox.put_color(_back(x + dx, y + dy, out + dz), col)


## Two cable runs along the back wall on brackets, and a conduit up the left wall.
func _cables() -> void:
	var c: Dictionary = _cfg["cables"]
	var bx := _span(_cfg["back"]["x"])
	var every := _n(Num.f(c["bracket_every"]))
	for raw: Variant in c["ys"]:
		var y := _n(Num.f(raw))
		for x: int in range(bx.x, bx.y + 1):
			for dy: int in 2:
				for out: int in [2, 3]:
					_vox.put_color(_back(x, y + dy, out), _c("cable"))
			if posmod(x, every) == 0:
				for dy: int in range(-1, 3):
					_vox.put_color(_back(x, y + dy, 1), _c("rail"))
	var z := _n(Num.f(c["conduit_z"]))
	for y: int in _n(Num.f(_cfg["height"])):
		for dz: int in 2:
			for out: int in [1, 2]:
				_vox.put_color(_left(z + dz, y, out), _c("cable"))


## Wall screens on the left wall: a steel frame round dark glass with rows of lit readout bars.
func _screens() -> void:
	for row: Dictionary in _cfg["screens"]:
		var zs := _span(row["z"])
		var ys := _span(row["y"])
		for z: int in range(zs.x, zs.y + 1):
			for y: int in range(ys.x, ys.y + 1):
				var frame := z == zs.x or z == zs.y or y == ys.x or y == ys.y
				var col := _c("rail")
				if not frame:
					var bar := absi(hash(Vector2i(y, floori(z / 5.0)))) % 3 != 0
					col = Color(_c("readout"), 0.0) if y % 3 == 0 and bar else _c("screen_glass")
				_vox.put_color(_left(z, y, 1), col)


## A cold strip light along the top of the back wall.
func _strip() -> void:
	var bx := _span(_cfg["back"]["x"])
	var y := _n(Num.f(_cfg["strip_y"]))
	for x: int in range(bx.x + 4, bx.y - 3):
		for dy: int in 2:
			_vox.put_color(_back(x, y + dy, 1), Color(_c("strip"), 0.0))


## The strip light's cold wash on the walls.
func _lights(parent: Node3D) -> void:
	for raw: Variant in _cfg["washes"]:
		var wash := OmniLight3D.new()
		wash.light_color = _c("strip")
		wash.light_energy = Num.f(_cfg["wash"])
		wash.omni_range = Num.f(_cfg["wash_range"])
		wash.position = CreationSet.vec(raw)
		wash.shadow_enabled = false
		parent.add_child(wash)
