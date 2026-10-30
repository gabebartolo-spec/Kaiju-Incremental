extends "res://tests/lib/runner.gd"
## Smoke suite. The typing warnings that keep the engine strict are errors; exactly the
## sanctioned autoloads are registered (a new autoload is a decision); every script in the
## project compiles; the main scene opens headless and stays up.
## Seeded by design: nothing here is random.
##   godot --headless --path . --script tests/run_smoke_tests.gd

const AUTOLOADS: Array[String] = ["Debug", "EventBus", "GameData", "Rng", "SaveSystem", "Settings"]
const HeadLead := preload("res://tests/lib/smoke_head_lead.gd")
const StepTurn := preload("res://tests/lib/smoke_step_turn.gd")
const VehiclesSolid := preload("res://tests/lib/smoke_vehicles_solid.gd")
const BuildingsSolid := preload("res://tests/lib/smoke_buildings_solid.gd")
const TankHeli := preload("res://tests/lib/smoke_tank_heli.gd")
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
	await _t("_check_settings")
	await _t("_check_autoloads")
	await _t("_check_scripts_compile")
	await _t("_check_main_scene")
	await _t("_check_planted_feet")
	await _h("HeadLead", func() -> void: HeadLead.check(check, root))
	await _h("StepTurn", func() -> void: StepTurn.check(check, root))
	await _t("_check_skins_fresh")
	await _t("_check_voxel_skin")
	await _h("Tank", func() -> void: TankHeli.check_tank(check, root))
	await _h("Heli", func() -> void: TankHeli.check_heli(check, root))
	await _h("VehicleParts", func() -> void: VehiclePartsCheck.check(check))
	await _t("_check_air_clear_side")
	await _h("VehiclesSolid", func() -> void: await VehiclesSolid.check(check, root))
	await _h("BuildingsSolid", func() -> void: await BuildingsSolid.check(check, root))
	await _t("_check_crease_pass")


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


## The species the game draws (D-385, read from data): every playable one (Demo.species(), so a
## parked species is left out, #416) and the far skyline beast's (tuning "skyline_rampage").
func _drawn_species() -> Array[String]:
	var out: Array[String] = []
	for def: Dictionary in Demo.species():
		out.append(str(def["id"]))
	var far := Content.section("skyline_rampage")
	var beast := str(far.get("species", ""))
	if far.get("on", false) == true and beast != "" and not out.has(beast):
		out.append(beast)
	return out


## D-041: every rigged kaiju the game draws has a voxel skin baked from its current .kvox and
## .rig.json.
func _check_skins_fresh() -> void:
	var stale: Array[String] = []
	var drawn := _drawn_species()
	check(not drawn.is_empty(), "the data names at least one species to draw")
	for species: String in drawn:
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
	var drawn := _drawn_species()
	for species: String in drawn:
		var def: Dictionary = Content.species_def(species)
		var colors: Dictionary = def["colors"]
		var kaiju := KaijuModel.new(species, colors, "adult")
		root.add_child(kaiju)
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
		kaiju.queue_free()
		await process_frame
	check(
		not drawn.is_empty() and skinned.size() == drawn.size(),
		"every drawn adult (%s) draws as a voxel skin by default (got %s)" % [drawn, skinned]
	)
	check(leaks.is_empty(), "no rig voxels draw under a voxel skin (drawing: %s)" % [leaks])
	check(
		broken.is_empty(),
		"the skin's bone matrices stay finite while walking (broken: %s)" % [broken]
	)
	await _t("_check_skin_mouth")
	VoxelSkin.show_rigid_voxels = true
	var first := str(Content.species()[0]["id"])
	if not drawn.is_empty():
		first = drawn[0]
	var first_def: Dictionary = Content.species_def(first)
	var first_colors: Dictionary = first_def["colors"]
	var rigid := KaijuModel.new(first, first_colors, "adult")
	var none := rigid.find_children("VoxelSkin", "VoxelSkin", true, false).is_empty()
	check(none, "the debug flag draws the rigid voxels instead (no skin)")
	rigid.free()
	VoxelSkin.show_rigid_voxels = false


## The mouth's inside shows on the skin as BipedHead shows it: hidden while a closed jaw rests,
## shown once the jaw is held open (the adolescent has no resting snarl).
func _check_skin_mouth() -> void:
	var rex: Dictionary = Content.species_def("reptilian")
	var rex_colors: Dictionary = rex["colors"]
	var kaiju := KaijuModel.new("reptilian", rex_colors, "adolescent")
	root.add_child(kaiju)
	var skin: VoxelSkin = kaiju.find_children("VoxelSkin", "VoxelSkin", true, false)[0]
	for frame: int in 20:
		kaiju.animate(1.0 / 60.0, 0.0)
	var shut := not skin.mouth_open
	kaiju.jaw_open(true)
	for frame: int in 30:
		kaiju.animate(1.0 / 60.0, 0.0)
	check(
		shut and skin.mouth_open,
		"the skin hides the mouth's inside at a shut rest and shows it with the jaw held open"
	)
	kaiju.queue_free()
	await process_frame


## The croc walks, curves, reverses hard and stands stomping the way the rampage drives it
## (sim speed, heading lerp, stomp beat); no planted foot may slide. Fixed 60 Hz steps, no clock.
func _check_planted_feet() -> void:
	await _t("_check_feet_of", ["reptilian"])


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


## The sim keeps helicopters off the side the game camera actually views from. (That no vehicle
## ever draws see-through is guarded by tests/lib/smoke_vehicles_solid.gd, D-290.)
func _check_air_clear_side() -> void:
	var bearing := rad_to_deg(atan2(CameraTuning.offset().z, CameraTuning.offset().x))
	var air := Num.f(Content.section("air")["camera_bearing"])
	check(
		is_equal_approx(bearing, air),
		(
			"the helicopters' clear side (%.0f deg) is where the camera looks from (%.0f)"
			% [air, bearing]
		)
	)


## The crease pass (crease.gdshader) is built from the look, switched off by it, and does no
## per-frame work of its own: nothing it caches can go stale on a resize, a UI-scale change or
## fullscreen (the shader reads the viewport size and buffers each frame).
func _check_crease_pass() -> void:
	var look := Content.look()
	var shipped: Variant = look["crease_strength"]
	if Num.f(shipped) <= 0.0:  # the look ships it off (D-104): test the pass switched on
		look["crease_strength"] = 0.3
	var crease := CreasePass.make()
	var mat: ShaderMaterial = crease.material_override if crease != null else null
	var wrong: Array[String] = []
	for param: String in CreasePass.KEYS:
		var want := Look.value(str(CreasePass.KEYS[param]))
		if mat == null or not is_equal_approx(Num.f(mat.get_shader_parameter(param)), want):
			wrong.append(param)
	check(
		mat != null and wrong.is_empty() and mat.render_priority == CreasePass.FIRST,
		"the crease pass reads every strength from the look, drawn first (wrong: %s)" % [wrong]
	)
	var script: Script = CreasePass
	var per_frame: Array[String] = []
	for method: Dictionary in script.get_script_method_list():
		if str(method["name"]) in ["_process", "_physics_process", "_notification"]:
			per_frame.append(str(method["name"]))
	check(per_frame.is_empty(), "the crease pass runs no per-frame script (%s)" % [per_frame])
	look["crease_strength"] = shipped
	var kept: Variant = look["crease_strength"]
	look["crease_strength"] = 0.0
	var off := CreasePass.make()
	look["crease_strength"] = kept
	check(off == null, "crease_strength 0 in the look leaves the pass out")
	if crease != null:
		crease.free()
