class_name CityGround
extends Node3D
## The ground of the street plan (CityGen.map): asphalt streets, raised pavement blocks, the
## park lawn, the plaza, parking lots with painted bays, the diagonal avenue laid across the
## blocks, quiet road paint, the river the kaiju rises from (CityRiver; its cross streets are
## the bridges), and the bay with its quay to the north. Flat boxes in a
## few MultiMeshes; presentation only.

const PAVE_TOP := 0.1  # blocks stand a kerb above the street
const DIAG_TOP := 0.11  # the diagonal avenue is laid over the blocks it crosses
const PAINT := 0.02
const WATER_Y := -0.8
const RIVER_QUAY := 0.6  # the stone quay wall along each bank, its top a narrow walk
const PARAPET := Vector2(0.9, 0.3)  # a bridge parapet's height over the deck, and its width
const FAR := 1400.0
const MIN_BUILDABLE := 2.0  # the narrowest block CityLots will put a building on
const PAINT_COLOR := Color("8c8a82")  # worn, low-contrast road paint

var plan: Dictionary
var cfg: Dictionary
## Where the land ends and the bay begins (z of the quay); north of it is water.
var coast: float
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
	for land: Rect2 in _cut([Rect2(-FAR, coast, FAR * 2.0, FAR)], channels):
		_slab(land, Vector2(-0.01, 0.4), asphalt.darkened(0.25))
	for land: Rect2 in _cut([Rect2(-outer, coast, outer * 2.0, outer - coast)], channels):
		_slab(land, Vector2(0.001, 0.4), asphalt)
	_lots(asphalt, pavement)
	_river(channels, asphalt, pavement.lightened(0.12))
	_diagonal(asphalt)
	_markings()
	_quay(pavement)
	add_child(_build_slabs())
	add_child(_build_paint())
	add_child(_water())


## Every block's pavement and lot: parks, plazas, parking, the rest paved; the river's own are
## its water and quays (_river).
func _lots(asphalt: Color, pavement: Color) -> void:
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		if rect.position.y < coast:
			continue
		if str(block["use"]) == "outer" and minf(rect.size.x, rect.size.y) < MIN_BUILDABLE:
			continue  # a sliver too thin to build on stays road, not a pale strip
		# The block's pavement reaches out over its sidewalks (and meets across an alley); none
		# over the river's bay the kaiju rises in.
		var walk := CityGen.pavement(block, cfg)
		match str(block["use"]):
			"park":
				_lot(walk, Vector2(PAVE_TOP, 0.3), pavement)
				_lot(rect.grow(-0.5), Vector2(PAVE_TOP + 0.02, 0.3), Look.color("outskirts"))
			"plaza", "landmark":  # a landmark stands on its own plaza
				_lot(walk, Vector2(PAVE_TOP, 0.3), pavement.lightened(0.12))
			"parking":
				_lot(walk, Vector2(PAVE_TOP, 0.3), pavement)
				_lot(rect.grow(-0.6), Vector2(PAVE_TOP + 0.01, 0.3), asphalt.lightened(0.06))
				_parking_bays(rect.grow(-0.6))
			"river":
				pass  # its water and quays: _river
			_:
				_lot(walk, Vector2(PAVE_TOP, 0.3), pavement)


## A block's flat box (_slab), with the river's bay cut out of it.
func _lot(rect: Rect2, y: Vector2, color: Color) -> void:
	for dry: Rect2 in _cut([rect], _basin):
		_slab(dry, y, color)


## A flat box covering rect (x, z); y: (top, thickness); turned by angle about the vertical.
func _slab(rect: Rect2, y: Vector2, color: Color, angle: float = 0.0) -> void:
	var top := y.x
	var thick := y.y
	var centre := rect.get_center()
	var basis := (
		Basis(Vector3.UP, angle) * Basis.from_scale(Vector3(rect.size.x, thick, rect.size.y))
	)
	(
		_slabs
		. append(
			{
				"t": Transform3D(basis, Vector3(centre.x, top - thick * 0.5, centre.y)),
				"c": color,
			}
		)
	)


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
		_slab(Rect2(mid - span * 0.5, span), Vector2(DIAG_TOP, 0.3), asphalt, angle)


## Quiet road paint, readable from the kaiju's height: a dashed centre line on the avenues and
## the diagonal, and zebra crossings (one per arm) only at the few junctions where two avenues
## cross nearest the city centre (city.zebra_junctions). Nothing else gets crossings.
func _markings() -> void:
	var nodes: Array[Vector2] = plan["nodes"]
	var reach := Num.f(cfg["half"]) + Num.f(cfg["markings_beyond"])
	var zebras := zebra_junctions()
	for street: Dictionary in plan["streets"]:
		var kind := str(street["kind"])
		if kind == CityGen.ALLEY:
			continue
		var ends: Array[int] = [Num.i(street["from"]), Num.i(street["to"])]
		var a := nodes[ends[0]]
		var b := nodes[ends[1]]
		if maxf(maxf(absf(a.x), absf(a.y)), maxf(absf(b.x), absf(b.y))) > reach:
			continue
		if minf(a.y, b.y) < coast:
			continue
		var dir := (b - a).normalized()
		var width := Num.f(street["width"])
		var length := a.distance_to(b)
		if kind != CityGen.STREET:
			var lift := DIAG_TOP + PAINT if kind == CityGen.DIAGONAL else PAINT
			_dashes(a, dir * length, width, lift)
		if kind == CityGen.DIAGONAL:
			continue
		for i: int in 2:
			if zebras.has(ends[i]):
				var toward := dir if i == 0 else -dir
				_zebra(nodes[ends[i]] + toward * (width * 0.5 + 0.9), toward, width)


## The junctions that get zebra crossings: where an avenue along x meets one along z, nearest
## the centre first, at most city.zebra_junctions of them.
func zebra_junctions() -> Dictionary:
	var nodes: Array[Vector2] = plan["nodes"]
	var along_x := {}
	var along_z := {}
	for street: Dictionary in plan["streets"]:
		if str(street["kind"]) != CityGen.AVENUE:
			continue
		var ends: Array[int] = [Num.i(street["from"]), Num.i(street["to"])]
		var flat := is_equal_approx(nodes[ends[0]].y, nodes[ends[1]].y)
		for end: int in ends:
			if flat:
				along_x[end] = true
			else:
				along_z[end] = true
	var both: Array[int] = []
	for n: int in along_x:
		if along_z.has(n) and nodes[n].y >= coast:
			both.append(n)
	both.sort_custom(
		func(p: int, q: int) -> bool:
			var dp := nodes[p].length()
			var dq := nodes[q].length()
			if not is_equal_approx(dp, dq):
				return dp < dq
			return nodes[p] < nodes[q]
	)
	var out := {}
	for k: int in mini(Num.i(cfg["zebra_junctions"]), both.size()):
		out[both[k]] = true
	return out


## Dashes down the centre line from a along `span` (direction times length), at height y.
func _dashes(a: Vector2, span: Vector2, width: float, y: float) -> void:
	var dir := span.normalized()
	var length := span.length()
	var angle := -dir.angle() + PI * 0.5
	var gap := width * 0.5 + 2.5  # none in or near the crossings
	var t := gap
	while t < length - gap:
		var p := a + dir * t
		_paint.append(
			Transform3D(
				Basis(Vector3.UP, angle) * Basis.from_scale(Vector3(0.12, 0.04, 0.9)),
				Vector3(p.x, y, p.y)
			)
		)
		t += 3.0


func _zebra(at: Vector2, along: Vector2, width: float) -> void:
	var across := Vector2(-along.y, along.x)
	var angle := -along.angle() + PI * 0.5
	var n := floori(width / 0.6)
	for i: int in n:
		var p := at + across * ((i + 0.5) * 0.6 - width * 0.5)
		_paint.append(
			Transform3D(
				Basis(Vector3.UP, angle) * Basis.from_scale(Vector3(0.3, 0.04, 1.2)),
				Vector3(p.x, PAINT, p.y)
			)
		)


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
	_slab(Rect2(-FAR, coast, FAR * 2.0, 3.0), Vector2(PAVE_TOP + 0.3, 1.6), pavement.darkened(0.15))
	_slab(
		Rect2(-FAR, coast - 0.4, FAR * 2.0, 0.4),
		Vector2(PAVE_TOP + 0.7, 1.0),
		pavement.darkened(0.3)
	)


func _build_slabs() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	box.material = mat
	mm.mesh = box
	mm.instance_count = _slabs.size()
	for i: int in _slabs.size():
		var t: Transform3D = _slabs[i]["t"]
		var c: Color = _slabs[i]["c"]
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, c)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func _build_paint() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PAINT_COLOR
	box.material = mat
	mm.mesh = box
	mm.instance_count = _paint.size()
	for i: int in _paint.size():
		mm.set_instance_transform(i, _paint[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


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
			Rect2(x0, channel.end.y - RIVER_QUAY, channel.size.x, RIVER_QUAY)
		]
		banks.append(Rect2(x0, z0, RIVER_QUAY, channel.size.y))
		banks.append(Rect2(channel.end.x - RIVER_QUAY, z0, RIVER_QUAY, channel.size.y))
		# A wall that runs inside other water (where the bay opens off the channel) is not drawn.
		var others: Array[Rect2] = channels.filter(func(o: Rect2) -> bool: return o != channel)
		for side: Rect2 in _cut(_cut(banks, bridges), others):
			_slab(side, wall, stone)
	CityShore.draw(self, plan, cfg, depth)
	var across := CityRiver.decks_after(plan, cfg, holes)  # east-west decks: parapets along x
	var inside := CityRiver.bay_bridges_ns(plan, cfg)  # the bay's own north-south decks
	var along := bridges.filter(func(d: Rect2) -> bool: return not d in inside)
	along.append_array(CityRiver.decks_after_ns(plan, cfg, holes_ns))
	for deck: Rect2 in along + across:
		_slab(deck, Vector2(0.001, 0.5), asphalt)
		var rail := Vector2(PARAPET.y, deck.size.y)
		var step := Vector2(deck.size.x - PARAPET.y, 0.0)
		if deck in across:
			rail = Vector2(deck.size.x, PARAPET.y)
			step = Vector2(0.0, deck.size.y - PARAPET.y)
		for edge: float in [0.0, 1.0]:
			_slab(Rect2(deck.position + step * edge, rail), Vector2(PARAPET.x, 1.0), stone)
	if not (holes.is_empty() and holes_ns.is_empty()):
		deck_burst = DeckBurst.new(holes, holes_ns, asphalt, stone)
		add_child(deck_burst)


## rects with every hole cut out of them, as the rects left over.
static func _cut(rects: Array[Rect2], holes: Array[Rect2]) -> Array[Rect2]:
	var out: Array[Rect2] = rects.duplicate()
	for hole: Rect2 in holes:
		var left: Array[Rect2] = []
		for r: Rect2 in out:
			var common := r.intersection(hole)
			if not r.intersects(hole) or common.get_area() <= 0.0:
				left.append(r)
				continue
			left.append(Rect2(r.position, Vector2(r.size.x, common.position.y - r.position.y)))
			left.append(Rect2(r.position.x, common.end.y, r.size.x, r.end.y - common.end.y))
			var mid := Rect2(r.position.x, common.position.y, 0.0, common.size.y)
			left.append(Rect2(mid.position, Vector2(common.position.x - r.position.x, mid.size.y)))
			left.append(Rect2(common.end.x, mid.position.y, r.end.x - common.end.x, mid.size.y))
		out.assign(left.filter(func(q: Rect2) -> bool: return q.size.x > 0.0 and q.size.y > 0.0))
	return out


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
