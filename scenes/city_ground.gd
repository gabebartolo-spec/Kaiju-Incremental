class_name CityGround
extends Node3D
## The ground of the street plan (CityGen.map): asphalt streets, raised pavement blocks, the
## park lawn, the plaza, parking lots with painted bays, the diagonal avenue laid across the
## blocks, quiet road paint, the river the kaiju rises from (CityRiver; its cross streets are
## the bridges), and the bay with its quay to the north. Flat boxes in a
## few MultiMeshes; presentation only.

const PAVE_TOP := 0.1  # blocks stand a kerb above the street
const DIAG_TOP := 0.003  # the diagonal avenue, at street level (DiagonalPaving kerbs it)
const PLAZA_RISE := 0.01  # a plaza's paving over the pavement round it
const PAINT := 0.02
const WATER_Y := -0.8
const RIVER_QUAY := 0.6  # the stone quay wall along each bank, its top a narrow walk
const PARAPET := Vector2(0.9, 0.3)  # a bridge parapet's height over the deck, and its width
const FAR := 1400.0
const WET_GROUP := "wet_ground"  # the slabs WeatherView wets (ground_slab.gdshader `wet`)
const PAINT_COLOR := Color("8c8a82")  # worn, low-contrast road paint
const ROAD_TOP := 0.005  # a street's slab and a junction box, over the land and the diagonal
const CROSSING_TOP := 0.006  # where the diagonal crosses a street, the street's asphalt over both

var plan: Dictionary
var cfg: Dictionary
## Where the land ends and the bay begins (z of the quay); north of it is water.
var coast: float
## The blocks the diagonal crosses, and the river's bank walls under its bridge (DiagonalPaving
## paves them).
var cut_blocks: Array[Dictionary] = []
var cut_walls: Array[Rect2] = []
## The streets' carriageways ({rect, data: kind data}), and the diagonal's pieces as drawn:
## where they cross, RoadJunctions.crossings lays the street's asphalt over both.
var street_pieces: Array[Dictionary] = []
var diagonal_pieces: Array[PackedVector2Array] = []
## The holes the kaiju's rise breaks in the bay's decks (Emergence.burst; set before it is added).
var holes: Array[Rect2] = []
var holes_ns: Array[Rect2] = []  # the same in the north-south decks (Emergence.burst_ns)
var deck_burst: DeckBurst  # the pieces over the holes, broken on the sim's "deck_burst"
var _slabs: Array[Dictionary] = []
var _paint: Array[Transform3D] = []
var _basin: Array[Rect2] = []  # the river's bay the kaiju rises in (CityRiver.bay): no pavement


func _init(p_cfg: Dictionary) -> void:
	cfg = p_cfg
	plan = CityGen.map(cfg)
	coast = Num.f(cfg["coast_z"])


func _ready() -> void:
	var asphalt := Look.color("asphalt")
	var pavement := Look.color("lot")
	var outer := Num.f(cfg["outer_half"])
	# Land: asphalt under everything south of the quay, darker beyond the drawn streets, open
	# where the river runs.
	var channels := CityRiver.water(plan, cfg)
	_basin = CityRiver.bay(plan, cfg)
	for land: Rect2 in GroundKit.cut([Rect2(-FAR, coast, FAR * 2.0, FAR)], channels):
		_of(GroundKit.K_ASPHALT, land, Vector2(-0.01, 0.4), asphalt.darkened(0.25))
	for land: Rect2 in GroundKit.cut([Rect2(-outer, coast, outer * 2.0, outer - coast)], channels):
		_of(GroundKit.K_ASPHALT, land, Vector2(0.001, 0.4), asphalt)
	for block: Dictionary in plan["blocks"]:
		_block(block, asphalt, pavement)
	_roads(channels, asphalt)
	_river(channels, asphalt, pavement.lightened(0.12))
	_diagonal(asphalt)
	_markings()
	_quay(pavement)
	var mat := _slab_material()
	var colors := {"pavement": pavement, "asphalt": asphalt, "stone": pavement.lightened(0.12)}
	for mmi: MultiMeshInstance3D in DiagonalPaving.meshes(self, colors, mat):
		mmi.add_to_group(WET_GROUP)
		add_child(mmi)
	add_child(_build_slabs(mat))
	add_child(_build_paint())
	add_child(_water())


## One block's pavement, and what stands on it (lawn, plaza, parking bays).
func _block(block: Dictionary, asphalt: Color, pavement: Color) -> void:
	var rect: Rect2 = block["rect"]
	if rect.position.y < coast:
		return
	# The block's pavement reaches out over its sidewalks (and meets across an alley); a sliver
	# too thin to build on is a kerbed pavement island, never open asphalt (roads suite R4).
	var walk := CityGen.pavement(block, cfg)
	if str(block["use"]) != "river" and DiagonalPaving.cuts(plan, block, cfg):
		cut_blocks.append(block)
		return
	var kerb := Vector2(PAVE_TOP, 0.3)
	match str(block["use"]):
		"park":
			_of(GroundKit.K_PAVEMENT, walk, kerb, pavement)
			_of(
				GroundKit.K_LAWN,
				rect.grow(-0.5),
				kerb + Vector2(0.02, 0.0),
				Look.color("outskirts")
			)
		"plaza", "landmark":  # a landmark stands on its own plaza, a pavement round it
			_of(GroundKit.K_PAVEMENT, walk, kerb, pavement)
			var rise := kerb + Vector2(PLAZA_RISE, 0.0)
			_of(GroundKit.K_PAVEMENT, plaza(walk, cfg), rise, pavement.lightened(0.12))
		"parking":
			_of(GroundKit.K_PAVEMENT, walk, kerb, pavement)
			var bay := rect.grow(-0.6)
			_of(GroundKit.K_ASPHALT, bay, kerb + Vector2(0.01, 0.0), asphalt.lightened(0.06))
			_parking_bays(bay)
		"river":
			pass  # its water and quays: _river
		_:
			_of(GroundKit.K_PAVEMENT, walk, kerb, pavement)


## A concrete face; water_y is its water line.
func _face(rect: Rect2, y: Vector2, color: Color, water_y: float) -> void:
	_slab(rect, y, color, GroundKit.kind(GroundKit.K_CONCRETE, water_y))


## A slab of a surface kind (GroundKit.K_*), with the river's bay cut out of it.
func _of(kind: int, rect: Rect2, y: Vector2, color: Color) -> void:
	for dry: Rect2 in GroundKit.cut([rect], _basin):
		_slab(dry, y, color, GroundKit.kind(kind))


## The streets as slabs of their own over the land (so the lanes, tracks and kerbs of
## ground_slab.gdshader know where each street runs), cut where the river is, meeting at plain
## junction boxes (RoadJunctions: one surface where two roads meet, roads suite R6).
func _roads(channels: Array[Rect2], asphalt: Color) -> void:
	var junctions := RoadJunctions.boxes(plan, coast)
	var y := Vector2(ROAD_TOP, 0.3)
	for street: Dictionary in RoadJunctions.streets(plan, coast, junctions):
		var axis := GroundKit.ALONG_X if Num.i(street["axis"]) == 0 else GroundKit.ALONG_Z
		var half := Num.f(street["half"])
		var data := GroundKit.road_kind(GroundKit.K_ROAD, axis, Num.f(street["centre"]), half)
		var rect: Rect2 = street["rect"]
		for piece: Rect2 in GroundKit.cut([rect], channels):
			_slab(piece, y, asphalt, data)
			street_pieces.append({"rect": piece, "data": data})
	for n: int in junctions:
		var half: Vector2 = junctions[n]
		var box := RoadJunctions.box_rect(plan, n, half)
		for piece: Rect2 in GroundKit.cut([box], channels):
			_of(GroundKit.K_JUNCTION, piece, y, asphalt)


## A flat box covering rect (x, z); y: (top, thickness).
func _slab(rect: Rect2, y: Vector2, color: Color, kind: Color) -> void:
	_put(rect, y, 0.0, [color, kind])


## The same turned by angle about the vertical; paint is [colour, kind data].
func _put(rect: Rect2, y: Vector2, angle: float, paint: Array) -> void:
	var top := y.x
	var thick := y.y
	var centre := rect.get_center()
	var basis := (
		Basis(Vector3.UP, angle) * Basis.from_scale(Vector3(rect.size.x, thick, rect.size.y))
	)
	var t := Transform3D(basis, Vector3(centre.x, top - thick * 0.5, centre.y))
	_slabs.append({"t": t, "c": paint[0], "d": paint[1]})


## A plaza's paving: its pavement less a sidewalk's width all round, so a road's asphalt meets a
## kerbed pavement, never the plaza (roads suite R4).
static func plaza(walk: Rect2, p_cfg: Dictionary) -> Rect2:
	return walk.grow(-Num.f(p_cfg["sidewalk"]))


func _diagonal(asphalt: Color) -> void:
	var nodes: Array[Vector2] = plan["nodes"]
	for street: Dictionary in plan["streets"]:
		if str(street["kind"]) != CityGen.DIAGONAL:
			continue
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if minf(a.y, b.y) < coast:
			continue
		var width := Num.f(street["width"])
		var mid := (a + b) * 0.5
		var length := a.distance_to(b) + width  # overlap the next piece at the crossings
		var angle := -(b - a).angle()
		var span := Vector2(length, width)
		var data := GroundKit.road_kind(GroundKit.K_ROAD, GroundKit.TURNED, 0.0, width * 0.5)
		_put(Rect2(mid - span * 0.5, span), Vector2(DIAG_TOP, 0.3), angle, [asphalt, data])
		var dir := (b - a).normalized() * length * 0.5
		var side := Vector2(-dir.y, dir.x).normalized() * width * 0.5
		diagonal_pieces.append(
			PackedVector2Array(
				[mid - dir - side, mid + dir - side, mid + dir + side, mid - dir + side]
			)
		)


## Quiet road paint (RoadPaint): dashes and the central junction's zebras.
func _markings() -> void:
	_paint.append_array(RoadPaint.new(plan, cfg, coast).marks())


## The junctions that get zebra crossings (RoadPaint.zebra_junctions).
func zebra_junctions() -> Dictionary:
	return RoadPaint.new(plan, cfg, coast).zebra_junctions()


func _parking_bays(rect: Rect2) -> void:
	var x := rect.position.x + 1.0
	while x < rect.end.x - 0.5:
		for z: float in [rect.position.y + 1.2, rect.end.y - 1.2]:
			_paint.append(
				Transform3D(
					Basis.from_scale(Vector3(0.1, 0.04, 2.2)), Vector3(x, PAVE_TOP + 0.03, z)
				)
			)
		x += 1.3


## The quay: a concrete edge where the city meets the bay.
func _quay(pavement: Color) -> void:
	_slab(
		Rect2(-FAR, coast, FAR * 2.0, 3.0),
		Vector2(PAVE_TOP + 0.3, 1.6),
		pavement.darkened(0.15),
		GroundKit.kind(GroundKit.K_CONCRETE, WATER_Y)
	)
	_slab(
		Rect2(-FAR, coast - 0.4, FAR * 2.0, 0.4),
		Vector2(PAVE_TOP + 0.7, 1.0),
		pavement.darkened(0.3),
		GroundKit.kind(GroundKit.K_CONCRETE, WATER_Y)
	)


## The ground's material, its river level set.
func _slab_material() -> ShaderMaterial:
	var mat := GroundKit.material(Num.i(cfg["map_seed"]))
	mat.set_shader_parameter("river_y", -Num.f(cfg.get("river_depth", 0.0)))
	return mat


func _build_slabs(mat: ShaderMaterial) -> MultiMeshInstance3D:
	var mmi := GroundKit.slab_instances(_slabs, mat)
	mmi.add_to_group(WET_GROUP)
	return mmi


func _build_paint() -> MultiMeshInstance3D:
	var mat := GroundKit.material(Num.i(cfg["map_seed"]))
	mat.set_shader_parameter("tint", PAINT_COLOR)
	mat.set_shader_parameter("force_kind", float(GroundKit.K_PAINT))
	return GroundKit.paint_instances(_paint, mat)


## The bay: dark, glossy water reaching to the horizon north of the quay.
func _water() -> MeshInstance3D:
	return _sheet(
		Rect2(-FAR * 2.0, coast - FAR * 2.0, FAR * 4.0, FAR * 2.0), WATER_Y, Look.color("water")
	)


## The river (CityRiver): a channel sunk city "river_depth" below the street, glossy water
## bluer and lighter than the bay's between stone quay walls, running on under its bridges:
## a deck at street level with a parapet along each side for every street that crosses it.
func _river(channels: Array[Rect2], asphalt: Color, stone: Color) -> void:
	var depth := Num.f(cfg.get("river_depth", 0.0))
	var bridges := CityRiver.bridges(plan, cfg)
	var wall := Vector2(PAVE_TOP, depth + 0.5)
	for channel: Rect2 in channels:
		add_child(_sheet(channel, -depth, Look.color("river")))
		var x0 := channel.position.x
		var z0 := channel.position.y
		var banks: Array[Rect2] = [
			Rect2(x0, z0, channel.size.x, RIVER_QUAY),
			Rect2(x0, channel.end.y - RIVER_QUAY, channel.size.x, RIVER_QUAY),
			Rect2(x0, z0, RIVER_QUAY, channel.size.y),
			Rect2(channel.end.x - RIVER_QUAY, z0, RIVER_QUAY, channel.size.y)
		]
		# A wall that runs inside other water (where the bay opens off the channel) is not drawn.
		var others: Array[Rect2] = channels.filter(func(o: Rect2) -> bool: return o != channel)
		var diagonal := DiagonalPaving.band(plan, cfg, 0.0)
		for side: Rect2 in GroundKit.cut(GroundKit.cut(banks, bridges), others):
			if DiagonalPaving.pieces(side, diagonal).size() == 1 and _whole(side, diagonal):
				_face(side, wall, stone, -depth)
			else:
				cut_walls.append(side)
	CityShore.draw(self, plan, cfg, depth)
	var over := CityRiver.diagonal_deck(plan, cfg)
	if not over.is_empty():
		_diagonal_deck(over, channels[0], [asphalt, stone])
	var inside := CityRiver.bay_bridges_ns(plan, cfg)  # the bay's own north-south decks
	var along := bridges.filter(func(d: Rect2) -> bool: return not d in inside)
	along.append_array(CityRiver.decks_after_ns(plan, cfg, holes_ns))
	for deck: Rect2 in along:
		_bridge(deck, channels, asphalt, stone, false)
	for deck: Rect2 in CityRiver.decks_after(plan, cfg, holes):  # east-west decks over the bay
		_bridge(deck, [], asphalt, stone, true)
	if not (holes.is_empty() and holes_ns.is_empty()):
		deck_burst = DeckBurst.new(holes, holes_ns, asphalt, stone)
		add_child(deck_burst)


## A street's bridge: its deck at street level, a parapet along each side, the bank walls
## carried on under it. across: an east-west deck (over the bay), its parapets along x.
func _bridge(
	deck: Rect2, channels: Array[Rect2], asphalt: Color, stone: Color, across: bool
) -> void:
	var depth := Num.f(cfg.get("river_depth", 0.0))
	_abutments(deck, channels, depth, stone)
	var axis := GroundKit.ALONG_X if across else GroundKit.ALONG_Z
	var mid := deck.get_center().y if across else deck.get_center().x
	var half := (deck.size.y if across else deck.size.x) * 0.5
	var top := GroundKit.road_kind(GroundKit.K_DECK, axis, mid, half)
	_slab(deck, Vector2(0.001, depth - 0.2), asphalt, top)
	var rail := Vector2(deck.size.x, PARAPET.y) if across else Vector2(PARAPET.y, deck.size.y)
	var step := deck.size - rail
	for edge: float in [0.0, 1.0]:
		var at := Rect2(deck.position + step * edge, rail)
		_face(at, Vector2(PARAPET.x, 1.0), stone, GroundKit.NO_WATER)


## The bank walls carried on under a bridge deck, from its underside down to the channel floor, so
## nothing under it shows the clear colour behind (a pale slit at the deck's sides).
func _abutments(deck: Rect2, channels: Array[Rect2], depth: float, stone: Color) -> void:
	for channel: Rect2 in channels:
		if not channel.intersects(deck):
			continue
		for z: float in [channel.position.y, channel.end.y - RIVER_QUAY]:
			_face(
				Rect2(deck.position.x, z, deck.size.x, RIVER_QUAY),
				Vector2(-0.4, depth),
				stone,
				-depth
			)


## The diagonal's bridge (CityRiver.diagonal_deck): its deck at the avenue's level with a parapet
## along each side, each running only over the channel (`water`, quays included), so neither
## crosses a street along the bank. colors: [asphalt, stone].
func _diagonal_deck(over: Dictionary, water: Rect2, colors: Array[Color]) -> void:
	var asphalt := colors[0]
	var stone := colors[1]
	var a: Vector2 = over["from"]
	var b: Vector2 = over["to"]
	var width := Num.f(over["width"])
	var angle := -(b - a).angle()
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var mid := (a + b) * 0.5
	var deck := Vector2(length, width)
	var top := GroundKit.road_kind(GroundKit.K_DECK, GroundKit.TURNED, 0.0, width * 0.5)
	_put(Rect2(mid - deck * 0.5, deck), Vector2(DIAG_TOP, 0.5), angle, [asphalt, top])
	var face := GroundKit.kind(GroundKit.K_CONCRETE, GroundKit.NO_WATER)
	for side: float in [-1.0, 1.0]:
		var line := mid + Vector2(-dir.y, dir.x) * side * (width - PARAPET.y) * 0.5
		# Where this parapet's line crosses the channel's two banks (z), as distances along dir.
		var t0 := (water.position.y - line.y) / dir.y
		var t1 := (water.end.y - line.y) / dir.y
		var at := line + dir * (t0 + t1) * 0.5
		var rail := Vector2(absf(t1 - t0), PARAPET.y)
		_put(Rect2(at - rail * 0.5, rail), Vector2(PARAPET.x, 1.0), angle, [stone, face])


## True when polygon `cut` leaves all of rect (they do not overlap).
static func _whole(rect: Rect2, cut: PackedVector2Array) -> bool:
	var left := DiagonalPaving.pieces(rect, cut)
	return absf(_area(left[0]) - rect.get_area()) < 0.001


static func _area(poly: PackedVector2Array) -> float:
	var out := 0.0
	for k: int in poly.size():
		out += poly[k].cross(poly[(k + 1) % poly.size()])
	return absf(out) * 0.5


## Glossy water of `color` over rect (x, z) at height y.
func _sheet(rect: Rect2, y: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = rect.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.12
	mat.metallic_specular = 0.8
	plane.material = mat
	mi.mesh = plane
	var mid := rect.get_center()
	mi.position = Vector3(mid.x, y, mid.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
