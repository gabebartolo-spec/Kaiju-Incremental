class_name BuildingView
extends Node3D
## One building, drawn from two baked meshes (BuildingMesher): its shell, and its floor slabs,
## which stay hidden until it is first broken open, and then show only next to a break (the rest
## of the building looks as it did, D-289). The sim's structural chunks (one sim unit,
## one floor) live in a small `alive` texture the shader reads: a broken chunk is switched off
## there, a bitten one loses a share of its voxels, so nothing is rebuilt mid-rampage. A falling
## part is the same meshes with its own texture (only its chunks on), lifted out to topple over
## its edge (accelerating like a real fall) or drop straight down.

const SHADER := preload("res://scenes/building_baked.gdshader")
const BITTEN := 0.7  # a chunk next to a hole keeps this share of its voxels
const BITE_CHANCE := 0.5  # ...and this share of the chunks next to a hole are bitten

## Building pairs the last party_walls() call compared (tests check it grows about linearly).
static var pair_checks := 0

var b: RampageSim.Building
## The building's fine voxels, rebuilt (the build is deterministic) the first time something needs
## them after meshing: a streamed city of thousands keeps only the meshes (director's playtest:
## stage 4 swapped, ~6 MB a building), and only a building the rampage reaches pays for voxels.
var voxels: BuildingVoxels:
	get:
		if _voxels == null:
			_voxels = voxels_of(b, _base, _party)
		return _voxels
var mesher: BuildingMesher
## The fine-grid view once the building is carved (promote, attach_cells); null while it is on
## its chunks.
var cells_view: CellView
## Whether the fine-grid view draws the building now (show_cells): the baked meshes stay hidden.
var fine := false
var _voxels: BuildingVoxels
var _base: Color
var _party: Dictionary
var _key_of := ""
var _alive: Image
var _alive_tex: ImageTexture
## The floors' own `alive` texture, made at the first blow: a floor shows only in a chunk that has
## broken or sits next to one (_exposed), so what the unbroken facade shows through its gaps stays
## what it was (D-289).
var _slab_alive: Image
var _slab_tex: ImageTexture
var _exposed := PackedByteArray()
var _slabs: MeshInstance3D
var _shell_mat: ShaderMaterial
var _slab_mat: ShaderMaterial
var _shell: MeshInstance3D
## The standing fine-grid view's material (attach_cells), cut by the bubble as the shell is.
var _cells_mat: ShaderMaterial
## The camera bubble's cut on this building (set_near_camera): 0 whole .. 1 the whole radius.
var _cut := 0.0
var _share := 1.0  # how much of the standing building is drawn (StreamDissolve)
## The landmark ground's mesh arrays until _dress makes its mesh.
var _ground: Array = []


## party: side (BuildingVoxels.SIDES) -> floors a neighbour covers there. The voxels and mesh data
## are built here, so a whole city can be built across worker threads before entering the tree;
## its textures, materials and meshes are made on the main thread (_dress: at once when built
## there, else as it enters the tree), never on a worker (ThreadCheck).
func _init(p_building: RampageSim.Building, base: Color, party: Dictionary = {}) -> void:
	b = p_building
	_base = base
	_party = party
	_key_of = BuildingBakeCache.key(b, base, party)
	mesher = BuildingBakeCache.take(_key_of)  # kept from an earlier run of this city
	if mesher == null:
		var made := voxels_of(b, _base, _party)
		mesher = BuildingMesher.new(made)
		if b.landmark != "":
			_voxels = made  # a landmark is few and its ground mesh is drawn below
		BuildingBakeCache.keep(_key_of, mesher)
	_alive = Image.create(maxi(1, b.w * b.d * b.height), 1, false, Image.FORMAT_R8)
	_alive.fill(Color(1, 1, 1))
	if b.landmark != "" and not (voxels as LandmarkVoxels).ground.cells.is_empty():
		var ground := (voxels as LandmarkVoxels).ground
		_ground = ground.bake_arrays({}, BuildingVoxels.VOXEL, voxels.origin())
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		_dress()


func _ready() -> void:
	_dress()


## Makes what is drawn (the alive texture, the materials, the shell, slab and ground meshes) from
## the data _init built. Main thread; once.
func _dress() -> void:
	if _shell != null:
		return
	ThreadCheck.main_only("BuildingView._dress")
	_alive_tex = ImageTexture.create_from_image(_alive)
	_shell_mat = _material(_alive_tex)
	_slab_mat = _material(_alive_tex)
	_shell = _instance(mesher.shell, _shell_mat)
	add_child(_shell)
	_slabs = _instance(mesher.slabs, _slab_mat)
	_slabs.visible = false
	add_child(_slabs)
	if not _ground.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = VoxelBuilder.baked(_ground, 0.0)
		add_child(mi)
		_ground = []


## A building's fine voxels (pure data: safe on a worker thread).
static func voxels_of(at: RampageSim.Building, base: Color, party: Dictionary) -> BuildingVoxels:
	if at.is_rail():
		return RailVoxels.new(at, base)
	if at.is_bridge():
		return BridgeVoxels.new(at, base)
	if at.landmark != "" or at.model != "":
		return LandmarkVoxels.new(at, base)
	if at.hazard != "":
		return HazardVoxels.new(at, base)  # a red barrel (comments #19)
	return BuildingVoxels.new(at, base, party)


## Builds this building's voxels anew when called, holding no reference to the view (a worker
## may call it while the view is streamed out); adopt_voxels hands them back.
func voxel_maker() -> Callable:
	return voxels_of.bind(b, _base, _party)


## The voxels voxel_maker built (the same data the getter would build): kept, not built again.
func adopt_voxels(made: BuildingVoxels) -> void:
	if _voxels == null:
		_voxels = made


## Whether the voxels are built already (the getter would not build them).
func has_voxels() -> bool:
	return _voxels != null


## Its BuildingBakeCache key (BuildingStream forgets the kept meshes of a view it frees).
func bake_key() -> String:
	return _key_of


## The camera bubble's seam (CameraBubble, D-283; render plan item 5 names it too): while `on`,
## this standing building is cut away inside the bubble round the camera, `share` of its radius
## (1 = all of it; less while the cut opens or closes); off, it draws whole. Only the standing
## building takes it: a piece lifted off it makes its own materials, never cut (D-326).
func set_near_camera(on: bool, share := 1.0) -> void:
	var cut := clampf(share, 0.0, 1.0) if on else 0.0
	if cut == _cut and _shell_mat != null:
		return
	_dress()
	_cut = cut
	for mat: ShaderMaterial in [_shell_mat, _slab_mat, _cells_mat]:
		if mat != null:
			mat.set_shader_parameter("bubble_cut", cut)


## The stream swap (StreamDissolve): `share` of this standing building is drawn, a dither (1 =
## whole, 0 = none). Only the stream sets it; a carved, broken or falling piece is whole (D-326).
func set_dissolve(share: float) -> void:
	_share = share
	for mat: ShaderMaterial in [_shell_mat, _slab_mat, _cells_mat]:
		if mat != null:
			mat.set_shader_parameter("dissolve", share)


## How much of this building the stream swap draws now (1 = whole; tests read it).
func dissolve_share() -> float:
	return _share


## How much of the bubble cuts this building now (0 = whole; tests read it).
func near_camera_cut() -> float:
	return _cut


## Switches this building to its fine grid (D-094): from now on it is drawn by a CellView of
## `grid` (its region meshes, remeshed as it is carved) and the baked chunk meshes are hidden.
## The same shader draws both, so the bubble's cut and the glow carry over. Not for a landmark
## (WP6). At once, on the main thread (tests, captures); play goes through CityCarve
## (attach_cells, show_cells).
func promote(grid: CellGrid) -> CellView:
	if cells_view != null:
		return cells_view
	attach_cells(CellView.new(CellMesher.new(voxels, grid), grid.cells, cells_material()))
	show_cells()
	return cells_view


## A material for a fine-grid mesh of this building: the baked shader with every face standing,
## uncut. The CellView's (attach_cells gives it the bubble's cut, as the shell has) and each
## falling piece's own (a lifted piece is never cut, D-326).
func cells_material() -> ShaderMaterial:
	_dress()
	var whole := Image.create(1, 1, false, Image.FORMAT_R8)
	whole.fill(Color(1, 1, 1))
	return _material(ImageTexture.create_from_image(whole))  # every face in chunk 0, standing


## Adds the fine-grid view, hidden: the baked meshes draw on until show_cells. From now on its
## material takes the bubble's cut with the shell's (set_near_camera): the grid stands where the
## shell did.
func attach_cells(view: CellView) -> void:
	_dress()
	cells_view = view
	_cells_mat = view.material as ShaderMaterial
	if _cells_mat != null:
		_cells_mat.set_shader_parameter("bubble_cut", _cut)
	view.visible = false
	add_child(view)


## The fine-grid view draws the building from now on; the baked meshes are hidden (the same
## frame, so nothing blinks).
func show_cells() -> void:
	cells_view.visible = true
	_shell.visible = false
	_slabs.visible = false
	fine = true


func _material(tex: Texture2D) -> ShaderMaterial:
	ThreadCheck.main_only("BuildingView._material")
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("alive", tex)
	mat.set_shader_parameter("glow", Look.value("window_glow"))
	var shape: Dictionary = Content.landmarks().get(b.landmark, {})
	mat.set_shader_parameter("inside", Num.f(shape.get("inside", 0.12)))  # cut faces' shade
	WindowPalette.apply(mat, b)
	VoxelAO.apply(mat)  # baked AO and material finish (render plan item 12)
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
	var i := _index(c)
	_alive.set_pixel(i, 0, Color(value, 0, 0))
	if _slab_alive != null and _exposed[i] == 1:
		_slab_alive.set_pixel(i, 0, Color(value, 0, 0))


## The floors inside show in these chunks and the ones next to them (the first blow makes the
## floors' own texture, all hidden, so the rest of the building looks as it did standing).
func _expose(cells: Array[Vector3i]) -> void:
	if _slab_alive == null:
		_slab_alive = Image.create(_alive.get_width(), 1, false, Image.FORMAT_R8)
		_slab_alive.fill(Color(0, 0, 0))
		_slab_tex = ImageTexture.create_from_image(_slab_alive)
		_slab_mat.set_shader_parameter("alive", _slab_tex)
		_exposed.resize(_alive.get_width())
	var around: Array[Vector3i] = [Vector3i.ZERO]
	around.append_array(BuildingMesher.NEIGHBOURS)
	for c: Vector3i in cells:
		for d: Vector3i in around:
			var n := c + d
			if n.x < 0 or n.z < 0 or n.y < 0 or n.x >= b.w or n.z >= b.d or n.y >= b.height:
				continue
			var i := _index(n)
			if _exposed[i] == 0:
				_exposed[i] = 1
				_slab_alive.set_pixel(i, 0, Color(_alive.get_pixel(i, 0).r, 0, 0))
	_slab_tex.update(_slab_alive)


## Debris sources (world positions and colours) for these chunks.
func _parts(cells: Array[Vector3i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Vector3i in cells:
		out.append_array(mesher.parts_of(_index(c)))
	return out


## Sends the `alive` images to the shader (the floors' own too, once a blow made them).
func _upload() -> void:
	_alive_tex.update(_alive)
	if _slab_tex != null:
		_slab_tex.update(_slab_alive)


## Hides these chunks; returns world positions and colours to throw as debris.
func hide_chunks(cells: Array[Vector3i]) -> Array[Dictionary]:
	_dress()
	_slabs.visible = not fine
	var out := _parts(cells)
	for c: Vector3i in cells:
		_put_state(c, 0.0)
	_expose(cells)
	_alive_tex.update(_alive)
	return out


## Bites ragged edges round a hole: some standing neighbours of the broken chunks lose a share
## of their voxels, so walls look chewed rather than cut along the chunk grid. Cosmetic only;
## the sim's chunks are unchanged. Not for a landmark: its smooth walls would read as speckled
## noise; its arcs (Arcs) come down whole instead.
func chip(broken: Array[Vector3i], rng: RandomNumberGenerator) -> Array[Dictionary]:
	_dress()
	_slabs.visible = not fine
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
	_upload()
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
	if not cells.is_empty():  # its chunks at rest, world space (tests read it)
		var box := AABB(b.chunk_world(cells[0]) - Vector3.ONE * 0.5, Vector3.ONE)
		for c: Vector3i in cells:
			box = box.merge(AABB(b.chunk_world(c) - Vector3.ONE * 0.5, Vector3.ONE))
		piece.set_meta("box", box)
	return piece


## Every building's view, its voxels and mesh data built across worker threads (thousands of
## voxels each; each is dressed as it enters the tree); colors: each building's wall colour.
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
