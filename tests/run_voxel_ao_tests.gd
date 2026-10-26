extends "res://tests/lib/runner.gd"
## Voxel AO suite (render plan item 12, looks R2 + R5): the building meshers bake per-corner
## ambient occlusion and a material finish into UV. Every region mesh carries a UV per vertex and
## the native == GDScript digest covers it; the AO ladder on a 3x3x3 fixture with a known inside
## corner (floor, back wall and side wall meeting) gives the 0fps levels 0..3, and a quad splits
## along its brighter diagonal; the baked shell and slabs agree with the cell mesh (same finish,
## slab AO equal, shell AO never lighter: its hollow counts as solid); every material names a
## finish the look prices; the look's flags reach the building material and off leaves it as before.
## Seeded by design: fixed fixtures; no RNG.
##   godot --headless --path . --script tests/run_voxel_ao_tests.gd

const CellFaces := preload("res://tests/lib/cell_faces.gd")
const AoFaces := preload("res://tests/lib/ao_faces.gd")
## [name, x, z, w, d, floors, tier, style]: an office and a curtain-wall glass tower.
const FIXTURES: Array = [
	["office", 10.5, 4.5, 3, 3, 6, 2, 0],
	["glass", 30.0, 6.0, 4, 4, 12, 3, 2],
]
const UV := 4  # the UV array's place in a region's arrays


func suite_name() -> String:
	return "Voxel AO"


func run_checks() -> void:
	await _t("_check_regions_carry_uv")
	await _t("_check_native_uv_matches_oracle")
	await _t("_check_ao_ladder")
	await _t("_check_split_brighter_diagonal")
	await _t("_check_baked_agrees_with_cells")
	await _t("_check_materials_have_finish")
	await _t("_check_look_reaches_material")


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


func _mesher(f: Array, use_native: bool) -> CellMesher:
	var b := _building(f)
	return CellMesher.new(BuildingVoxels.new(b, Color("8a7f72")), BuildingCells.new(b), use_native)


## Every region's arrays hold a UV per vertex, and the digest changes when one UV does.
func _check_regions_carry_uv() -> void:
	var m := _mesher(FIXTURES[0], false)
	var cells := BuildingCells.new(_building(FIXTURES[0])).cells
	var bad := 0
	var meshed := 0
	var digest_covers := false
	for r: Vector3i in m.all_regions():
		var arrays := m.mesh_region_gd(cells, r)
		var verts: PackedVector3Array = arrays[0]
		if verts.is_empty():
			continue
		meshed += 1
		if arrays.size() <= UV:
			bad += 1
			continue
		var got: PackedVector2Array = arrays[UV]
		if got.size() != verts.size():
			bad += 1
			continue
		var changed := arrays.duplicate(true)
		var uv: PackedVector2Array = changed[UV]
		uv[0] = uv[0] + Vector2(0.5, 0.0)
		changed[UV] = uv
		digest_covers = digest_covers or CellMesher.digest(changed) != CellMesher.digest(arrays)
	check(
		meshed > 0 and bad == 0,
		"every meshed region carries one UV per vertex (%d of %d without)" % [bad, meshed]
	)
	check(digest_covers, "the region digest covers the UV (a changed UV changes it)")


## The native mesher gives the oracle's UV bytes too (the digest covers UV), uncarved and carved.
func _check_native_uv_matches_oracle() -> void:
	if not ClassDB.class_exists("KaijuMesher"):
		check(OS.get_environment("KAIJU_NATIVE_REQUIRED") != "1", "native required but not built")
		print("SKIP: KaijuMesher is not registered; build native/ to run the native UV check")
		return
	var blocks := 0
	var off := 0
	var natives := 0
	for f: Array in FIXTURES:
		var oracle := _mesher(f, false)
		var fast := _mesher(f, true)
		natives += int(fast.native != null)
		var cells := BuildingCells.new(_building(f)).cells
		for step: int in 2:
			if step == 1:
				CellFaces.carve(cells, oracle.dims, Vector3(1.0, 20.0, 6.0), 5.0)
			for r: Vector3i in oracle.all_regions():
				var a := oracle.mesh_region_gd(cells, r)
				var b := fast.mesh_region(cells, r)
				blocks += 1
				if a.size() <= UV or b.size() <= UV or CellMesher.digest(a) != CellMesher.digest(b):
					off += 1
	check(natives == FIXTURES.size(), "the native path ran (%d of %d)" % [natives, FIXTURES.size()])
	check(off == 0, "native == GDScript with UV on %d blocks (%d off)" % [blocks, off])


## The known inside corner: floor (y 0), back wall (z 0) and side wall (x 0) at y 1. The +z face
## of back-wall cell (1, 1, 0) has all four levels; the floor's top at (1, 0, 1) is closed in
## its back-left corner; the side wall's -x face meets the ground (a contact shade, never air).
func _check_ao_ladder() -> void:
	var m := AoFaces.fixture_mesher(_mesher(FIXTURES[0], false))
	var arrays := m.mesh_region_gd(AoFaces.inside_corner(), Vector3i.ZERO)
	if arrays.size() <= UV:
		check(false, "the fixture's region carries UV (no UV array: %d arrays)" % arrays.size())
		return
	var cases: Array = [
		# [cell, normal, {corner sign (two in-plane axes) -> expected level}, what]
		[Vector3i(1, 1, 0), Vector3i(0, 0, 1), AoFaces.XY_LADDER, "back wall face at the corner"],
		[Vector3i(1, 0, 1), Vector3i(0, 1, 0), AoFaces.XZ_FLOOR, "floor top at the corner"],
		[Vector3i(0, 0, 1), Vector3i(-1, 0, 0), AoFaces.YZ_GROUND, "side wall foot on the ground"],
	]
	for c: Array in cases:
		var cell: Vector3i = c[0]
		var normal: Vector3i = c[1]
		var want: Dictionary = c[2]
		var got := AoFaces.corner_levels(m, arrays, cell, normal)
		check(got == want, "%s: corner levels %s (want %s)" % [c[3], got, want])


## Every face of the fixture splits along its brighter diagonal (ties keep the meshers' split);
## both splits occur.
func _check_split_brighter_diagonal() -> void:
	var m := AoFaces.fixture_mesher(_mesher(FIXTURES[0], false))
	var arrays := m.mesh_region_gd(AoFaces.inside_corner(), Vector3i.ZERO)
	if arrays.size() <= UV:
		check(false, "the fixture's region carries UV (no UV array)")
		return
	var uv: PackedVector2Array = arrays[UV]
	var index: PackedInt32Array = arrays[3]
	var counts := AoFaces.splits(uv, index)
	check(counts[0] == 0, "no face splits along its darker diagonal (%d do)" % counts[0])
	check(
		counts[1] > 0 and counts[2] > 0,
		"both splits occur: %d along 0-2, %d flipped to 1-3" % [counts[1], counts[2]]
	)


## The baked shell and slabs and the uncarved cell mesh: same finish on every shared face; slab
## faces (no hollow) the same AO; shell faces never lighter (their hollow counts as solid).
func _check_baked_agrees_with_cells() -> void:
	for f: Array in FIXTURES:
		var b := _building(f)
		var voxels := BuildingVoxels.new(b, Color("8a7f72"))
		var baked := BuildingMesher.new(voxels)
		var cells := BuildingCells.new(b)
		var m := CellMesher.new(voxels, cells, false)
		var now := AoFaces.cell_uvs(m, cells.cells)
		var shell := AoFaces.mesh_uvs(baked.shell)
		var slabs := AoFaces.mesh_uvs(baked.slabs)
		var r := AoFaces.compare(shell, now, false)
		var s := AoFaces.compare(slabs, now, true)
		check(
			r[0] > 0 and s[0] > 0 and r[1] == 0 and s[1] == 0,
			(
				"%s: baked faces carry UV and the cell mesh's finish (%d shell, %d slab; %d, %d off)"
				% [f[0], r[0], s[0], r[1], s[1]]
			)
		)
		check(
			r[2] == 0 and s[2] == 0,
			"%s: slab AO equal, shell AO never lighter (%d shell, %d slab off)" % [f[0], r[2], s[2]]
		)


## Every material names a finish class the look prices (roughness and specular).
func _check_materials_have_finish() -> void:
	var rough: Dictionary = Content.look().get("finish_roughness", {})
	var spec: Dictionary = Content.look().get("finish_specular", {})
	var bad: Array[String] = []
	var used := {}
	for mat: Dictionary in Content.materials():
		var fin := str(mat.get("finish", ""))
		used[fin] = true
		if not (rough.has(fin) and spec.has(fin)):
			bad.append(str(mat["name"]))
	check(bad.is_empty(), "every material has a priced finish (missing: %s)" % [bad])
	check(used.has("glass") and used.has("metal"), "glass and metal finishes are used")
	for fin: String in rough:
		var x := Num.f(rough[fin])
		check(
			x < 0.83 or x > 0.87,
			"finish %s roughness %.2f stays clear of the kaiju tag (0.83-0.87)" % [fin, x]
		)


## BuildingView's material takes the look's AO and finish; with both flags off the uniforms are
## the shader's do-nothing values (AO 1, no light affect, the old roughness).
func _check_look_reaches_material() -> void:
	var look := Content.look()
	var keep := [look.get("voxel_ao_on"), look.get("finish_on")]
	check(
		keep[0] != null and keep[1] != null and Num.f(keep[0]) > 0.0 and Num.f(keep[1]) > 0.0,
		"voxel_ao_on and finish_on are in the look and default ON"
	)
	var view := BuildingView.new(_building(FIXTURES[0]), Color("8a7f72"))
	var on := AoFaces.uniforms(view)
	var on_ao: float = on[0]
	var on_finish: bool = on[2]
	check(
		is_equal_approx(on_ao, Look.value("voxel_ao_strength")) and on_ao > 0.0 and on_finish,
		"on: the shell material has the look's AO strength and the finish (%s)" % [on]
	)
	view.free()
	look["voxel_ao_on"] = 0.0
	look["finish_on"] = 0.0
	view = BuildingView.new(_building(FIXTURES[0]), Color("8a7f72"))
	var off := AoFaces.uniforms(view)
	for k: int in 2:
		var key: String = ["voxel_ao_on", "finish_on"][k]
		if keep[k] == null:
			look.erase(key)
		else:
			look[key] = keep[k]
	var off_ao: float = off[0]
	var off_affect: float = off[1]
	var off_finish: bool = off[2]
	check(
		off_ao == 0.0 and off_affect == 0.0 and not off_finish,
		"off: AO strength 0, light affect 0, finish off (%s)" % [off]
	)
	view.free()
