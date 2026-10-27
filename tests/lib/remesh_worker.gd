extends RefCounted
## Render plan item 9c (tuning render_opt.remesh_worker_mesh) for tests/run_cell_mesh_tests.gd:
## the flag is ON by default; the native mesher packs a block's surface itself
## (KaijuMesher.pack_surface), and the mesh made from it (CellMesher.packed_mesh, what a worker
## makes under a real renderer) is the main thread's CellMesher.to_mesh byte for byte: the
## surface the RenderingServer holds (format, counts, vertex, attribute and index bytes, AABB) and
## CellMesher.digest of the arrays read back, on every block of the fixture after a carve
## sequence. Headless keeps the main-thread path (the dummy renderer's allocator is not
## thread-safe), so a headless view never meshes on its worker; under a real renderer (a windowed
## run) a view with the flag on does, and shows the same digests in every block as one with it off.
## Seeded by design: a fixed building and a fixed carve sequence, no random numbers.

const CellFaces := preload("res://tests/lib/cell_faces.gd")
const RemeshPriority := preload("res://tests/lib/remesh_priority.gd")
## The surface keys both paths must hold the same (RenderingServer.mesh_get_surface).
const SURFACE_KEYS: Array[String] = [
	"format",
	"primitive",
	"vertex_count",
	"index_count",
	"vertex_data",
	"attribute_data",
	"index_data",
	"aabb",
]

var _check: Callable
var _native: bool


## check: the runner's check; native: whether the KaijuMesher extension is loaded.
func _init(p_check: Callable, p_native: bool) -> void:
	_check = p_check
	_native = p_native


func run() -> void:
	var opt := Content.section("render_opt")
	var was: Variant = opt.get("remesh_worker_mesh", null)
	_check.call(was == true, "render_opt.remesh_worker_mesh is ON by default")
	if not _native:
		print("  (no native library: the packed-surface checks skip)")
		return
	var fx := _fixture()
	var m: CellMesher = fx[0]
	var cells: PackedByteArray = fx[1]
	var packs := "the native mesher packs a block's surface (KaijuMesher.pack_surface)"
	_check.call(m.can_pack(), packs)
	if not m.can_pack():
		return
	_same_bytes(m, cells)
	var headless := DisplayServer.get_name() == "headless"
	var has_rd := RenderingServer.get_rendering_device() != null
	var view := CellView.new(m, cells, StandardMaterial3D.new())
	view.flush()
	var says := "a view with the flag on meshes on its worker exactly when the renderer is real"
	var on_worker := view.worker_mesh == (not headless and has_rd)
	_check.call(on_worker, "%s (%s: %s)" % [says, DisplayServer.get_name(), view.worker_mesh])
	if not has_rd:
		var no_rd := "with no RenderingDevice (headless, gl_compatibility) a view meshes on main"
		_check.call(not view.worker_mesh, no_rd)
	view.free()
	if not headless:
		_same_view(opt, was, has_rd)


## Every block of the fixture after the carve sequence: to_mesh and packed_mesh give the same
## surface on the server and the same digest read back.
func _same_bytes(m: CellMesher, cells: PackedByteArray) -> void:
	for k: int in RemeshPriority.CARVE_AT.size():
		cells = cells.duplicate()
		CellFaces.carve(cells, m.dims, RemeshPriority.CARVE_AT[k], RemeshPriority.CARVE_R[k])
	var blocks := 0
	var empty := 0
	var bad: Array[String] = []
	for r: Vector3i in m.all_regions():
		var arrays := m.mesh_region(cells, r)
		var main_mesh := CellMesher.to_mesh(arrays)
		var packed := m.packed_mesh(arrays)
		if main_mesh == null or packed == null:
			empty += 1
			if (main_mesh == null) != (packed == null):
				bad.append("%s: one path has no mesh" % r)
			continue
		blocks += 1
		var a := RenderingServer.mesh_get_surface(main_mesh.get_rid(), 0)
		var b := RenderingServer.mesh_get_surface(packed.get_rid(), 0)
		for key: String in SURFACE_KEYS:
			if var_to_bytes(a.get(key)) != var_to_bytes(b.get(key)):
				bad.append("%s: %s differs" % [r, key])
		if CellMesher.digest(read_back(main_mesh)) != CellMesher.digest(read_back(packed)):
			bad.append("%s: digest differs" % r)
	_check.call(
		blocks > 0 and bad.is_empty(),
		(
			"a packed block is the main thread's mesh byte for byte (%d blocks, %d empty; %s)"
			% [blocks, empty, "none differ" if bad.is_empty() else ", ".join(bad.slice(0, 4))]
		)
	)


## A windowed run: views with the flag on and off, carved the same, show the same digest in every
## block (the worker's meshes are the main thread's).
func _same_view(opt: Dictionary, was: Variant, has_rd: bool) -> void:
	var shown := {}
	for on: bool in [true, false]:
		opt["remesh_worker_mesh"] = on
		var fx := _fixture()
		var m: CellMesher = fx[0]
		var cells: PackedByteArray = fx[1]
		var view := CellView.new(m, cells, StandardMaterial3D.new())
		_check.call(
			view.worker_mesh == (on and has_rd),
			"a windowed view with the flag %s: worker_mesh %s" % [on, on and has_rd]
		)
		view.flush()
		for k: int in RemeshPriority.CARVE_AT.size():
			cells = cells.duplicate()
			var box := CellFaces.carve(
				cells, m.dims, RemeshPriority.CARVE_AT[k], RemeshPriority.CARVE_R[k]
			)
			view.carved(cells, box[0], box[1])
			view.flush()
		var digests := {}
		for r: Vector3i in view.parts:
			var part: MeshInstance3D = view.parts[r]
			digests[r] = CellMesher.digest(read_back(part.mesh as ArrayMesh))
		shown[on] = digests
		view.free()
	opt["remesh_worker_mesh"] = was
	var on_digests: Dictionary = shown[true]
	var off_digests: Dictionary = shown[false]
	_check.call(
		not on_digests.is_empty() and on_digests == off_digests,
		(
			"worker-made and main-thread views show the same bytes in every block (%d)"
			% on_digests.size()
		)
	)


## A mesh's first surface read back from the server, in mesh_region's order (CellMesher.digest).
static func read_back(mesh: ArrayMesh) -> Array:
	var rb := mesh.surface_get_arrays(0)
	return [
		rb[Mesh.ARRAY_VERTEX],
		rb[Mesh.ARRAY_NORMAL],
		rb[Mesh.ARRAY_COLOR],
		rb[Mesh.ARRAY_INDEX],
		rb[Mesh.ARRAY_TEX_UV],
	]


## RemeshPriority's office fixture: [its native mesher, its grid's cells].
func _fixture() -> Array:
	var b := RampageSim.Building.new()
	b.x = 10.5
	b.z = 4.5
	b.w = 3
	b.d = 3
	b.height = 6
	b.tier = 2
	b.style = 0
	b.frame = Structure.new(b.w, b.d, b.height, 1.0)
	var grid := BuildingCells.new(b, {})
	var m := CellMesher.new(BuildingVoxels.new(b, Color("8a7f72"), {}), grid, _native)
	return [m, grid.cells]
