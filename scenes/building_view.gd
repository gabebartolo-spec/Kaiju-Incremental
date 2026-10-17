class_name BuildingView
extends Node3D
## One building, drawn from two baked meshes (BuildingMesher): its shell, and its floor slabs,
## which stay hidden until it is first broken open. The sim's structural chunks (one sim unit,
## one floor) live in a small `alive` texture the shader reads: a broken chunk is switched off
## there, a bitten one loses a share of its voxels, so nothing is rebuilt mid-rampage. A falling
## part is the same meshes with its own texture (only its chunks on), lifted out to topple over
## its edge (accelerating like a real fall) or drop straight down.

const SHADER := preload("res://scenes/building_baked.gdshader")
const BITTEN := 0.7  # a chunk next to a hole keeps this share of its voxels
const BITE_CHANCE := 0.5  # ...and this share of the chunks next to a hole are bitten

## The party-wall grid's cell size (sim units): a little over a typical lot.
const PARTY_CELL := 8.0
## Building pairs the last party_walls() call compared (tests check it grows about linearly).
static var pair_checks := 0

var b: RampageSim.Building
var voxels: BuildingVoxels
var mesher: BuildingMesher
var _alive: Image
var _alive_tex: ImageTexture
var _slabs: MeshInstance3D
var _shell_mat: ShaderMaterial
var _slab_mat: ShaderMaterial


## party: side (BuildingVoxels.SIDES) -> floors a neighbour covers there. The voxels and meshes are
## built here, so a whole city can be built across worker threads before entering the tree.
func _init(p_building: RampageSim.Building, base: Color, party: Dictionary = {}) -> void:
	b = p_building
	voxels = BuildingVoxels.new(b, base, party)
	mesher = BuildingMesher.new(voxels)
	_alive = Image.create(maxi(1, b.w * b.d * b.height), 1, false, Image.FORMAT_R8)
	_alive.fill(Color(1, 1, 1))
	_alive_tex = ImageTexture.create_from_image(_alive)
	_shell_mat = _material(_alive_tex)
	_slab_mat = _material(_alive_tex)
	add_child(_instance(mesher.shell, _shell_mat))
	_slabs = _instance(mesher.slabs, _slab_mat)
	_slabs.visible = false
	add_child(_slabs)


func _material(tex: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("alive", tex)
	mat.set_shader_parameter("glow", Look.value("window_glow"))
	return mat


func _instance(mesh: ArrayMesh, mat: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi


func _index(c: Vector3i) -> int:
	return c.x + c.z * b.w + c.y * b.w * b.d


func _get_state(c: Vector3i) -> float:
	return _alive.get_pixel(_index(c), 0).r


func _put_state(c: Vector3i, value: float) -> void:
	_alive.set_pixel(_index(c), 0, Color(value, 0, 0))


## Debris sources (world positions and colours) for these chunks.
func _parts(cells: Array[Vector3i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Vector3i in cells:
		for part: Dictionary in mesher.samples.get(_index(c), []):
			out.append(part)
	return out


## Hides these chunks; returns world positions and colours to throw as debris.
func hide_chunks(cells: Array[Vector3i]) -> Array[Dictionary]:
	_slabs.visible = true
	var out := _parts(cells)
	for c: Vector3i in cells:
		_put_state(c, 0.0)
	_alive_tex.update(_alive)
	return out


## Bites ragged edges round a hole: some standing neighbours of the broken chunks lose a share
## of their voxels, so walls look chewed rather than cut along the chunk grid. Cosmetic only;
## the sim's chunks are unchanged.
func chip(broken: Array[Vector3i], rng: RandomNumberGenerator) -> Array[Dictionary]:
	_slabs.visible = true
	var bitten: Array[Vector3i] = []
	for c: Vector3i in broken:
		for d: Vector3i in BuildingMesher.NEIGHBOURS:
			var n := c + d
			if n.x < 0 or n.z < 0 or n.y < 0 or n.x >= b.w or n.z >= b.d or n.y >= b.height:
				continue
			if _get_state(n) > BITTEN + 0.01 and rng.randf() < BITE_CHANCE:
				_put_state(n, BITTEN)
				bitten.append(n)
	_alive_tex.update(_alive)
	var out := _parts(bitten)
	return out.slice(0, floori(out.size() / 3.0))


## Lifts these chunks out into a separate piece pivoting at `pivot` (world); hides them here.
func lift_piece(cells: Array[Vector3i], pivot: Vector3) -> Node3D:
	var piece_alive := Image.create(_alive.get_width(), 1, false, Image.FORMAT_R8)
	piece_alive.fill(Color(0, 0, 0))
	for c: Vector3i in cells:
		piece_alive.set_pixel(_index(c), 0, Color(_get_state(c), 0, 0))
	var parts := hide_chunks(cells)
	var piece := Node3D.new()
	piece.position = pivot
	var tex := ImageTexture.create_from_image(piece_alive)
	for mesh: ArrayMesh in [mesher.shell, mesher.slabs]:
		var mi := _instance(mesh, _material(tex))
		mi.position = -pivot  # the meshes are baked in world space
		piece.add_child(mi)
	piece.set_meta("parts", parts)
	piece.set_meta("pivot", pivot)
	return piece


## Every building's view, its voxels and meshes built across worker threads (thousands of
## voxels each); colors: each building's wall colour.
static func build_all(
	buildings: Array[RampageSim.Building], colors: Array[Color]
) -> Array[BuildingView]:
	var party := party_walls(buildings)
	var built: Array[BuildingView] = []
	built.resize(buildings.size())
	var task := WorkerThreadPool.add_group_task(
		func(i: int) -> void: built[i] = BuildingView.new(buildings[i], colors[i], party[i]),
		buildings.size()
	)
	WorkerThreadPool.wait_for_group_task_completion(task)
	return built


## For each building, side (BuildingVoxels.SIDES) -> how many floors of it a touching
## neighbour covers (the tallest one, where several share the side). Buildings are bucketed in
## a coarse grid first, so each is compared only with those in its own cells: about linear in
## the building count (an Apex city is 2,400 buildings; all pairs would be 5.9M).
static func party_walls(buildings: Array[RampageSim.Building]) -> Array[Dictionary]:
	var grid := {}
	for n: int in buildings.size():
		for cell: Vector2i in _cells(buildings[n]):
			if not grid.has(cell):
				grid[cell] = [] as Array[int]
			var bucket: Array[int] = grid[cell]
			bucket.append(n)
	var out: Array[Dictionary] = []
	pair_checks = 0
	for n: int in buildings.size():
		var a := buildings[n]
		var sides := {}
		var seen := {}
		for cell: Vector2i in _cells(a):
			var bucket: Array[int] = grid[cell]
			for m: int in bucket:
				if m == n or seen.has(m):
					continue
				seen[m] = true
				pair_checks += 1
				var other := buildings[m]
				var gap_x := absf(a.x - other.x) - (a.w + other.w) * 0.5
				var gap_z := absf(a.z - other.z) - (a.d + other.d) * 0.5
				var side := Vector2i.ZERO
				if absf(gap_x) < 0.01 and gap_z < -0.01:
					side = Vector2i(1 if other.x > a.x else -1, 0)
				elif absf(gap_z) < 0.01 and gap_x < -0.01:
					side = Vector2i(0, 1 if other.z > a.z else -1)
				if side != Vector2i.ZERO:
					sides[side] = maxi(Num.i(sides.get(side, 0)), other.height)
		out.append(sides)
	return out


## The grid cells a building's footprint touches, grown a little so touching walls share one.
static func _cells(b: RampageSim.Building) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo := Vector2i(
		floori((b.x - b.w * 0.5 - 0.1) / PARTY_CELL), floori((b.z - b.d * 0.5 - 0.1) / PARTY_CELL)
	)
	var hi := Vector2i(
		floori((b.x + b.w * 0.5 + 0.1) / PARTY_CELL), floori((b.z + b.d * 0.5 + 0.1) / PARTY_CELL)
	)
	for cx: int in range(lo.x, hi.x + 1):
		for cz: int in range(lo.y, hi.y + 1):
			out.append(Vector2i(cx, cz))
	return out
