extends "res://tests/lib/runner.gd"
## Smoke suite. The typing warnings that keep the engine strict are errors; exactly the
## sanctioned autoloads are registered (a new autoload is a decision); every script in the
## project compiles; the main scene opens headless and stays up.
## Seeded by design: nothing here is random.
##   godot --headless --path . --script tests/run_smoke_tests.gd

const AUTOLOADS: Array[String] = ["Debug", "EventBus", "GameData", "Rng", "SaveSystem", "Settings"]
const FRAMES_UP := 3
const WARNING_AS_ERROR := 2
const STRICT_WARNINGS: Array[String] = [
	"debug/gdscript/warnings/untyped_declaration",
	"debug/gdscript/warnings/unsafe_property_access",
	"debug/gdscript/warnings/unsafe_method_access",
	"debug/gdscript/warnings/unsafe_cast",
	"debug/gdscript/warnings/unsafe_call_argument",
]


func suite_name() -> String:
	return "Smoke"


func run_checks() -> void:
	_check_settings()
	_check_autoloads()
	_check_scripts_compile()
	await _check_main_scene()


func _check_settings() -> void:
	for key: String in STRICT_WARNINGS:
		var level: int = ProjectSettings.get_setting(key, 0)
		check(level == WARNING_AS_ERROR, "%s is an error (2), not %d" % [key, level])


func _check_autoloads() -> void:
	var names: Array[String] = []
	for property: Dictionary in ProjectSettings.get_property_list():
		var key: String = property["name"]
		if key.begins_with("autoload/"):
			names.append(key.trim_prefix("autoload/"))
	names.sort()
	var expected: Array[String] = AUTOLOADS.duplicate()
	expected.sort()
	check(names == expected, "the autoloads are exactly %s, not %s" % [expected, names])


## One check for all scripts, so adding or deleting a script never moves the floor;
## a failure names every script that did not compile.
func _check_scripts_compile() -> void:
	var paths: Array[String] = []
	_collect_scripts("res://", paths)
	var broken: Array[String] = []
	for path: String in paths:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			broken.append(path)
	check(paths.size() > 0, "the project has scripts to compile")
	check(broken.is_empty(), "all %d scripts compile, broken: %s" % [paths.size(), broken])


## Skips folders holding a .gdignore (tests/fixtures/compile/ keeps a deliberately broken
## script there) and hidden folders such as .godot/.
func _collect_scripts(dir_path: String, into: Array[String]) -> void:
	if FileAccess.file_exists(dir_path.path_join(".gdignore")):
		return
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "gd":
			into.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		if not sub.begins_with("."):
			_collect_scripts(dir_path.path_join(sub), into)


func _check_main_scene() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	check(ResourceLoader.exists(path), "the main scene is set and exists, not '%s'" % path)
	if not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path) as PackedScene
	check(packed != null and packed.can_instantiate(), "%s loads as a scene" % path)
	if packed == null or not packed.can_instantiate():
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	for _frame: int in FRAMES_UP:
		await process_frame
	check(scene.is_inside_tree(), "%s stays up for %d frames" % [path, FRAMES_UP])
	scene.queue_free()
	await process_frame
