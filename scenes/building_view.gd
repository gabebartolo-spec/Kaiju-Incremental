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

## Building pairs the last party_walls() call compared (tests check it grows about linearly).
static var pair_checks := 0
## A building's voxels and meshes never change in a rampage (damage is the alive texture), and
## every run of a stage builds the same city, so they are kept for the next run (director's
## playtest: "load times when you start a run could be quicker"). Key: _key().
static var _baked: Dictionary = {}
static var _baked_lock := Mutex.new()
## The city being built (begin_city); an entry not used by it is dropped at end_city, so only
## the current city's buildings stay in memory as the city grows between runs.
static var _generation := 0

var b: RampageSim.Building
## The building's fine voxels, rebuilt (the build is deterministic) the first time something needs
## them after meshing: a streamed city of thousands keeps only the meshes (director's playtest:
## stage 4 swapped, ~6 MB a building), and only a building the rampage reaches pays for voxels.
var voxels: BuildingVoxels:
	get:
		if _voxels == null:
			_voxels = _make_voxels()
		return _voxels
var mesher: BuildingMesher
## The fine-grid view once the building is carved (promote); null while it is on its chunks.
var cells_view: CellView
var _voxels: BuildingVoxels
var _base: Color
var _party: Dictionary
var _key_of := ""
var _alive: Image
var _alive_tex: ImageTexture
var _slabs: MeshInstance3D
var _shell_mat: ShaderMaterial
var _slab_mat: ShaderMaterial
var _shell: MeshInstance3D
var _cells_mat: ShaderMaterial


## party: side (BuildingVoxels.SIDES) -> floors a neighbour covers there. The voxels and meshes are
## built here, so a whole city can be built across worker threads before entering the tree.
func _init(p_building: RampageSim.Building, base: Color, party: Dictionary = {}) -> void:
	b = p_building
	_base = base
	_party = party
	var key := _key(b, base, party)
	_key_of = key
	_baked_lock.lock()
	var kept: Array = _baked.get(key, [])
	if not kept.is_empty():
		kept[2] = _generation
	_baked_lock.unlock()
	if kept.is_empty():
		var made := _make_voxels()
		mesher = BuildingMesher.new(made)
		if b.landmark != "":
			_voxels = made  # a landmark is few and its ground mesh is drawn below
		_baked_lock.lock()
		_baked[key] = [null, mesher, _generation]
		_baked_lock.unlock()
	else:
		mesher = kept[1]
	_alive = Image.create(maxi(1, b.w * b.d * b.height), 1, false, Image.FORMAT_R8)
	_alive.fill(Color(1, 1, 1))
	_alive_tex = ImageTexture.create_from_image(_alive)
	_shell_mat = _material(_alive_tex)
	_slab_mat = _material(_alive_tex)
	_shell = _instance(mesher.shell, _shell_mat)
	add_child(_shell)
	_slabs = _instance(mesher.slabs, _slab_mat)
	_slabs.visible = false
	add_child(_slabs)
	if b.landmark != "" and not (voxels as LandmarkVoxels).ground.cells.is_empty():
		var ground := (voxels as LandmarkVoxels).ground
		var mi := MeshInstance3D.new()
		mi.mesh = ground.bake({}, BuildingVoxels.VOXEL, voxels.origin(), 0.0)
		add_child(mi)


func _make_voxels() -> BuildingVoxels:
	if b.is_rail():
		return RailVoxels.new(b, _base)
	if b.landmark == "" and b.model == "":
		return BuildingVoxels.new(b, _base, _party)
	return LandmarkVoxels.new(b, _base)


## A new city's build starts (BuildingStream): what it uses is marked as its own.
static func begin_city() -> void:
	_baked_lock.lock()
	_generation += 1
	_baked_lock.unlock()


## The city is done with (its rampage leaves): every kept building it did not use is dropped.
static func end_city() -> void:
	_baked_lock.lock()
	for key: String in _baked.keys():
		var kept: Array = _baked[key]
		if Num.i(kept[2]) != _generation:
			_baked.erase(key)
	_baked_lock.unlock()


## A view leaves for good (BuildingStream sends a far, untouched building back to a box): its
## kept meshes go too, so the memory is really returned.
static func forget(view: BuildingView) -> void:
	_baked_lock.lock()
	_baked.erase(view._key_of)
	_baked_lock.unlock()


## Buildings whose voxels and meshes are kept (tests).
static func cached() -> int:
	return _baked.size()


## What makes two buildings bake alike: place, size, floors, landmark, wall colour, party walls,
## and a pool building's model, variant and palette.
static func _key(at: RampageSim.Building, base: Color, party: Dictionary) -> String:
	var model := "%s|%s|%d" % [at.model, str(at.variant), at.palette]
	return (
		"%s|%s|%d|%d|%d|%s|%s|%s|%s"
		% [at.x, at.z, at.w, at.d, at.height, at.landmark, base.to_html(), str(party), model]
	)


## Screen-door share (1 = solid): a building between the camera and the kaiju (BuildingFade).
func set_opacity(value: float) -> void:
	_shell_mat.set_shader_parameter("opacity", value)
	_slab_mat.set_shader_parameter("opacity", value)
	if cells_view != null:
		cells_view.set_opacity(value)


## Switches this building to its fine grid (D-094): from now on it is drawn by a CellView of
## `grid` (its region meshes, remeshed as it is carved) and the baked chunk meshes are hidden.
## The same shader draws both, so fade and glow carry over. Not for a landmark (WP6).
func promote(grid: BuildingCells) -> CellView:
	if cells_view != null:
		return cells_view
	var whole := Image.create(1, 1, false, Image.FORMAT_R8)
	whole.fill(Color(1, 1, 1))
	_cells_mat = _material(ImageTexture.create_from_image(whole))  # every face in chunk 0, standing
	_cells_mat.set_shader_parameter("opacity", _shell_mat.get_shader_parameter("opacity"))
	cells_view = CellView.new(CellMesher.new(voxels, grid), grid.cells, _cells_mat)
	add_child(cells_view)
	_shell.visible = false
	_slabs.visible = false
	return cells_view


func _material(tex: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("alive", tex)
	mat.set_shader_parameter("glow", Look.value("window_glow"))
	var shape: Dictionary = Content.landmarks().get(b.landmark, {})
	mat.set_shader_parameter("inside", Num.f(shape.get("inside", 0.12)))  # cut faces' shade
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
		out.append_array(mesher.parts_of(_index(c)))
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
## the sim's chunks are unchanged. Not for a landmark: its smooth walls would read as speckled
## noise; its arcs (Arcs) come down whole instead.
func chip(broken: Array[Vector3i], rng: RandomNumberGenerator) -> Array[Dictionary]:
	_slabs.visible = true
	if b.landmark != "":
		return []
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
	if not cells.is_empty():  # its chunks at rest, world space (FallFade)
		var box := AABB(b.chunk_world(cells[0]) - Vector3.ONE * 0.5, Vector3.ONE)
		for c: Vector3i in cells:
			box = box.merge(AABB(b.chunk_world(c) - Vector3.ONE * 0.5, Vector3.ONE))
		piece.set_meta("box", box)
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


## For each building, side -> how many floors of it a touching neighbour covers (the sim's
## PartyWalls, so the view and the sim's fine grid agree).
static func party_walls(buildings: Array[RampageSim.Building]) -> Array[Dictionary]:
	var out := PartyWalls.of(buildings)
	pair_checks = PartyWalls.pair_checks
	return out
