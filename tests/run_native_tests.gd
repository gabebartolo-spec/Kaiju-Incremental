extends "res://tests/lib/runner.gd"
## Native core suite (WP2): the GDExtension's KaijuCarve gives the same removed-cell counts and
## the same grid digest as the GDScript oracle (the spike's carve_grid.gd algorithm, copied
## below as the test oracle) on one fixed fixture. Skips with a SKIP line where the library is
## not built; CI builds it and sets KAIJU_NATIVE_REQUIRED=1, which turns a missing library
## into a failure. It also holds the tool guard (tools/capture/native_guard.gd, tech debt row 14):
## the library has every class and method native/src binds, the guard names what is missing, and
## every bench and capture tool starts by refusing to run without the library.
##   godot --headless --path . --script tests/run_native_tests.gd

const RES := 4
const UNITS := Vector3i(6, 12, 6)
const EMPTY := 0
const SLAB := 2
const GLASS := 3
const COLUMN := 4
const WALL := 1
## tools/capture scripts that never reach the city or the sim (UI screens, audio, a model bake):
## they run without the library; every other tool starts with the guard.
const GUARD_EXEMPT := {
	"bake_colossus.gd": "bakes the kaiju model to PNGs",
	"capture_headers.gd": "a UI header board",
	"capture_loading.gd": "the loading overlay",
	"capture_title.gd": "the title screen",
	"capture_ui_sounds.gd": "UI sounds",
	"font_board.gd": "a font board",
	"capture_time_setting.gd": "the options menu row",
}
## What a guarded tool's _initialize starts with.
const GUARD_HEAD := "func _initialize() -> void:\n\tif not NativeGuard.ok(self):\n\t\treturn\n"

var _available := false


func suite_name() -> String:
	return "Native"


func run_checks() -> void:
	_available = ClassDB.class_exists("KaijuCarve")
	await _t("_check_loaded")
	await _t("_check_guard_reads_the_sources")
	await _t("_check_guard_names_what_is_missing")
	await _t("_check_tools_start_with_the_guard")
	if _available:
		await _t("_check_library_complete")
		await _t("_check_set_grid")
		await _t("_check_carve_matches_oracle")
		await _t("_check_flood_matches_oracle")
		await _t("_check_replay")


func _check_loaded() -> void:
	if _available:
		check(true, "the KaijuCarve class is registered by the extension")
	elif OS.get_environment("KAIJU_NATIVE_REQUIRED") == "1":
		check(
			false,
			(
				"native library is required here (KAIJU_NATIVE_REQUIRED=1) "
				+ "but KaijuCarve is not registered"
			)
		)
	else:
		print(
			(
				"SKIP: KaijuCarve is not registered; build native/ (see native/SConstruct) "
				+ "to run the native checks"
			)
		)
		check(true, "native library not built: skipped on purpose")


func _check_library_complete() -> void:
	var gone := NativeGuard.lacking()
	check(
		gone.is_empty(),
		"the loaded library has every class and method native/src binds (lacking: %s)" % [gone]
	)


## The guard's list comes from the committed C++, with nothing dropped.
func _check_guard_reads_the_sources() -> void:
	var want := NativeGuard.expected()
	for klass: String in ["KaijuCarve", "KaijuMesher", "KaijuSettle"]:
		var names: Array = want.get(klass, [])
		check(not names.is_empty(), "the guard reads %s's bound methods from native/src" % klass)
	var mesher: Array = want.get("KaijuMesher", [])
	var settle: Array = want.get("KaijuSettle", [])
	check(
		mesher.has("mesh_region") and settle.has("cells"),
		"mesh_region and the native cells generator are on the guard's list"
	)
	var raw := 0
	var dir := DirAccess.open(NativeGuard.SOURCE_DIR)
	for file: String in dir.get_files():
		if file.ends_with(".cpp"):
			var source := FileAccess.get_file_as_string(NativeGuard.SOURCE_DIR.path_join(file))
			raw += source.count("D_METHOD(")
	var parsed := 0
	for klass: String in want:
		var names: Array = want[klass]
		parsed += names.size()
	check(raw > 10 and raw == parsed, "the guard reads all %d bound methods (read %d)" % [raw, parsed])


## A known-bad table names exactly what is missing; a good one is clean (built-in classes, so it
## holds with or without the library).
func _check_guard_names_what_is_missing() -> void:
	var bad := NativeGuard.lacking({"Node": ["add_child", "no_such_method"], "NoSuchClass": ["x"]})
	check(
		bad == ["Node.no_such_method (method missing)", "NoSuchClass (class not registered)"],
		"a missing method and a missing class are named: %s" % [bad]
	)
	check(NativeGuard.lacking({"Node": ["add_child"]}).is_empty(), "a complete table is clean")
	var text := NativeGuard.refusal(["X"])
	check(
		text.contains("tools/native_dll.sh") and text.contains(NativeGuard.OPTIONAL_ENV),
		"a refusal says how to fix it and how to run on the GDScript path on purpose"
	)


## Every bench and capture tool refuses to run without the library: its _initialize starts with
## the guard, or it is on the exempt list (and that list holds no tool that guards).
func _check_tools_start_with_the_guard() -> void:
	var bad: Array[String] = []
	var scanned := 0
	var seen_exempt := 0
	var dir := DirAccess.open("res://tools/capture")
	for file: String in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://tools/capture/" + file)
		if not text.contains("func _initialize() -> void:"):
			continue
		scanned += 1
		if GUARD_EXEMPT.has(file):
			seen_exempt += 1
			if text.contains("NativeGuard.ok("):
				bad.append("%s is exempt but guards" % file)
		elif not text.contains(GUARD_HEAD):
			bad.append("%s does not start with the guard" % file)
	check(
		scanned > 50 and seen_exempt == GUARD_EXEMPT.size() and bad.is_empty(),
		(
			"%d tools scanned, %d exempt of %d listed; unguarded: %s"
			% [scanned, seen_exempt, GUARD_EXEMPT.size(), bad]
		)
	)


func _check_set_grid() -> void:
	var k: Object = ClassDB.instantiate("KaijuCarve")
	var ok: bool = k.call("set_grid", PackedByteArray([1, 2, 3]), Vector3i(2, 2, 2))
	check(not ok, "set_grid refuses a grid whose size is not w*h*d")
	var none: int = k.call("carve_sphere", Vector3(1, 1, 1), 3.0)
	check(none == 0, "an empty holder carves nothing")
	var g := _fixture()
	ok = k.call("set_grid", g, _dims())
	check(ok, "set_grid takes a matching grid")
	var back: PackedByteArray = k.call("get_grid")
	check(hash(back) == hash(g), "get_grid returns the grid unchanged")


func _check_carve_matches_oracle() -> void:
	var oracle := _fixture()
	var k: Object = ClassDB.instantiate("KaijuCarve")
	k.call("set_grid", _fixture(), _dims())
	for s: Array in _spheres():
		var c: Vector3 = s[0]
		var r: float = s[1]
		var want := _oracle_carve(oracle, c, r)
		var got: int = k.call("carve_sphere", c, r)
		check(got == want, "carve_sphere %s r=%s removed %d, oracle %d" % [c, r, got, want])
		check(want > 0, "fixture sphere %s r=%s hits something" % [c, r])
	var after: PackedByteArray = k.call("get_grid")
	check(hash(after) == hash(oracle), "grid digest after the carves equals the oracle's")


func _check_flood_matches_oracle() -> void:
	var oracle := _fixture()
	var k: Object = ClassDB.instantiate("KaijuCarve")
	k.call("set_grid", _fixture(), _dims())
	var cut: Array = _spheres()[0]
	var cc: Vector3 = cut[0]
	var cr: float = cut[1]
	_oracle_carve(oracle, cc, cr)
	k.call("carve_sphere", cc, cr)
	var want := _oracle_flood(oracle)
	var got: int = k.call("ground_flood")
	check(want > 0, "the cut leaves floating cells (%d)" % want)
	check(got == want, "ground_flood removed %d, oracle %d" % [got, want])
	var after: PackedByteArray = k.call("get_grid")
	check(hash(after) == hash(oracle), "grid digest after the flood equals the oracle's")


func _check_replay() -> void:
	var digests: Array[int] = []
	for run: int in 2:
		var k: Object = ClassDB.instantiate("KaijuCarve")
		k.call("set_grid", _fixture(), _dims())
		for s: Array in _spheres():
			var c: Vector3 = s[0]
			var r: float = s[1]
			k.call("carve_sphere", c, r)
			k.call("ground_flood")
		var end: PackedByteArray = k.call("get_grid")
		digests.append(hash(end))
	check(digests[0] == digests[1], "two native runs of the same carves end in the same grid")


# ---- fixture and oracle -------------------------------------------------------------------


func _dims() -> Vector3i:
	return Vector3i(UNITS.x * RES, UNITS.y * RES, UNITS.z * RES)


## Centres and radii in cell units, exact in float32 so the oracle and C++ agree bit for bit.
func _spheres() -> Array:
	return [
		[Vector3(12.0, 24.0, 12.0), 18.0],
		[Vector3(3.5, 6.25, 20.0), 6.0],
		[Vector3(20.0, 40.0, 4.0), 5.0],
	]


## The spike's hollow block: slab per floor, shell with window bands, interior columns.
func _fixture() -> PackedByteArray:
	var d := _dims()
	var cells := PackedByteArray()
	cells.resize(d.x * d.y * d.z)
	for y: int in d.y:
		for z: int in d.z:
			for x: int in d.x:
				var edge := x == 0 or z == 0 or x == d.x - 1 or z == d.z - 1
				var m := EMPTY
				if y % RES == 0:
					m = SLAB
				elif edge:
					m = GLASS if (y % RES >= 2 and (x + z) % RES != 0 and y >= RES) else WALL
				elif x % (2 * RES) == RES and z % (2 * RES) == RES:
					m = COLUMN
				cells[x + z * d.x + y * d.x * d.z] = m
	return cells


## carve_grid.gd's sphere pass (test oracle), in cell units.
func _oracle_carve(cells: PackedByteArray, c: Vector3, r: float) -> int:
	var d := _dims()
	var removed := 0
	var r2 := r * r
	for y: int in range(maxi(0, int(floorf(c.y - r))), mini(d.y, int(ceilf(c.y + r)) + 1)):
		for z: int in range(maxi(0, int(floorf(c.z - r))), mini(d.z, int(ceilf(c.z + r)) + 1)):
			for x: int in range(maxi(0, int(floorf(c.x - r))), mini(d.x, int(ceilf(c.x + r)) + 1)):
				var i := x + z * d.x + y * d.x * d.z
				if (
					cells[i] != EMPTY
					and Vector3(x + 0.5, y + 0.5, z + 0.5).distance_squared_to(c) <= r2
				):
					cells[i] = EMPTY
					removed += 1
	return removed


## carve_grid.gd's _grounded flood plus removal of everything it did not reach (test oracle).
func _oracle_flood(cells: PackedByteArray) -> int:
	var d := _dims()
	var plan := d.x * d.z
	var seen := PackedByteArray()
	seen.resize(cells.size())
	var stack: Array[int] = []
	for i: int in plan:
		if cells[i] != EMPTY:
			seen[i] = 1
			stack.append(i)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % d.x
		var z := (i / d.x) % d.z
		var y := i / plan
		for n: int in [
			i - 1 if x > 0 else -1,
			i + 1 if x < d.x - 1 else -1,
			i - d.x if z > 0 else -1,
			i + d.x if z < d.z - 1 else -1,
			i - plan if y > 0 else -1,
			i + plan if y < d.y - 1 else -1
		]:
			if n >= 0 and seen[n] == 0 and cells[n] != EMPTY:
				seen[n] = 1
				stack.append(n)
	var removed := 0
	for i: int in cells.size():
		if cells[i] != EMPTY and seen[i] == 0:
			cells[i] = EMPTY
			removed += 1
	return removed
