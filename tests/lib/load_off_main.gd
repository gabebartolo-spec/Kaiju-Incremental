extends RefCounted
## The load suite's off-main-thread checks, split out to keep the runner small.

var _check: Callable
var _sim: RampageSim
var _root: Node


## check: the runner's check(condition, expectation); sim: a stage's city; root: the tree's root.
func _init(p_check: Callable, sim: RampageSim, root: Node) -> void:
	_check = p_check
	_sim = sim
	_root = root


## Both checks, in order.
func run() -> void:
	_built_off_main()
	_voxel_pack()


## A city's buildings and ruins are laid out on worker threads, but no texture, material or mesh
## is made there: one made off the main thread raced the renderer's material list and froze the
## High bench with self_list errors forever (2026-10-26). Each view is drawn as it enters the
## tree; a ruin plan becomes its heap on the main thread.
func _built_off_main() -> void:
	ThreadCheck.hits.clear()
	var sim := _sim
	var some: Array[RampageSim.Building] = []
	var colors: Array[Color] = []
	for n: int in mini(6, sim.buildings.size()):
		some.append(sim.buildings[n])
		colors.append(Color.GRAY)
	var views := BuildingView.build_all(some, colors)
	var voxels := views[0].voxels
	var plans: Array = [{}]
	var task := WorkerThreadPool.add_task(
		func() -> void: plans[0] = Ruin.build_plan(voxels, Seeds.make("ruin", 0))
	)
	WorkerThreadPool.wait_for_task_completion(task)
	_check.call(
		ThreadCheck.hits.is_empty() and not views.has(null),
		(
			"a city laid out on worker threads makes no render resource there (%s)"
			% ThreadCheck.report()
		)
	)
	var holder := Node3D.new()
	_root.add_child(holder)
	for view: BuildingView in views:
		holder.add_child(view)
	var plan: Dictionary = plans[0]
	var heap := Ruin.make(plan)
	holder.add_child(heap)
	var drawn := views.all(
		func(v: BuildingView) -> bool:
			return (
				v._shell != null
				and v._shell.mesh.get_surface_count() == 1
				and v._shell.material_override != null
			)
	)
	_check.call(
		drawn and heap.multimesh.instance_count > 100,
		"each building is drawn as it enters the tree, and the ruin's heap from its plan"
	)
	holder.free()


## A heap's MultiMesh buffer (VoxelBuilder.pack, built on a worker) holds each cell's cube exactly
## as the per-instance setters did: scaled to the inset, centred on its cell, lifted half a voxel,
## in its jittered colour, bottom-up.
func _voxel_pack() -> void:
	var vox := VoxelBuilder.new()
	vox.put(Vector3i(0, 1, 0), "a")
	vox.put(Vector3i(2, 0, 3), "b")
	vox.inset = 0.9
	vox.salt = 7
	var palette := {"a": Color(0.2, 0.4, 0.6), "b": Color(0.8, 0.1, 0.3)}
	var origin := Vector3(1, 2, 3)
	var buf := vox.pack(palette, 0.5, origin)
	var ok := buf.size() == 2 * VoxelBuilder.STRIDE and vox.sorted_y == PackedInt32Array([0, 1])
	for i: int in 2:
		var cell: Vector3i = vox.built_cells[i]
		var want := Transform3D(
			Basis().scaled(Vector3.ONE * 0.9), origin + Vector3(cell) * 0.5 + Vector3(0, 0.25, 0)
		)
		var base: Color = palette["a" if cell.y == 1 else "b"]
		var color := Look.jitter(base, cell, 7)
		var k := i * VoxelBuilder.STRIDE
		var got := Transform3D(
			Basis(
				Vector3(buf[k], buf[k + 4], buf[k + 8]),
				Vector3(buf[k + 1], buf[k + 5], buf[k + 9]),
				Vector3(buf[k + 2], buf[k + 6], buf[k + 10])
			),
			Vector3(buf[k + 3], buf[k + 7], buf[k + 11])
		)
		var tint := Color(buf[k + 12], buf[k + 13], buf[k + 14], buf[k + 15])
		ok = ok and got.is_equal_approx(want) and tint.is_equal_approx(color)
	_check.call(ok, "a packed heap places and colours each cube as the per-instance setters did")
