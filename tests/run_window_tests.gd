extends "res://tests/lib/runner.gd"
## Window palette suite (render plan item 6, looks window_palette_on): the look's lit-window
## palette is valid data; a lit window keeps its colour and brightness when its building is
## promoted to the cell grid (the shader's pick, redone on the CPU by WindowPalette, on the baked
## shell's window faces equals the pick on the cell meshes' faces of the same cells); the shader
## holds the replica's hash; the stand-in and skyline facades box-filter their windows
## (render_opt.facade_aa, tests/lib/facade_filter.gd); a stand-in's lit window holds whole
## (tests/lib/facade_flat.gd).
## Seeded by design: fixed buildings, a fixed hash; no RNG.
##   godot --headless --path . --script tests/run_window_tests.gd

const FacadeFilter := preload("res://tests/lib/facade_filter.gd")
const FacadeFlat := preload("res://tests/lib/facade_flat.gd")

## Each fixture: [name, x, z, w, d, floors, tier, style] (as the cell mesh suite's).
const FIXTURES: Array = [
	["office", 10.5, 4.5, 3, 3, 6, 2, 0],
	["brick", 20.5, 4.5, 3, 2, 5, 1, 1],
	["glass", 30.0, 6.0, 4, 4, 12, 3, 2],
]


func suite_name() -> String:
	return "Window palette"


func run_checks() -> void:
	await _t("_check_window_palette_data")
	await _t("_check_window_colour_survives_promote")
	await _t("_check_window_shader_is_the_replica")
	await _t("_check_window_key_off_unit_edges")
	await _t("_check_facade_windows_filtered")
	await _t("_check_facade_windows_hold_whole")


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


func _party(_f: Array) -> Dictionary:
	return {}


func _fixture(name: String) -> Array:
	for f: Array in FIXTURES:
		if f[0] == name:
			return f
	return []


func _part(view: CellView, r: Vector3i) -> MeshInstance3D:
	var part: MeshInstance3D = view.parts[r]
	return part


## Lived-in windows (render plan item 6): the look's palette shares sum to 1, its gain range is
## ordered, and it is on by default.
func _check_window_palette_data() -> void:
	var look: Dictionary = Content.looks()[0]
	var raw: Array = look.get("window_lit_palette", [])
	var total := 0.0
	for entry: Array in raw:
		total += Num.f(entry[1])
	check(
		raw.size() >= 2 and raw.size() <= WindowPalette.MAX and absf(total - 1.0) < 1e-6,
		(
			"the window palette has 2-%d colours whose shares sum to 1 (%d, %.6f)"
			% [WindowPalette.MAX, raw.size(), total]
		)
	)
	var gain := WindowPalette.gain()
	check(gain.x > 0.0 and gain.x <= gain.y, "the window gain range is ordered (%s)" % gain)
	check(Num.f(look.get("window_palette_on", 0)) > 0.5, "window_palette_on is on by default")


## A lit window keeps its colour and brightness when its building is promoted to the cell grid:
## the shader's pick (WindowPalette's replica) on the baked shell's window faces equals the pick
## on the cell meshes' faces of the same cells, each with its own material's uniforms.
func _check_window_colour_survives_promote() -> void:
	for name: String in ["office", "glass", "brick"]:
		var f := _fixture(name)
		var b := _building(f)
		var view := BuildingView.new(b, Color("8a7f72"), _party(f))
		var shell_mat := view._shell_mat
		var before := {}
		_window_picks(view.mesher.shell, shell_mat, before)
		var cv := view.promote(BuildingCells.new(b, _party(f)))
		cv.flush()
		var cells_mat := cv.material as ShaderMaterial
		var after := {}
		for r: Vector3i in cv.parts:
			_window_picks(_part(cv, r).mesh, cells_mat, after)
		var same := 0
		var off := 0
		var colours := {}
		for cell: Vector3i in before:
			colours[before[cell][0]] = true
			if not after.has(cell):
				continue
			var a: Array = before[cell]
			var c: Array = after[cell]
			if a[0] == c[0] and is_equal_approx(Num.f(a[1]), Num.f(c[1])):
				same += 1
			else:
				off += 1
		var on: bool = str(shell_mat.get_shader_parameter("window_palette_on")) == "true"
		var cells_on: bool = str(cells_mat.get_shader_parameter("window_palette_on")) == "true"
		check(
			on and cells_on,
			"%s: the shell and the cell grid draw with the window palette on" % name
		)
		check(
			same > 0 and off == 0,
			(
				"%s: every lit window cell keeps its pick after promote (%d same, %d changed)"
				% [name, same, off]
			)
		)
		check(
			colours.size() >= 2,
			"%s: its lit windows take more than one colour (%d)" % [name, colours.size()]
		)
		view.free()


## Window faces of `mesh` (colour alpha WindowPalette.TAG): cell -> [palette index, gain], picked
## with `mat`'s window uniforms. Empty when the material has no window uniforms (main).
func _window_picks(mesh: Mesh, mat: ShaderMaterial, out: Dictionary) -> void:
	var raw_align: Variant = mat.get_shader_parameter("window_align")
	var raw_unit: Variant = mat.get_shader_parameter("window_unit")
	if not (raw_align is Vector2 and raw_unit is Vector2):
		return
	var align: Vector2 = raw_align
	var unit: Vector2 = raw_unit
	var voxel := BuildingVoxels.VOXEL
	for s: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for q: int in range(0, verts.size(), 4):
			if absf(colors[q].a - WindowPalette.TAG) > 0.5 / 255.0:
				continue
			var centre := (verts[q] + verts[q + 1] + verts[q + 2] + verts[q + 3]) * 0.25
			var n := normals[q]
			var cell := Vector3i(((centre - n * voxel * 0.5) / voxel).floor())
			var key := WindowPalette.window_key(centre, n, align, unit)
			out[cell] = WindowPalette.pick(WindowPalette.window_hash(key))


## The shader holds the replica's hash: the same mixing constants, edge and palette size, and
## the building shader tests the window tag.
func _check_window_shader_is_the_replica() -> void:
	var src := FileAccess.get_file_as_string("res://scenes/window_palette.gdshaderinc")
	var expected: Array[String] = [
		"x *= %du;" % WindowPalette.MIX_A,
		"x *= %du;" % WindowPalette.MIX_B,
		"(vec3(1.0) - abs(n)) * vec3(window_voxel * %s)" % str(WindowPalette.EDGE),
		"window_palette[%d]" % WindowPalette.MAX,
	]
	var missing: Array[String] = []
	for line: String in expected:
		if not src.contains(line):
			missing.append(line)
	check(
		missing.is_empty(), "window_palette.gdshaderinc carries the replica's hash (%s)" % [missing]
	)
	var baked := FileAccess.get_file_as_string("res://scenes/building_baked.gdshader")
	check(
		baked.contains("window_palette.gdshaderinc") and baked.contains("window_tagged(COLOR.a)"),
		"the building shader includes the window palette and tests the window tag"
	)


## A window face's key holds when its point moves a hair along the normal (the GPU's interpolated
## position does, pixel to pixel): min-side faces (-x, -z) on a unit edge broke into flashing
## stripes while the camera moved (director 10-28, dusk).
func _check_window_key_off_unit_edges() -> void:
	var align := Vector2(0.25, 0.5)
	var unit := Vector2(1.0, 2.0)
	var eps := 0.0001
	var faces: Array = [
		[Vector3(0.25, 3.3, 0.9), Vector3(-1, 0, 0)],
		[Vector3(0.7, 3.3, 0.5), Vector3(0, 0, -1)],
		[Vector3(3.25, 5.1, 1.4), Vector3(1, 0, 0)],
		[Vector3(2.6, 5.1, 4.5), Vector3(0, 0, 1)],
	]
	var split: Array[String] = []
	for face: Array in faces:
		var p: Vector3 = face[0]
		var n: Vector3 = face[1]
		var a := WindowPalette.window_key(p + n * eps, n, align, unit)
		var b := WindowPalette.window_key(p - n * eps, n, align, unit)
		if a != b:
			split.append("%s n %s: %s vs %s" % [p, n, a, b])
	check(split.is_empty(), "a window's key holds across a hair along its normal (%s)" % [split])


## Window filtering on the stand-in and skyline facades (tests/lib/facade_filter.gd).
func _check_facade_windows_filtered() -> void:
	FacadeFilter.new(check).run()


## A stand-in's lit window holds whole (tests/lib/facade_flat.gd).
func _check_facade_windows_hold_whole() -> void:
	FacadeFlat.new(check).run()
