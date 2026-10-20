extends RefCounted
## Pure helpers for the landmark cells suite (tests/run_landmarkcells_tests.gd): digests, the
## independent colour classifier, cell/chunk maths and the no-clock grep. Split out for gdlint's
## 400-line file cap.

const FORBIDDEN: Array[String] = [
	"randi(",
	"randf(",
	"randomize(",
	"RandomNumberGenerator",
	"Seeds.",
	"Time.",
	"OS.",
	"Engine.",
	"Look.",
	"Node",
	"await ",
	"scenes/",
]


static func digest(g: CellGrid) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes([g.dims, g.offset]))
	ctx.update(g.cells)
	return ctx.finish().hex_encode().substr(0, 16)


## The class a baked colour falls in, worked out here on 0-255 channels (the module uses floats).
static func class_of(c: Color, ground: Array) -> String:
	var r := c.r8
	var g := c.g8
	var b := c.b8
	for key: Variant in ground:
		var k := Color(str(key))
		if maxi(absi(r - k.r8), maxi(absi(g - k.g8), absi(b - k.b8))) <= 24:
			return "landmark_pitch"
	if maxi(r, maxi(g, b)) - mini(r, mini(g, b)) <= 30:
		return "landmark_wall"
	if r - g >= 77 and r - b >= 77:
		return "landmark_seat"
	return "landmark_other"


static func chunk(cell: Vector3i) -> Vector3i:
	var r := CellGrid.cell_res()
	return Vector3i(floori(float(cell.x) / r), floori(float(cell.y) / r), floori(float(cell.z) / r))


## The building-local cell of grid index i.
static func cell(g: CellGrid, i: int) -> Vector3i:
	var plan := g.dims.x * g.dims.z
	return Vector3i(i % g.dims.x, i / plan, (i / g.dims.x) % g.dims.z) + g.offset


## The four landmark_ classes exist in data/materials.json and the grids use all four.
static func forbidden(text: String) -> Array[String]:
	var hits: Array[String] = []
	for line: String in text.split("\n"):
		var code := line.get_slice("#", 0)
		for token: String in FORBIDDEN:
			if code.contains(token):
				hits.append("%s: %s" % [token, line.strip_edges()])
	return hits
