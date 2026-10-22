class_name CitySkyline
extends Node3D
## Everything past the playable edge, so the city has a believable end: to the north a quay,
## the bay and a far skyline; east, west and south the streets run on until the fog takes them.
## The street plan's outer blocks hold cheap stand-in buildings (one painted box each,
## facade.gdshader); an elevated expressway runs along the waterfront; a second skyline across
## the bay has a lattice tower and blinking beacons; lamps glow down the outer streets and a
## few aircraft lights cross the sky. Never destroyed; presentation only.

const FACADE := preload("res://scenes/facade.gdshader")
const FACADE_FAR := preload("res://scenes/facade_far.gdshader")
const DECK_Y := 7.0
const DECK_WIDTH := 5.0
const DETAIL_REACH := 200.0  # roof clutter and lamp heads only this close to the centre
const EXPRESSWAY_CLEAR := 17.0  # no stand-ins this close to the quay, under the expressway
const FREEWAY_CLEAR := 6.0  # ...or this close to a freeway's centre line
const FAR_GRAIN := 1.2  # far facades paint bigger windows, or they shimmer at distance
const TANK := Color("6a5040")  # rooftop water tanks, as on the playable brick buildings
const SUPERTALL := 1.8  # a far tower that is a supertall stands this many times taller
## A capped far shore (cfg far_tower_cap, the title's): towers under this share of the cap stand as
## they were; above it they bend toward the cap and never reach it, so the tall ones stay in order
## and differ (no row of towers cut off at one height).
const CAP_KNEE := 0.6

var cfg: Dictionary
var ground: CityGround
var _rng: RandomNumberGenerator
var _near: Array[Dictionary] = []  # boxes: size, centre, colour, custom
var _far: Array[Dictionary] = []
var _plain: Array[Dictionary] = []  # concrete and hills: transform, colour
var _lamps: Array[Vector3] = []
## Elevated freeways as ground-plane polylines: the waterfront one and two that wind through
## the east and west outskirts, breaking the long straight sightlines down the grid.
var _freeways: Array[PackedVector2Array] = []


func _init(p_ground: CityGround, rng: RandomNumberGenerator) -> void:
	ground = p_ground
	cfg = ground.cfg
	_rng = rng


func _ready() -> void:
	_plan_freeways()
	_outer_blocks()
	for path: PackedVector2Array in _freeways:
		_freeway(path)
	_far_shore()
	_outer_lamps()
	add_child(_facades(_near, 0.0))
	var far := _facades(_far, Num.f(cfg["far_haze"]))
	var far_mesh: BoxMesh = far.multimesh.mesh
	var far_mat: ShaderMaterial = far_mesh.material
	far_mat.set_shader_parameter("grain", FAR_GRAIN)
	add_child(far)
	add_child(_plain_boxes())
	add_child(_lamp_heads())
	add_child(Aircraft.new(_rng))


## Every painted stand-in building (near and far), as {"size": Vector3, "at": Vector3 centre}.
func stand_ins() -> Array[Dictionary]:
	return _near + _far


## Stand-ins on every outer block: the same lots as the playable city, a little lower, with a
## few far tower districts so the skyline rises again past the edge.
func _outer_blocks() -> void:
	var outer_cfg := cfg.duplicate()
	outer_cfg["cores"] = cfg["outer_cores"]
	var styles := Look.styles()
	for block: Dictionary in ground.plan["blocks"]:
		if str(block["use"]) != "outer":
			continue
		var rect: Rect2 = block["rect"]
		if rect.position.y < ground.coast + EXPRESSWAY_CLEAR:
			continue  # the waterfront: the expressway and the quay
		# Blocks differ: some rise, some sit low, so the skyline is never one flat field.
		var scale := _rng.randf_range(0.5, 1.4)
		for lot: Dictionary in CityLots.fill_block(_rng, ground.plan, block, outer_cfg, scale):
			if _under_freeway(Vector2(Num.f(lot["x"]), Num.f(lot["z"]))):
				continue
			var h := Num.f(lot["h"])
			var at := Vector3(Num.f(lot["x"]), h * 0.5, Num.f(lot["z"]))
			var style := Num.i(lot["style"])
			(
				_near
				. append(
					{
						"size": Vector3(Num.f(lot["w"]), h, Num.f(lot["d"])),
						"at": at,
						"color": styles[posmod(style + roundi(at.x * 3.0 + at.z), styles.size())],
						"custom": Color(style % 4, _lit(), 1.0 if h > 18.0 else 0.0, _rng.randf()),
					}
				)
			)
			if Vector2(at.x, at.z).length() < DETAIL_REACH:  # past it the fog hides roofs
				var top := at + Vector3(0, h * 0.5, 0)
				_roof_clutter(top, Vector2(Num.f(lot["w"]), Num.f(lot["d"])))


## Rooftop stair huts, plant boxes and water tanks, so the stand-ins' roofs are not bare.
func _roof_clutter(top: Vector3, size: Vector2) -> void:
	var gear := Look.color("roof").lightened(0.15)
	for n: int in _rng.randi_range(0, 2):
		var s := Vector3(
			_rng.randf_range(0.6, 1.4), _rng.randf_range(0.4, 1.0), _rng.randf_range(0.6, 1.4)
		)
		var off := Vector3(
			_rng.randf_range(-0.5, 0.5) * maxf(0.0, size.x - s.x - 0.6),
			s.y * 0.5,
			_rng.randf_range(-0.5, 0.5) * maxf(0.0, size.y - s.z - 0.6)
		)
		_box(Basis(), AABB(top + off, s), gear if n == 0 else TANK)


func _lit() -> float:
	return Look.value("window_lit") * _rng.randf_range(0.6, 1.4)


func _plan_freeways() -> void:
	var outer := Num.f(cfg["outer_half"]) + 40.0
	var shore := PackedVector2Array()
	var x := -outer
	while x <= outer:
		shore.append(Vector2(x, ground.coast + 9.0 + sin(x / 47.0) * 5.0))
		x += 6.0
	_freeways.append(shore)
	for side: float in [-1.0, 1.0]:  # inland, winding north to south past the city
		var path := PackedVector2Array()
		var z := ground.coast + 9.0
		while z <= outer:
			path.append(Vector2(_inland_x(side, z), z))
			z += 6.0
		_freeways.append(path)


## Where the inland freeway on `side` (-1 west, 1 east) crosses latitude z.
func _inland_x(side: float, z: float) -> float:
	var swing := sin(z / 53.0 + side) * 22.0 + sin(z / 23.0) * 6.0
	return side * (Num.f(cfg["half"]) + 62.0 + swing)


## Whether p is under an inland freeway (no stand-ins there; the waterfront strip is kept
## clear by block).
func _under_freeway(p: Vector2) -> bool:
	for side: float in [-1.0, 1.0]:
		if absf(p.x - _inland_x(side, p.y)) < FREEWAY_CLEAR:
			return true
	return false


## An elevated freeway on pillars along `path` (Tokyo's Shuto), with lamps.
func _freeway(path: PackedVector2Array) -> void:
	var concrete := Look.color("lot").darkened(0.1)
	for i: int in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var mid := (a + b) * 0.5
		var basis := Basis(Vector3.UP, -(b - a).angle())
		var length := a.distance_to(b) + 0.2
		_box(basis, AABB(Vector3(mid.x, DECK_Y, mid.y), Vector3(length, 0.7, DECK_WIDTH)), concrete)
		for side: float in [-1.0, 1.0]:  # parapets
			var off := Vector2(-(b - a).normalized().y, (b - a).normalized().x) * side * 2.3
			var at := Vector3(mid.x + off.x, DECK_Y + 0.65, mid.y + off.y)
			_box(basis, AABB(at, Vector3(length, 0.6, 0.3)), concrete.lightened(0.1))
		if i % 3 == 0:  # a pillar every 18 units, and a lamp on it
			_box(
				Basis(), AABB(Vector3(a.x, DECK_Y * 0.5, a.y), Vector3(1.2, DECK_Y, 1.6)), concrete
			)
			if a.length() < DETAIL_REACH * 1.5:
				_lamps.append(Vector3(a.x, DECK_Y + 2.2, a.y))


## A far tower's height under the cap (cfg far_tower_cap in metres; 0 is no cap, the game's own).
func _capped(tall: float) -> float:
	var cap := Num.f(cfg["far_tower_cap"])
	var knee := cap * CAP_KNEE
	if cap <= 0.0 or tall <= knee:
		return tall
	return knee + (cap - knee) * tanh((tall - knee) / (cap - knee))


## The skyline across the bay: a waterfront of towers, a lattice tower, hazy and lit.
func _far_shore() -> void:
	var shore := ground.coast - Num.f(cfg["bay_width"])
	var styles := Look.styles()
	var concrete := Look.color("lot").darkened(0.2)
	_box(
		Basis(), AABB(Vector3(0, -0.2, shore - 200.0), Vector3(2400.0, 2.0, 400.0)), concrete, true
	)
	var x := -700.0
	while x < 700.0:
		var downtown := maxf(0.0, 1.0 - absf(x - 60.0) / 260.0)
		var rows := 2 + roundi(downtown * 4.0)
		for r: int in rows:
			var w := _rng.randf_range(8.0, 22.0)
			var d := _rng.randf_range(8.0, 20.0)
			var tall := lerpf(8.0, 70.0, pow(downtown, 1.5)) * _rng.randf_range(0.5, 1.4)
			tall = maxf(tall, 6.0)
			tall *= SUPERTALL if _rng.randf() < downtown * 0.15 else 1.0
			tall = _capped(tall)
			var at := Vector3(
				x + _rng.randf_range(-4.0, 4.0), tall * 0.5, shore - 12.0 - r * 26.0 - d * 0.5
			)
			var style := _rng.randi_range(0, 3)
			(
				_far
				. append(
					{
						"size": Vector3(w, tall, d),
						"at": at,
						"color": styles[style % styles.size()].darkened(0.15),
						"custom":
						Color(style, _lit() * 0.7, 1.0 if tall > 60.0 else 0.0, _rng.randf()),
					}
				)
			)
			if tall > 90.0:  # a stepped crown on the supertalls, New York style
				(
					_far
					. append(
						{
							"size": Vector3(w * 0.6, tall * 0.12, d * 0.6),
							"at": at + Vector3(0, tall * 0.56, 0),
							"color": styles[style % styles.size()],
							"custom": Color(style, _lit(), 1.0, _rng.randf()),
						}
					)
				)
		x += _rng.randf_range(14.0, 26.0)
	_lattice_tower(Vector3(-160.0, 0.0, shore - 70.0))


## A red-and-white lattice broadcast tower on the far shore (a Tokyo Tower silhouette).
func _lattice_tower(base: Vector3) -> void:
	var red := Color("b0402c")
	var white := Color("c8c4b8")
	var height := 130.0
	var levels := 26
	for i: int in levels:
		var t := float(i) / levels
		var half_w := lerpf(16.0, 1.2, pow(t, 0.7))
		var y := t * height
		var color := red if posmod(i >> 1, 2) == 0 else white
		for side: int in 4:
			var basis := Basis(Vector3.UP, side * PI * 0.5)
			var leg := basis * Vector3(half_w, 0, half_w)
			var post := Vector3(0.9, height / levels + 0.2, 0.9)
			_box(basis, AABB(base + leg + Vector3(0, y, 0), post), color, true)
			var brace := basis * Vector3(0, 0, half_w)
			_box(
				basis,
				AABB(base + brace + Vector3(0, y, 0), Vector3(half_w * 2.0, 0.5, 0.5)),
				color,
				true
			)
		if i == 9 or i == 17:  # observation decks
			var deck := Vector3(half_w * 2.4, 3.0, half_w * 2.4)
			_box(Basis(), AABB(base + Vector3(0, y, 0), deck), white, true)
	(
		_far
		. append(
			{
				"size": Vector3(1.0, 2.0, 1.0),
				"at": base + Vector3(0, height + 1.0, 0),
				"color": red,
				"custom": Color(0, 0, 1.0, 0.3),
			}
		)
	)


## Glowing lamp heads down the outer streets (no real lights: they only need to twinkle).
func _outer_lamps() -> void:
	var nodes: Array[Vector2] = ground.plan["nodes"]
	var half := Num.f(cfg["half"])
	for street: Dictionary in ground.plan["streets"]:
		if str(street["kind"]) == CityGen.ALLEY:
			continue
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if maxf(absf(a.x), absf(a.y)) <= half + 1.0 and maxf(absf(b.x), absf(b.y)) <= half + 1.0:
			continue  # inside the playable city the decor puts real streetlights
		if minf(a.y, b.y) < ground.coast:
			continue
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x) * (Num.f(street["width"]) * 0.5 + 0.5)
		var t := 3.0
		while t < a.distance_to(b):
			var p := a + dir * t + side
			if p.length() < DETAIL_REACH:
				_lamps.append(Vector3(p.x, 2.6, p.y))
			t += 9.0


## A plain box; box.position is its centre (not a corner), turned by `turn` about the vertical.
func _box(turn: Basis, box: AABB, color: Color, hazy: bool = false) -> void:
	var t := Transform3D(turn * Basis.from_scale(box.size), box.position)
	_plain.append({"t": t, "c": color, "hazy": hazy})


func _facades(boxes: Array[Dictionary], haze: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var mesh := BoxMesh.new()
	mesh.material = facade_material(haze)
	mm.mesh = mesh
	mm.instance_count = boxes.size()
	for i: int in boxes.size():
		var box: Dictionary = boxes[i]
		var size: Vector3 = box["size"]
		var at: Vector3 = box["at"]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(size), at))
		var color: Color = box["color"]
		var custom: Color = box["custom"]
		mm.set_instance_color(i, color)
		mm.set_instance_custom_data(i, custom)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if haze > 0.0:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


static func facade_material(haze: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FACADE_FAR if haze > 0.0 else FACADE
	mat.set_shader_parameter("roof_color", Look.color("roof"))
	mat.set_shader_parameter("window_color", Look.color("window"))
	mat.set_shader_parameter("lit_color", Look.color("window_lit_color"))
	mat.set_shader_parameter("glow", Look.value("window_glow"))
	mat.set_shader_parameter("haze_color", Look.color("fog_color"))
	mat.set_shader_parameter("haze", haze)
	return mat


## Concrete (expressway, the lattice tower, the far shore) and the hills, plain-coloured; the
## hazy ones fade like the far skyline.
func _plain_boxes() -> Node3D:
	var holder := Node3D.new()
	for hazy: bool in [false, true]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		var mesh := BoxMesh.new()
		var mat := facade_material(Num.f(cfg["far_haze"]) * 1.6 if hazy else 0.0)
		mat.set_shader_parameter("plain", true)
		mesh.material = mat
		mm.mesh = mesh
		var picked: Array[Dictionary] = []
		for box: Dictionary in _plain:
			var is_hazy: bool = box["hazy"]
			if is_hazy == hazy:
				picked.append(box)
		mm.instance_count = picked.size()
		for i: int in picked.size():
			var t: Transform3D = picked[i]["t"]
			var c: Color = picked[i]["c"]
			mm.set_instance_transform(i, t)
			mm.set_instance_color(i, c)
			mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mmi)
	return holder


func _lamp_heads() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 0.2, 0.35)
	mesh.material = CityView.glow(Color("ffd59a"), 4.0)
	mm.mesh = mesh
	mm.instance_count = _lamps.size()
	for i: int in _lamps.size():
		mm.set_instance_transform(i, Transform3D(Basis(), _lamps[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
