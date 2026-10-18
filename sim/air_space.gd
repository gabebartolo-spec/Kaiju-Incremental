class_name AirSpace
extends RefCounted
## Where a helicopter may fly (D-066): inside the game camera's frame, clear of the HUD (air.view:
## the camera the view frames by, the safe share of the screen and the HUD's plates), and
## roof_clear over every roof within `facade` metres of where it may be next, so it is never
## beside a tower's face.
## Part of AirWing; pure geometry.

## The cell (metres) the roof heights are looked up by.
const TOP_CELL := 2.0

var sim: RampageSim
var view: Dictionary
var form: Dictionary
var cruise: float  # air.altitude
var _tops := {}  # TOP_CELL cell -> the tallest roof within facade of it (_top_near)
var _safe: Rect2  # the screen kept in sight, and the HUD's plates (shares of the screen)
var _plates: Array[Rect2] = []
var _tan := Vector2.ZERO  # tan of the half field of view, across and up
var _size := 0.0  # half the airframe's box
var _seen_for := Vector3(INF, INF, INF)  # the kaiju (x, z, body scale) the camera is set for
var _eye := Vector3.ZERO
var _fwd := Vector3.ZERO
var _right := Vector3.ZERO
var _up := Vector3.ZERO


func _init(p_sim: RampageSim, cfg: Dictionary) -> void:
	sim = p_sim
	view = cfg["view"]
	form = cfg["formation"]
	cruise = Num.f(cfg["altitude"])
	var safe: Array = view["safe"]
	_safe = _rect(safe)
	for plate: Array in view["hud"]:
		_plates.append(_rect(plate))
	var tan_v := tan(deg_to_rad(Num.f(view["fov"])) * 0.5)
	_tan = Vector2(tan_v * Num.f(view["aspect"]), tan_v)
	_size = Num.f(form["airframe"])


static func _rect(r: Array) -> Rect2:
	var lo := Vector2(Num.f(r[0]), Num.f(r[1]))
	return Rect2(lo, Vector2(Num.f(r[2]), Num.f(r[3])) - lo)


## Where the camera stands and looks for the kaiju as it is now (the view's own numbers).
func camera() -> Array[Vector3]:
	var zoom: Array = view["zoom"]
	var off: Array = view["offset"]
	var bs := sim.body_scale()
	var k := Vector3(sim.kaiju_pos.x, 0.0, sim.kaiju_pos.y)
	var scale := Num.f(zoom[0]) + Num.f(zoom[1]) * bs
	var eye := k + Vector3(Num.f(off[0]), Num.f(off[1]), Num.f(off[2])) * scale
	return [eye, k + Vector3(0.0, Num.f(view["look"]) * bs, 0.0)]


## Does a helicopter at p, alt up, lie inside the safe frame (airframe and rotor all of it)?
func in_frame(p: Vector2, alt: float) -> bool:
	_aim()
	var c := Vector3(p.x, alt, p.y)
	for corner: int in 8:  # the airframe's box, rotor and all, any way it points
		var d := Vector3(1 if corner & 1 else -1, corner >> 2, 1 if corner & 2 else -1)
		var v := c + d * Vector3(_size, _size * 0.5, _size) - _eye
		var depth := v.dot(_fwd)
		if depth <= 0.1:
			return false
		var s := Vector2(0.5 + v.dot(_right) / (depth * _tan.x * 2.0), 0.5)
		s.y -= v.dot(_up) / (depth * _tan.y * 2.0)
		if not _safe.has_point(s):
			return false
		for plate: Rect2 in _plates:
			if plate.has_point(s):
				return false
	return true


## Sets the camera's basis for the kaiju where it is now (once per place and size).
func _aim() -> void:
	var at := Vector3(sim.kaiju_pos.x, sim.kaiju_pos.y, sim.body_scale())
	if at == _seen_for:
		return
	_seen_for = at
	var cam := camera()
	_eye = cam[0]
	_fwd = (cam[1] - cam[0]).normalized()
	_right = _fwd.cross(Vector3.UP).normalized()
	_up = _right.cross(_fwd)


## The farthest out (at most hi, at least lo, a metre at a time) a helicopter on `angle` round
## the kaiju can fly, `up` over the roofs there, and stay in the frame; -1 where none can (a tall
## block: it goes round, not over and out of sight).
func reach(angle: float, lo: float, hi: float, up := 0.0) -> float:
	var dir := Vector2.from_angle(angle)
	var r := hi
	while r >= lo:  # (hi, most often: one look)
		var p := sim.kaiju_pos + dir * r
		if in_frame(p, alt_over([p] as Array[Vector2]) + up):
			return r
		r -= 1.0
	return -1.0


## Cruise altitude, or roof_clear over the tallest building within `facade` of `track` (where it
## will be over the next look_ahead metres), so it is up before it gets there and stays down, in
## sight, away from any tall one.
func alt_over(track: Array[Vector2]) -> float:
	var top := -INF
	for at: Vector2 in track:
		top = maxf(top, _top_near(at))
	return maxf(cruise, top + Num.f(form["roof_clear"]))


## The tallest roof within `facade` of anywhere in p's TOP_CELL cell (buildings keep their
## height for the run, so each cell is looked up once).
func _top_near(p: Vector2) -> float:
	var cell := Vector2i(floori(p.x / TOP_CELL), floori(p.y / TOP_CELL))
	if _tops.has(cell):
		var known: float = _tops[cell]
		return known
	var centre := (Vector2(cell) + Vector2(0.5, 0.5)) * TOP_CELL
	var room := Num.f(form["facade"]) + TOP_CELL * 0.71  # the cell's half-diagonal
	var graph := sim.army_units.convoy.graph
	var top := -INF
	var lo := graph.cell_of(centre - Vector2.ONE * room)
	var hi := graph.cell_of(centre + Vector2.ONE * room)
	for cx: int in range(lo.x, hi.x + 1):
		for cz: int in range(lo.y, hi.y + 1):
			for i: int in graph.lots_at(Vector2i(cx, cz)):
				var b := sim.buildings[i]
				var half := Vector2(b.w, b.d) * 0.5
				var near := centre.clamp(Vector2(b.x, b.z) - half, Vector2(b.x, b.z) + half)
				if near.distance_to(centre) < room:
					top = maxf(top, float(b.height))
	_tops[cell] = top
	return top
