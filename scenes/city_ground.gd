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
const WET_GROUP := "wet_ground"  # the slabs WeatherView wets (ground_slab.gdshader `wet`)
const SLAB_SHADER := preload("res://scenes/ground_slab.gdshader")
const PAINT_COLOR := Color("8c8a82")  # worn, low-contrast road paint
## The shader's uniforms, each read from the look as "ground_<name>" (data/looks.json).
const BLOCK_KEYS: Array[String] = [
	"block",
	"block_noise",
	"patch_noise",
	"speck_chance",
	"speck_dark",
	"seam",
	"fade_near",
	"fade_far",
	"mottle",
	"track",
	"tar",
	"patch_dark",
	"stain",
	"gutter",
	"panel",
	"damp",
	"streak",
	"soil",
	"paving"
]
## What a slab is (ground_slab.gdshader's kind, in the instance custom data) and which way a
## street runs.
const K_ASPHALT := 0
const K_ROAD := 1
const K_PAVEMENT := 2
const K_LAWN := 3
const K_CONCRETE := 4
const K_DECK := 5
const K_PAINT := 6
const ALONG_X := 0
const ALONG_Z := 1
const TURNED := 2
const NO_WATER := -100.0  # a concrete face with no water line
## A street slab lies this far over the land under it (x streets, then z streets over them at a
## junction).
const ROAD_TOP_X := 0.004
const ROAD_TOP_Z := 0.007

var plan: Dictionary
var cfg: Dictionary
## Where the land ends and the bay begins (z of the quay); north of it is water.
var coast: float
var _slabs: Array[Dictionary] = []
var _paint: Array[Transform3D] = []


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
	var channels := CityRiver.channels(plan, cfg)
	for land: Rect2 in _cut([Rect2(-FAR, coast, FAR * 2.0, FAR)], channels):
		_slab(land, Vector2(-0.01, 0.4), asphalt.darkened(0.25), _kind(K_ASPHALT))
	for land: Rect2 in _cut([Rect2(-outer, coast, outer * 2.0, outer - coast)], channels):
		_slab(land, Vector2(0.001, 0.4), asphalt, _kind(K_ASPHALT))
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		if rect.position.y < coast:
			continue
		if str(block["use"]) == "outer" and minf(rect.size.x, rect.size.y) < MIN_BUILDABLE:
			continue  # a sliver too thin to build on stays road, not a pale strip
		# The block's pavement reaches out over its sidewalks (and meets across an alley).
		var walk := CityGen.pavement(block, cfg)
		match str(block["use"]):
			"park":
				_slab(walk, Vector2(PAVE_TOP, 0.3), pavement, _kind(K_PAVEMENT))
				_slab(
					rect.grow(-0.5),
					Vector2(PAVE_TOP + 0.02, 0.3),
					Look.color("outskirts"),
					_kind(K_LAWN)
				)
			"plaza", "landmark":  # a landmark stands on its own plaza
				_slab(walk, Vector2(PAVE_TOP, 0.3), pavement.lightened(0.12), _kind(K_PAVEMENT))
			"parking":
				_slab(walk, Vector2(PAVE_TOP, 0.3), pavement, _kind(K_PAVEMENT))
				_slab(
					rect.grow(-0.6),
					Vector2(PAVE_TOP + 0.01, 0.3),
					asphalt.lightened(0.06),
					_kind(K_ASPHALT)
				)
				_parking_bays(rect.grow(-0.6))
			"river":
				pass  # its water and quays: _river
			_:
				_slab(walk, Vector2(PAVE_TOP, 0.3), pavement, _kind(K_PAVEMENT))
	_roads(channels, asphalt)
	_river(channels, asphalt, pavement.lightened(0.12))
	_diagonal(asphalt)
	_markings()
	_quay(pavement)
	add_child(_build_slabs())
	add_child(_build_paint())
	add_child(_water())


## The streets as slabs of their own over the land (so the lanes, tracks and kerbs of
## ground_slab.gdshader know where each street runs), cut where the river is: an x street at
## ROAD_TOP_X, a z street over it.
func _roads(channels: Array[Rect2], asphalt: Color) -> void:
	var nodes: Array[Vector2] = plan["nodes"]
	for street: Dictionary in plan["streets"]:
		var kind := str(street["kind"])
		if kind == CityGen.DIAGONAL:
			continue  # laid over the blocks by _diagonal
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if minf(a.y, b.y) < coast:
			continue
		var width := Num.f(street["width"])
		var along_x := is_equal_approx(a.y, b.y)
		var centre := a.y if along_x else a.x
		var lo := minf(a.x, b.x) if along_x else minf(a.y, b.y)
		var hi := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
		var span := hi - lo + width  # reaches half a width past each node, into the junction
		var rect := (
			Rect2(lo - width * 0.5, centre - width * 0.5, span, width)
			if along_x
			else Rect2(centre - width * 0.5, lo - width * 0.5, width, span)
		)
		var data := _road_kind(K_ROAD, ALONG_X if along_x else ALONG_Z, centre, width * 0.5)
		for piece: Rect2 in _cut([rect], channels):
			_slab(piece, Vector2(ROAD_TOP_X if along_x else ROAD_TOP_Z, 0.3), asphalt, data)


## Instance custom data for a surface kind (ground_slab.gdshader): `water_y` is a concrete
## face's water line.
static func _kind(kind: int, water_y: float = 0.0) -> Color:
	return Color(float(kind), water_y, 0.0, 0.0)


## A street's custom data: the centre line split into a big and a small part, so the half-float
## instance buffer keeps it exact to a few millimetres.
static func _road_kind(kind: int, axis: int, centre: float, half_width: float) -> Color:
	var big := roundf(centre / 16.0) * 16.0
	return Color(float(kind) + float(axis) / 8.0, big, centre - big, half_width)


## A flat box covering rect (x, z); y: (top, thickness); turned by angle about the vertical.
func _slab(rect: Rect2, y: Vector2, color: Color, kind: Color, angle: float = 0.0) -> void:
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
				"d": kind,
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
		_slab(
			Rect2(mid - span * 0.5, span),
			Vector2(DIAG_TOP, 0.3),
			asphalt,
			_road_kind(K_ROAD, TURNED, 0.0, width * 0.5),
			angle
		)


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
	_slab(
		Rect2(-FAR, coast, FAR * 2.0, 3.0),
		Vector2(PAVE_TOP + 0.3, 1.6),
		pavement.darkened(0.15),
		_kind(K_CONCRETE, WATER_Y)
	)
	_slab(
		Rect2(-FAR, coast - 0.4, FAR * 2.0, 0.4),
		Vector2(PAVE_TOP + 0.7, 1.0),
		pavement.darkened(0.3),
		_kind(K_CONCRETE, WATER_Y)
	)


func _build_slabs() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var box := BoxMesh.new()
	box.material = ground_material(Num.i(cfg["map_seed"]))
	mm.mesh = box
	mm.instance_count = _slabs.size()
	for i: int in _slabs.size():
		var t: Transform3D = _slabs[i]["t"]
		var c: Color = _slabs[i]["c"]
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, c)
		var d: Color = _slabs[i]["d"]
		mm.set_instance_custom_data(i, d)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.add_to_group(WET_GROUP)
	return mmi


## The ground's material (ground_slab.gdshader, the one ground shader) with the look's numbers.
static func ground_material(map_seed: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SLAB_SHADER
	apply_look(mat, map_seed)
	return mat


## The look's ground numbers (surface_detail.gdshaderinc's uniforms) and the city's map seed, so
## the same seed lays the same ground, on a material of any shader that includes the surface
## family.
static func apply_look(mat: ShaderMaterial, map_seed: int) -> void:
	for key: String in BLOCK_KEYS:
		mat.set_shader_parameter(key, Look.value("ground_" + key))
	mat.set_shader_parameter("seed", float(map_seed % 997))


func _build_paint() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	var mat := ground_material(Num.i(cfg["map_seed"]))
	mat.set_shader_parameter("tint", PAINT_COLOR)
	mat.set_shader_parameter("force_kind", float(K_PAINT))
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
		for side: Rect2 in _cut(banks, bridges):
			_slab(side, wall, stone, _kind(K_CONCRETE, -depth))
		_slab(Rect2(x0, z0, RIVER_QUAY, channel.size.y), wall, stone, _kind(K_CONCRETE, -depth))
		_slab(
			Rect2(channel.end.x - RIVER_QUAY, z0, RIVER_QUAY, channel.size.y),
			wall,
			stone,
			_kind(K_CONCRETE, -depth)
		)
	for deck: Rect2 in bridges:
		_abutments(deck, channels, depth, stone)
		_slab(
			deck,
			Vector2(0.001, 0.5),
			asphalt,
			_road_kind(K_DECK, ALONG_Z, deck.get_center().x, deck.size.x * 0.5)
		)
		for x: float in [deck.position.x, deck.end.x - PARAPET.y]:
			_slab(
				Rect2(x, deck.position.y, PARAPET.y, deck.size.y),
				Vector2(PARAPET.x, 1.0),
				stone,
				_kind(K_CONCRETE, NO_WATER)
			)


## The bank walls carried on under a bridge deck, from the deck's underside down to the channel floor,
## so nothing under the deck shows the clear colour behind (a pale slit at the deck's sides).
func _abutments(deck: Rect2, channels: Array[Rect2], depth: float, stone: Color) -> void:
	for channel: Rect2 in channels:
		if not channel.intersects(deck):
			continue
		for z: float in [channel.position.y, channel.end.y - RIVER_QUAY]:
			_slab(
				Rect2(deck.position.x, z, deck.size.x, RIVER_QUAY),
				Vector2(-0.4, depth),
				stone,
				_kind(K_CONCRETE, -depth)
			)


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
