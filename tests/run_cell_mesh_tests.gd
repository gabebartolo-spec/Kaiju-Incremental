extends "res://tests/lib/runner.gd"
## Cell mesh suite (D-094 WP4): a carved building's view drawn from its fine grid. An uncarved
## building draws every face its baked BuildingView draws, in the same colour (lit windows
## included), plus only the inner faces of its walls; a carved one is a closed surface (every
## solid cell meets air through exactly one drawn face, so a hole shows lit inner faces, never
## a gap); a carve remeshes only the REGION blocks it touched, and what they show equals a
## fresh mesh of the carved grid; the native KaijuMesher gives the GDScript oracle's bytes.
## Seeded by design: buildings and carves are fixed fixtures; no RNG.
##   godot --headless --path . --script tests/run_cell_mesh_tests.gd

## Each fixture: [name, x, z, w, d, floors, tier, style, party].
const FIXTURES: Array = [
	["office", 10.5, 4.5, 3, 3, 6, 2, 0, {}],
	["brick", 20.5, 4.5, 3, 2, 5, 1, 1, {}],
	["glass", 30.0, 6.0, 4, 4, 12, 3, 2, {}],
	["stone", 40.5, 4.5, 3, 3, 8, 2, 3, {}],
	["party", 20.5, 14.0, 3, 2, 5, 1, 1, {Vector2i(1, 0): 3, Vector2i(0, -1): 5}],
	["sign", 4.5, 2.5, 3, 3, 6, 1, 3, {}],
]
## A carve sequence on a fixture (grid cells; [centre, radius]): a punch through the street
## face, a bite out of a corner, a cut across a region boundary, a hole through the roof, and a
## bite whose box starts exactly on a block boundary (the block below and behind must remesh).
const CARVE_AT: Array[Vector3] = [
	Vector3(1.0, 30.0, 12.0),
	Vector3(0.0, 44.0, 0.0),
	Vector3(16.0, 16.0, 16.0),
	Vector3(12.0, 47.0, 12.0),
	Vector3(19.0, 40.0, 2.5),
]
const CARVE_R: Array[float] = [5.0, 7.0, 6.0, 4.0, 3.0]

const CellFaces := preload("res://tests/lib/cell_faces.gd")

var _native := false


func suite_name() -> String:
	return "Cell mesh"


func run_checks() -> void:
	_native = ClassDB.class_exists("KaijuMesher")
	await _t("_check_native_loaded")
	await _t("_check_matches_baked_view")
	await _t("_check_no_face_hidden_by_a_hidden_slab")
	await _t("_check_closed_surface_after_carves")
	await _t("_check_only_touched_regions")
	await _t("_check_incremental_equals_fresh")
	await _t("_check_native_matches_oracle")
	await _t("_check_promote_keeps_fade")


func _building(f: Array) -> RampageSim.Building:
	var b := RampageSim.Building.new()
	b.x = f[1]
	b.z = f[2]
	b.w = f[3]
	b.d = f[4]
	b.height = f[5]
	b.tier = f[6]
	b.style = f[7]
	b.frame = Structure.new(b.w, b.d, b.height, 1.0)
	return b


func _party(f: Array) -> Dictionary:
	var party: Dictionary = f[8]
	return party


func _fixture(name: String) -> Array:
	for f: Array in FIXTURES:
		if f[0] == name:
			return f
	return []


func _mesher(f: Array, use_native: bool) -> CellMesher:
	var b := _building(f)
	return CellMesher.new(
		BuildingVoxels.new(b, Color("8a7f72"), _party(f)),
		BuildingCells.new(b, _party(f)),
		use_native
	)


func _part(view: CellView, r: Vector3i) -> MeshInstance3D:
	var part: MeshInstance3D = view.parts[r]
	return part


func _check_native_loaded() -> void:
	if _native:
		check(true, "the KaijuMesher class is registered by the extension")
	elif OS.get_environment("KAIJU_NATIVE_REQUIRED") == "1":
		check(
			false,
			"native library is required here (KAIJU_NATIVE_REQUIRED=1) but KaijuMesher is not registered"
		)
	else:
		print("SKIP: KaijuMesher is not registered; build native/ to run the native checks")
		check(true, "native library not built: native checks skipped on purpose")


## Uncarved, the grid's mesh holds every face of the baked view (shell and slabs) in the same
## colour, and its only extra faces are wall and roof faces looking into the building's hollow.
## The one face the baked view draws that the grid's mesh does not is a wall face behind a balcony
## slab (the baked view hides that slab, so the wall must show; the grid draws the slab itself).
func _check_matches_baked_view() -> void:
	for f: Array in FIXTURES:
		var b := _building(f)
		var voxels := BuildingVoxels.new(b, Color("8a7f72"), _party(f))
		var baked := BuildingMesher.new(voxels)
		var cells := BuildingCells.new(b, _party(f))
		var m := CellMesher.new(voxels, cells, false)
		var old := {}
		CellFaces.mesh_faces(baked.shell, old)
		CellFaces.mesh_faces(baked.slabs, old)
		var now := CellFaces.cell_faces(m, cells.cells)
		var missing := 0
		var recoloured := 0
		for key: Array in old:
			if not now.has(key):
				missing += 1
			elif not CellFaces.same_colour(CellFaces.colour(now, key), CellFaces.colour(old, key)):
				recoloured += 1
		var extra := 0
		var stray := 0
		var w := b.w * BuildingVoxels.RES
		var d := b.d * BuildingVoxels.RES
		var h := b.height * BuildingVoxels.RES
		for key: Array in now:
			if old.has(key):
				continue
			extra += 1
			# The air cell this face looks into, building-local: must be inside the hollow.
			var normal: Vector3i = key[1]
			var at: Vector3i = key[0]
			var corner := Vector3(at) / 64.0
			var centre := corner - m._corners[CellMesher.NEIGHBOURS.find(normal)][0]
			var lift := Vector3(0, BuildingVoxels.VOXEL * 0.5, 0)  # the baked cells' centre height
			var local := (
				Vector3i(((centre - voxels.origin() - lift) / BuildingVoxels.VOXEL).round())
				+ normal
			)
			var inside := local.x >= 1 and local.x <= w - 2 and local.z >= 1 and local.z <= d - 2
			if not (inside and local.y >= 0 and local.y < h - 1):
				stray += 1
		var behind := _faces_behind_balconies(voxels, baked)
		check(
			missing == behind.size() and recoloured == 0,
			(
				"%s: every baked face is drawn in its colour, bar the %d walls behind a balcony slab (%d missing, %d recoloured of %d)"
				% [f[0], behind.size(), missing, recoloured, old.size()]
			)
		)
		check(
			stray == 0 and extra > 0,
			(
				"%s: the only extra faces look into the hollow (%d extra, %d stray)"
				% [f[0], extra, stray]
			)
		)


## Face centres (see _face_key) of the shell cells' faces that look at a floor slab outside the
## hollow (a brick balcony).
func _faces_behind_balconies(voxels: BuildingVoxels, baked: BuildingMesher) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var cells: Dictionary = voxels.vox.cells
	for cell: Vector3i in cells:
		if cells[cell] == "slab":
			continue
		for d: Vector3i in BuildingMesher.NEIGHBOURS:
			var o := cell + d
			if cells.get(o, "") == "slab" and not baked._inside(o):
				out.append(_face_key(voxels, cell, d))
	return out


## A face's centre on a 1/1024 m grid: the cell's centre, half a voxel out along `d`.
func _face_key(voxels: BuildingVoxels, cell: Vector3i, d: Vector3i) -> Vector3i:
	var half := BuildingVoxels.VOXEL * 0.5
	var at := voxels.origin() + Vector3(0, half, 0) + Vector3(cell) * BuildingVoxels.VOXEL
	return Vector3i(((at + Vector3(d) * half) * 1024.0).round())


## The quad centres of a baked mesh, on the same 1/1024 m grid.
func _quad_keys(mesh: ArrayMesh) -> Dictionary:
	var out := {}
	if mesh.get_surface_count() == 0:
		return out
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for q: int in range(0, verts.size(), 4):
		var centre := (verts[q] + verts[q + 1] + verts[q + 2] + verts[q + 3]) * 0.25
		out[Vector3i((centre * 1024.0).round())] = true
	return out


## The director's "flickering horizontal black bars across the windows" (2026-10-27): a wall cell
## behind a balcony slab (brick facades, every other floor) had no face drawn, because the slab
## that touches it is in the hidden mesh: a see-through strip with dark back faces behind it.
## Every face of a shell cell is drawn unless a drawn cell, the hollow or the ground covers it;
## the brick fixtures have such balconies (not blind).
func _check_no_face_hidden_by_a_hidden_slab() -> void:
	var balcony_fixtures := 0
	for f: Array in FIXTURES:
		var b := _building(f)
		var voxels := BuildingVoxels.new(b, Color("8a7f72"), _party(f))
		var baked := BuildingMesher.new(voxels)
		var cells: Dictionary = voxels.vox.cells
		var drawn := _quad_keys(baked.shell)
		var hidden := 0
		for cell: Vector3i in cells:
			if cells[cell] == "slab":
				continue
			for d: Vector3i in BuildingMesher.NEIGHBOURS:
				var o := cell + d
				if drawn.has(_face_key(voxels, cell, d)):
					continue
				var covered := (
					o.y < 0 or baked._inside(o) or (cells.has(o) and cells[o] != "slab")
				)
				if not covered:
					hidden += 1
		var behind := _faces_behind_balconies(voxels, baked).size()
		if behind > 0:
			balcony_fixtures += 1
		check(
			hidden == 0,
			(
				"%s: no shell face is hidden by a slab outside the hollow (%d hidden, %d balcony faces)"
				% [f[0], hidden, behind]
			)
		)
	check(balcony_fixtures >= 2, "the brick fixtures have balconies (%d)" % balcony_fixtures)


## After the carve sequence every solid cell meets air through exactly one face per side:
## no gap shows the sky or a dark back face through a hole.
func _check_closed_surface_after_carves() -> void:
	for name: String in ["office", "glass"]:
		var m := _mesher(_fixture(name), false)
		var cells := BuildingCells.new(_building(_fixture(name)), {}).cells
		var solid := CellFaces.solid(cells)
		for k: int in CARVE_AT.size():
			CellFaces.carve(cells, m.dims, CARVE_AT[k], CARVE_R[k])
		var faces := CellFaces.cell_faces(m, cells)
		var bounds := CellFaces.boundaries(m, cells)
		check(
			CellFaces.solid(cells) < solid,
			"%s: the carves removed cells (%d -> %d)" % [name, solid, CellFaces.solid(cells)]
		)
		check(
			faces.size() == bounds,
			(
				"%s: one face per solid-air boundary (%d faces, %d boundaries)"
				% [name, faces.size(), bounds]
			)
		)


## A carve inside one block remeshes that block only; one across a block corner remeshes the
## blocks round it; the other blocks keep their meshes.
func _check_only_touched_regions() -> void:
	var m := _mesher(_fixture("glass"), _native)
	var cells := BuildingCells.new(_building(_fixture("glass")), {}).cells
	var view := CellView.new(m, cells, StandardMaterial3D.new())
	view.flush()
	var total := m.all_regions().size()
	check(
		view.remeshed == total,
		"the first build meshes every block (%d of %d)" % [view.remeshed, total]
	)
	var meshes := {}
	for r: Vector3i in view.parts:
		meshes[r] = _part(view, r).mesh
	cells = cells.duplicate()
	var box := CellFaces.carve(cells, m.dims, Vector3(8.0, 40.0, 1.0), 3.0)  # inside block (0, 2, 0)
	view.carved(cells, box[0], box[1])
	view.flush()
	check(
		view.last_batch == [Vector3i(0, 2, 0)],
		"a carve inside one block remeshes it alone: %s" % [view.last_batch]
	)
	var kept := 0
	for r: Vector3i in meshes:
		if r != Vector3i(0, 2, 0) and view.parts.has(r) and _part(view, r).mesh == meshes[r]:
			kept += 1
	check(
		kept == meshes.size() - 1,
		"every other block keeps its mesh (%d of %d)" % [kept, meshes.size() - 1]
	)
	cells = cells.duplicate()
	box = CellFaces.carve(cells, m.dims, Vector3(16.0, 16.0, 16.0), 2.0)  # on a block corner
	view.carved(cells, box[0], box[1])
	view.flush()
	check(
		view.last_batch.size() == 8,
		"a carve on a block corner remeshes the 8 blocks round it (%d)" % view.last_batch.size()
	)
	check(
		view.remeshed == total + 9,
		"nine blocks remeshed in all for the two carves (%d)" % (view.remeshed - total)
	)
	view.free()


## Carves fed one by one leave every block showing exactly a fresh mesh of the grid: checked
## after each carve when each is drawn before the next, and at the end when they land on a
## batch still meshing (all but the first queue behind it).
func _check_incremental_equals_fresh() -> void:
	for queued: bool in [false, true]:
		var m := _mesher(_fixture("office"), _native)
		var cells := BuildingCells.new(_building(_fixture("office")), {}).cells
		var view := CellView.new(m, cells, StandardMaterial3D.new())
		view.keep_arrays = true
		view.flush()
		var off := 0
		for k: int in CARVE_AT.size():
			cells = cells.duplicate()
			var box := CellFaces.carve(cells, m.dims, CARVE_AT[k], CARVE_R[k])
			view.carved(cells, box[0], box[1])
			if not queued:
				view.flush()
				off += _stale_blocks(m, view, cells)
		view.flush()
		off += _stale_blocks(m, view, cells)
		var how := "queued on a running batch" if queued else "each drawn before the next"
		check(view.settled(), "the view has drawn every carve (%s)" % how)
		check(
			off == 0, "every block shows a fresh mesh of the grid, carves %s (%d off)" % [how, off]
		)
		view.free()


## Blocks whose shown mesh is not a fresh mesh of `cells`.
func _stale_blocks(m: CellMesher, view: CellView, cells: PackedByteArray) -> int:
	var off := 0
	for r: Vector3i in m.all_regions():
		var fresh := m.mesh_region(cells, r)
		var shown: Array = view.arrays.get(r, [])
		if shown.is_empty() or CellMesher.digest(shown) != CellMesher.digest(fresh):
			off += 1
		var fresh_verts: PackedVector3Array = fresh[0]
		if view.parts.has(r) != (fresh_verts.size() > 0):
			off += 1
	return off


## The native mesher gives the oracle's bytes for every block, uncarved and carved.
func _check_native_matches_oracle() -> void:
	if not _native:
		check(true, "native mesher not built: skipped")
		return
	var blocks := 0
	var off := 0
	for f: Array in FIXTURES:
		var oracle := _mesher(f, false)
		var fast := _mesher(f, true)
		check(
			fast.native != null and oracle.native == null,
			"%s: one path native, one GDScript" % f[0]
		)
		var cells := BuildingCells.new(_building(f), _party(f)).cells
		for step: int in CARVE_AT.size() + 1:
			if step > 0:
				CellFaces.carve(cells, oracle.dims, CARVE_AT[step - 1], CARVE_R[step - 1])
			for r: Vector3i in oracle.all_regions():
				blocks += 1
				var a := CellMesher.digest(oracle.mesh_region_gd(cells, r))
				if a != CellMesher.digest(fast.mesh_region(cells, r)):
					off += 1
	check(
		off == 0,
		(
			"native == GDScript on %d blocks of %d fixtures, uncarved and through the carves (%d off)"
			% [blocks, FIXTURES.size(), off]
		)
	)


## Promoted, a building draws from its grid with the baked shader, and BuildingFade's
## set_opacity still reaches it.
func _check_promote_keeps_fade() -> void:
	var f := _fixture("brick")
	var b := _building(f)
	var view := BuildingView.new(b, Color("8a7f72"), _party(f))
	var cv := view.promote(BuildingCells.new(b, _party(f)))
	cv.flush()
	check(
		view.promote(BuildingCells.new(b, _party(f))) == cv, "promoting twice keeps one cell view"
	)
	check(cv.parts.size() > 0, "the promoted building has region meshes (%d)" % cv.parts.size())
	var mat := cv.material as ShaderMaterial
	check(
		mat != null and mat.shader == BuildingView.SHADER,
		"the region meshes use the baked building shader"
	)
	view.set_opacity(0.4)
	var opacity: Variant = mat.get_shader_parameter("opacity")
	check(
		opacity is float and is_equal_approx(Num.f(opacity), 0.4),
		"set_opacity (BuildingFade) reaches the cell view"
	)
	var shown := 0
	for child: Node in view.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			shown += 1
	check(shown == 0, "the baked chunk meshes are hidden once promoted (%d shown)" % shown)
	view.free()
