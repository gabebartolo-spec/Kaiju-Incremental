extends SceneTree
## Parses and compiles every GDScript file in the project with Godot's own parser, so a
## Godot 3 name an agent wrote (`yield`, `onready` or `export` without @, `instance()`,
## `Spatial`, `KinematicBody`, `rand_range`, `deg2rad`, `PoolStringArray`, ...) or any other
## parse or compile error fails CI's preflight before the test shards start (R 5.6).
##
## Files are found by walking res:// (no list kept by hand); .godot/, .git/, .claude/ and any
## folder holding a .gdignore (Godot's own "not project content" marker, e.g. the harness's
## deliberately broken fixtures) are skipped. Each script is loaded fresh, not from the cache,
## after the first frame so autoload names resolve, and must compile.
## Prints one "BAD <path>" line per failure and "check_scripts: N scripts, F failed".
## Exit code 1 on any failure. The engine's own "SCRIPT ERROR"/"Parse Error" lines name
## the line and the reason; tools/check_scripts.sh fails on those too.
##
##   godot --headless --path . --script res://tools/check_scripts.gd

const SKIP_DIRS: PackedStringArray = [".godot", ".git", ".claude"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var me: Script = get_script()
	var self_path: String = me.resource_path
	var files: PackedStringArray = []
	_collect("res://", files)
	var failed: int = 0
	for path: String in files:
		if path == self_path:
			continue
		if not _compiles(path):
			print("BAD %s" % path)
			failed += 1
	print("check_scripts: %d scripts, %d failed" % [files.size(), failed])
	quit(1 if failed > 0 or files.is_empty() else 0)


func _compiles(path: String) -> bool:
	var res: Resource = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	var script: GDScript = res as GDScript
	# A script that fails to parse or compile still loads, but cannot be instantiated.
	return script != null and script.can_instantiate()


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.include_hidden = false
	if dir.file_exists(".gdignore"):
		return
	for sub: String in dir.get_directories():
		if sub in SKIP_DIRS:
			continue
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.get_extension() == "gd":
			out.append(dir_path.path_join(file))
