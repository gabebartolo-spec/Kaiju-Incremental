class_name PitchProps
extends RefCounted
## One sport's markings and posts on the stadium's pitch (D-078, data/sports.json), as one voxel
## mesh at the buildings' scale (RES cells per sim unit): lines one cell proud of the grass,
## posts one cell thick. Cell (0, 0, 0) sits on the grass at the pitch's centre; +x runs to
## the ends (the posts), z across. Presentation only.

const RES := BuildingVoxels.RES
## A rectangular field's share of the pitch's half size (it fits inside the oval stands).
const RECT := 0.82


## The field's half size in cells: the whole pitch for an oval sport, else the rectangle.
static func field(sport: Dictionary, half: Vector2) -> Vector2i:
	var share := 1.0 if str(sport["shape"]) == "oval" else RECT
	return Vector2i(roundi(half.x * RES * share), roundi(half.y * RES * share))


static func mesh(sport: Dictionary, half: Vector2, voxel: float) -> ArrayMesh:
	var v := VoxelBuilder.new()
	var f := field(sport, half)
	if str(sport["shape"]) == "oval":
		_ellipse(v, Vector2(f), "line")
	else:
		_rect(v, -f, f)
		_line_z(v, 0, f.y)  # halfway
	match str(sport["posts"]):
		"afl":
			_ellipse(v, Vector2(3, 3), "line")  # centre circle
			for end: int in [-1, 1]:
				for z: int in [-3, 3]:
					_post(v, Vector2i(end * f.x, z), 13)  # goal posts
				for z: int in [-8, 8]:
					_post(v, Vector2i(end * f.x, z), 8)  # behind posts
		"uprights":
			for k: int in range(1, 10):  # yard lines between the end zones
				_line_z(v, -f.x + roundi(f.x * 2.0 * k / 10.0), f.y)
			for end: int in [-1, 1]:
				var x := end * (f.x + 1)
				_post(v, Vector2i(x, 0), 5)
				v.box(Vector3i(x, 5, -3), Vector3i(x, 5, 3), "post")  # crossbar
				for z: int in [-3, 3]:
					v.box(Vector3i(x, 6, z), Vector3i(x, 14, z), "post")
		"goals":
			_ellipse(v, Vector2(4, 4), "line")
			for end: int in [-1, 1]:
				_rect(v, Vector2i(end * f.x - end * 7, -9), Vector2i(end * f.x, 9))  # penalty box
				var x := end * (f.x + 1)
				for z: int in [-3, 3]:
					_post(v, Vector2i(x, z), 3)
				v.box(Vector3i(x, 3, -3), Vector3i(x, 3, 3), "post")
		"stumps":
			v.box(Vector3i(-10, 0, -1), Vector3i(10, 0, 1), "strip")  # the pitch strip
			for end: int in [-1, 1]:
				_line_z(v, end * 8, 2)  # crease
				for z: int in [-1, 0, 1]:
					v.box(Vector3i(end * 9, 1, z), Vector3i(end * 9, 3, z), "post")
	var palette := {
		"line": Color(str(sport["line"])),
		"post": Color(str(sport["post_color"])),
		"strip": Color(str(sport.get("strip", sport["line"]))),
	}
	return v.bake(palette, voxel, Vector3.ZERO, 0.0)


static func _ellipse(v: VoxelBuilder, radii: Vector2, key: String) -> void:
	var steps := maxi(24, roundi((radii.x + radii.y) * 4.0))
	for k: int in steps:
		var a := TAU * k / steps
		v.put(Vector3i(roundi(radii.x * cos(a)), 0, roundi(radii.y * sin(a))), key)


static func _rect(v: VoxelBuilder, a: Vector2i, b: Vector2i) -> void:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	v.box(Vector3i(lo.x, 0, lo.y), Vector3i(hi.x, 0, lo.y), "line")
	v.box(Vector3i(lo.x, 0, hi.y), Vector3i(hi.x, 0, hi.y), "line")
	v.box(Vector3i(lo.x, 0, lo.y), Vector3i(lo.x, 0, hi.y), "line")
	v.box(Vector3i(hi.x, 0, lo.y), Vector3i(hi.x, 0, hi.y), "line")


static func _line_z(v: VoxelBuilder, x: int, half_z: int) -> void:
	v.box(Vector3i(x, 0, -half_z), Vector3i(x, 0, half_z), "line")


static func _post(v: VoxelBuilder, at: Vector2i, cells: int) -> void:
	v.box(Vector3i(at.x, 0, at.y), Vector3i(at.x, cells - 1, at.y), "post")
