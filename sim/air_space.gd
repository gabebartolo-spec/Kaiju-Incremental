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


func _init(p_sim: RampageSim, cfg: Dictionary) -> void:
	sim = p_sim
	view = cfg["view"]
	form = cfg["formation"]
	cruise = Num.f(cfg["altitude"])


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
	var cam := camera()
	var fwd := (cam[1] - cam[0]).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd)
	var tan_v := tan(deg_to_rad(Num.f(view["fov"])) * 0.5)
	var tan_h := tan_v * Num.f(view["aspect"])
	var safe: Array = view["safe"]
	var size := Num.f(form["airframe"])
	var c := Vector3(p.x, alt, p.y)
	for corner: int in 8:  # the airframe's box, rotor and all, any way it points
		var d := Vector3(1 if corner & 1 else -1, corner >> 2, 1 if corner & 2 else -1)
		var v := c + d * Vector3(size, size * 0.5, size) - cam[0]
		var depth := v.dot(fwd)
		if depth <= 0.1:
			return false
		var sx := 0.5 + v.dot(right) / (depth * tan_h * 2.0)
		var sy := 0.5 - v.dot(up) / (depth * tan_v * 2.0)
		if not _on_screen(Vector2(sx, sy), safe):
			return false
		for plate: Array in view["hud"]:
			if _on_screen(Vector2(sx, sy), plate):
				return false
	return true


## Is screen point s (shares of the screen) inside rect [x0, y0, x1, y1]?
static func _on_screen(s: Vector2, rect: Array) -> bool:
	var lo := Vector2(Num.f(rect[0]), Num.f(rect[1]))
	return s.x >= lo.x and s.y >= lo.y and s.x <= Num.f(rect[2]) and s.y <= Num.f(rect[3])


## The farthest out (at most hi, at least lo, a metre at a time) a helicopter on `angle` round
## the kaiju can fly, `up` over the roofs there, and stay in the frame; -1 where none can (a tall
## block: it goes round, not over and out of sight).
func reach(angle: float, lo: float, hi: float, up := 0.0) -> float:
	var dir := Vector2.from_angle(angle)
	var r := hi
	while r >= lo:
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
