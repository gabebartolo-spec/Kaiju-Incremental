extends "res://tests/lib/runner.gd"
## Smoke suite. The typing warnings that keep the engine strict are errors; exactly the
## sanctioned autoloads are registered (a new autoload is a decision); every script in the
## project compiles; the main scene opens headless and stays up.
## Seeded by design: nothing here is random.
##   godot --headless --path . --script tests/run_smoke_tests.gd

const AUTOLOADS: Array[String] = ["Debug", "EventBus", "GameData", "Rng", "SaveSystem", "Settings"]
const FRAMES_UP := 3
## Planted feet may drift at most this share of the hip height over a walk with hard turns.
const MAX_FOOT_DRIFT := 0.02
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
	await _check_planted_feet()
	_check_skins_fresh()
	await _check_voxel_skin()


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


## D-041: every rigged kaiju has a voxel skin baked from its current .kvox and .rig.json.
func _check_skins_fresh() -> void:
	var stale: Array[String] = []
	for species: String in ["reptilian", "insectoid", "cephalopod"]:
		for stage: String in ["baby", "adolescent", "adult"]:
			var base := "res://assets/kaiju/%s_%s" % [species, stage]
			if not FileAccess.file_exists(base + ".rig.json"):
				continue
			if VoxelSkin.baked_stamp(base) != VoxelSkin.source_stamp(base):
				stale.append(base.get_file())
	check(
		stale.is_empty(),
		(
			"every kaiju's voxel skin matches its rig (stale: %s; run tools/kaiju_skin/bake_all.sh)"
			% [stale]
		)
	)


## D-041: kaiju draw as voxel cubes on a smooth skin by default; the rig's own voxels draw nothing;
## the skin follows the pose (finite matrices) and shows the mouth's inside when the jaw drops; the
## debug flag brings back the rigid voxels.
func _check_voxel_skin() -> void:
	var skinned: Array[String] = []
	var leaks: Array[String] = []
	var broken: Array[String] = []
	var mouth := false
	for species: String in ["reptilian", "insectoid", "cephalopod"]:
		var def: Dictionary = Content.species_def(species)
		var colors: Dictionary = def["colors"]
		var kaiju := KaijuModel.new(species, colors, "adult")
		root.add_child(kaiju)
		if species == "reptilian":
			kaiju.jaw_open(true)
		for frame: int in 40:
			kaiju.position.z -= 0.05
			kaiju.animate(1.0 / 60.0, 1.0)
		var skins := kaiju.find_children("VoxelSkin", "VoxelSkin", true, false)
		if not skins.is_empty():
			var skin: VoxelSkin = skins[0]
			skinned.append(species)
			for node: Node in kaiju.find_children("*", "MultiMeshInstance3D", true, false):
				if not skin.is_ancestor_of(node) and (node as MultiMeshInstance3D).layers != 0:
					leaks.append("%s/%s" % [species, node.get_parent().name])
			for m: Projection in skin.pose:
				if not (
					m.x.is_finite() and m.y.is_finite() and m.z.is_finite() and m.w.is_finite()
				):
					broken.append(species)
					break
			if species == "reptilian":
				mouth = skin.mouth_open
		kaiju.queue_free()
		await process_frame
	check(
		skinned.size() == 3, "all three adults draw as a voxel skin by default (got %s)" % [skinned]
	)
	check(leaks.is_empty(), "no rig voxels draw under a voxel skin (drawing: %s)" % [leaks])
	check(
		broken.is_empty(),
		"the skin's bone matrices stay finite while walking (broken: %s)" % [broken]
	)
	check(mouth, "the reptile's held-open jaw shows the mouth's inside on the skin")
	KaijuModel.show_rigid_voxels = true
	var rex: Dictionary = Content.species_def("reptilian")
	var rex_colors: Dictionary = rex["colors"]
	var rigid := KaijuModel.new("reptilian", rex_colors, "adult")
	var none := rigid.find_children("VoxelSkin", "VoxelSkin", true, false).is_empty()
	check(none, "the debug flag draws the rigid voxels instead (no skin)")
	rigid.free()
	KaijuModel.show_rigid_voxels = false


## Each legged kaiju walks, curves, reverses hard and stands stomping the way the rampage drives it
## (sim speed, heading lerp, stomp beat); no planted foot may slide. Fixed 60 Hz steps, no clock.
func _check_planted_feet() -> void:
	for species: String in ["reptilian", "insectoid"]:
		await _check_feet_of(species)


func _check_feet_of(species_id: String) -> void:
	var def: Dictionary = Content.species_def(species_id)
	var stats: Dictionary = def["stats"]
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new(species_id, colors, "adult")
	kaiju.scale = Vector3.ONE * 1.3
	root.add_child(kaiju)
	var dt := 1.0 / 60.0
	var pos := Vector2.ZERO
	var facing := Vector2(0, -1)
	var stomp_in := 0.0
	for frame: int in 600:
		var t := frame * dt
		var move := Vector2.ZERO
		if t > 0.5 and t < 3.0:
			move = Vector2(0, -1)
		elif t >= 3.0 and t < 5.0:
			move = Vector2(0.4, 1).normalized()  # a hard reversal
		elif t >= 5.0 and t < 7.0:
			move = Vector2(-1, 0)
		if move != Vector2.ZERO:
			pos += move * Num.f(stats["speed"]) * dt
			facing = move
		kaiju.position = kaiju.position.lerp(Vector3(pos.x, 0, pos.y), minf(1.0, dt * 12.0))
		var heading := atan2(-facing.x, -facing.y)
		kaiju.rotation.y = lerp_angle(kaiju.rotation.y, heading, minf(1.0, dt * 10.0))
		stomp_in -= dt
		if stomp_in <= 0.0:
			stomp_in += Num.f(stats["stomp_interval"])
			kaiju.stomp()
		kaiju.animate(dt, move.length())
	var drift := kaiju.foot_drift()
	var hip := kaiju.hip_height()
	check(
		hip > 0.0 and drift <= MAX_FOOT_DRIFT * hip,
		(
			"the reptilian's planted feet hold (drift %.3f <= %.3f units)"
			% [drift, MAX_FOOT_DRIFT * hip]
		)
	)
	kaiju.queue_free()
	await process_frame
