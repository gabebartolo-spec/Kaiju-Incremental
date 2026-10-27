class_name CityFalls
extends RefCounted
## CityView's falling sections (split out of it, destruction plan stage 1): a section the sim
## lets go (fall_start) becomes a piece, drawn from exactly its own fine cells when the building
## is drawn from them (CityCarve.piece), else from its chunks' voxels (BuildingView.lift_piece);
## gravity drives it each frame (a topple's hinge: ToppleFx) and where it lands (fall_land) it
## bursts into debris and dust and crushes what it covers. Presentation only.

const DEBRIS_PER_LANDING := 160
const DROP_REACH := 0.8  # a dropped section crushes people this far out from its walls

## Fall id -> {"node", "kind", "dir", "drop", "duration", "t"} (CityView._falling; tools read it).
var falling: Dictionary = {}

var _city: CityView
var _stream: BuildingStream
var _topple: ToppleFx
var _rng: RandomNumberGenerator


func _init(
	city: CityView, stream: BuildingStream, topple: ToppleFx, rng: RandomNumberGenerator
) -> void:
	_city = city
	_stream = stream
	_topple = topple
	_rng = rng


## A section starts to fall: its piece topples or drops from the pivot.
func start(event: Dictionary) -> void:
	var index := Num.i(event["building"])
	var pivot: Vector3 = event["pivot"]
	var piece: Node3D = _city.carve.piece(event) if _city.carve != null else null
	if piece == null:
		var cells: Array[Vector3i] = event["cells"]
		piece = _stream.view(index).lift_piece(cells, pivot)
	if LandmarkBurst.bursts(_city.sim, event):  # a landmark's section bursts where it stands
		piece = LandmarkBurst.new(piece, _city, event)
	_city.add_child(piece)
	falling[Num.i(event["id"])] = {
		"node": piece,
		"kind": str(event["kind"]),
		"dir": event["dir"],
		"drop": Num.f(event["drop"]),
		"duration": maxf(0.05, Num.f(event["duration"])),
		"t": 0.0,
	}
	_city.fx.dust(pivot + Vector3(0, 0.5, 0), 1.0)
	if _city.street != null:  # the people under it freeze; its landing crushes the same reach
		_city.street.brace_fall(event, DROP_REACH)


## Gravity drives it: the angle (topple) or the drop grows with the square of time.
func animate(delta: float) -> void:
	for id: int in falling:
		var f: Dictionary = falling[id]
		var node: Node3D = f["node"]
		f["t"] = Num.f(f["t"]) + delta
		var k := clampf(Num.f(f["t"]) / Num.f(f["duration"]), 0.0, 1.0)
		if str(f["kind"]) == "topple":
			_topple.pose(f, delta)
		else:
			node.position.y = (
				node.position.y - (Num.f(f["drop"]) * k * k - Num.f(f.get("dropped", 0.0)))
			)
			f["dropped"] = Num.f(f["drop"]) * k * k


## A section hit the ground (or what was below it): it bursts into debris and dust.
func land(event: Dictionary) -> void:
	var id := Num.i(event["id"])
	if not falling.has(id):
		return
	var f: Dictionary = falling[id]
	falling.erase(id)
	var node: Node3D = f["node"]
	var parts: Array = node.get_meta("parts", [])
	if str(event["kind"]) == "topple" and not (node is LandmarkBurst):
		_topple_land(node, event)
		return
	var landed: Array[Vector3] = []
	for n: int in mini(parts.size(), DEBRIS_PER_LANDING):
		var part: Dictionary = parts[_rng.randi_range(0, parts.size() - 1)]
		var pos: Vector3 = part["pos"]
		var pivot: Vector3 = node.get_meta("pivot")
		var at := node.global_transform * (pos - pivot)
		landed.append(at)
		var color: Color = part["color"]
		_city.debris(at, color, Vector3.UP)
	var b := _city.sim.buildings[Num.i(event["building"])]
	if b.landmark != "":
		LandmarkBurst.retire(node, true)
	else:
		_topple.crumble(node)  # crumbles into the street over a moment, never a one-frame pop
	if not landed.is_empty():
		_city.fx.dust(landed[0], 1.5)
		var street := _city.street
		if street != null and b.landmark == "":  # came down round its own (not a ring's) walls
			var spill := Num.f(street.tune("fall_spill"))
			street.crush(Vector3(b.x, 0, b.z), maxf(b.w, b.d) * 0.5 + DROP_REACH + spill)


## A tower came down across the street: it breaks up and leaves a rubble strip (ToppleFx); what
## the strip covers is crushed.
func _topple_land(node: Node3D, event: Dictionary) -> void:
	_topple.land(node, event, _stream.view(Num.i(event["building"])).voxels)
	var from: Vector2 = event["from"]
	var to: Vector2 = event["to"]
	var width := Num.f(event["width"])
	var a := Vector3(from.x, 0, from.y)
	var b := Vector3(to.x, 0, to.y)
	var steps := maxi(1, ceili(a.distance_to(b) / 1.5))
	var street := _city.street
	var spill := Num.f(street.tune("fall_spill")) if street != null else 0.0
	var spots: Array[Vector3] = []
	for i: int in steps + 1:
		var at := a.lerp(b, float(i) / steps)
		spots.append(Vector3(at.x, at.z, width * 0.6 + spill))
	_city.crush_all(spots)
