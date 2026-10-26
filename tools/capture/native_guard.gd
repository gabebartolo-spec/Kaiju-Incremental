class_name NativeGuard
extends RefCounted
## The native-library check every bench and capture tool makes before it runs (tech debt row 14,
## D-295). A missing or stale DLL does not fail the game: CellMesher and VoxelSupport quietly fall
## back to their GDScript oracles, so a bench times the slow path and a capture shows a build the
## player never sees. A tool starts with
##   if not NativeGuard.ok(self): return
## and ok() prints what is missing, quits with exit code 2 and returns false.
##
## "Stale" is read from the committed C++, not a hand-kept list: every class that native/src
## registers (`Class::_bind_methods`) and every method it binds (`D_METHOD("name"`) must exist in
## ClassDB, so a DLL built before a method was added is refused. A DLL built from the same
## methods but older logic is caught by tools/native_dll.sh (md5 against main's CI build).

## Where the C++ sources are (a tool runs from the repo, never from an export).
const SOURCE_DIR := "res://native/src"
## Set to 1 to run on the GDScript path on purpose (a fallback measurement, no DLL on this PC).
const OPTIONAL_ENV := "KAIJU_NATIVE_OPTIONAL"
## The exit code of a refused run (1 is the window check's).
const EXIT_CODE := 2


## Class name -> the method names its `_bind_methods` registers, read from native/src/*.cpp.
static func expected() -> Dictionary:
	var out := {}
	var klass := RegEx.create_from_string("void\\s+(\\w+)::_bind_methods")
	var method := RegEx.create_from_string('D_METHOD\\(\\s*"(\\w+)"')
	var dir := DirAccess.open(SOURCE_DIR)
	if dir == null:
		return out
	for file: String in dir.get_files():
		if not file.ends_with(".cpp"):
			continue
		var text := FileAccess.get_file_as_string(SOURCE_DIR.path_join(file))
		var heads := klass.search_all(text)
		for i in heads.size():
			var stop := heads[i + 1].get_start() if i + 1 < heads.size() else text.length()
			var body := text.substr(heads[i].get_end(), stop - heads[i].get_end())
			var names: Array[String] = []
			for hit: RegExMatch in method.search_all(body):
				names.append(hit.get_string(1))
			out[heads[i].get_string(1)] = names
	return out


## What the loaded library lacks of `table` (default: expected()): "KaijuSettle (class not
## registered)" or "KaijuSettle.cells (method missing)". Empty when it is complete.
static func lacking(table: Dictionary = {}) -> Array[String]:
	var want := table if not table.is_empty() else expected()
	var out: Array[String] = []
	if want.is_empty():
		out.append("%s has no registered classes to check against" % SOURCE_DIR)
	for klass: String in want:
		if not ClassDB.class_exists(klass):
			out.append("%s (class not registered)" % klass)
			continue
		for method: String in want[klass]:
			if not ClassDB.class_has_method(klass, method, true):
				out.append("%s.%s (method missing)" % [klass, method])
	return out


## True when the run may go on. Otherwise prints why, quits with EXIT_CODE and returns false:
## the caller returns at once.
static func ok(tree: SceneTree) -> bool:
	if OS.get_environment(OPTIONAL_ENV) == "1":
		return true
	var gone := lacking()
	if gone.is_empty():
		return true
	printerr(refusal(gone))
	tree.quit(EXIT_CODE)
	return false


## The message of a refused run.
static func refusal(gone: Array[String]) -> String:
	return (
		"NATIVE LIBRARY NOT LOADED, refusing to run: this tool would time or show the slow "
		+ "GDScript mesher and flood, not what the game runs.\n  lacking: %s\n" % ", ".join(gone)
		+ "  fix: bash tools/native_dll.sh fetch (main's CI build), or build native/ "
		+ "(native/SConstruct), then import once.\n"
		+ "  on the GDScript path on purpose: %s=1" % OPTIONAL_ENV
	)
