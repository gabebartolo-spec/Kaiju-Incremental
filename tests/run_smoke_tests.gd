extends "res://tests/lib/runner.gd"
## Smoke suite. The typing warnings that keep the engine strict are errors; exactly the
## sanctioned autoloads are registered (a new autoload is a decision); every script in the
## project compiles; the main scene opens headless and stays up.
## Seeded by design: nothing here is random.
##   godot --headless --path . --script tests/run_smoke_tests.gd

const AUTOLOADS: Array[String] = ["Debug", "EventBus", "GameData", "Rng", "SaveSystem", "Settings"]
const HeadLead := preload("res://tests/lib/smoke_head_lead.gd")
const StepTurn := preload("res://tests/lib/smoke_step_turn.gd")
const FRAMES_UP := 3
## Planted feet may drift at most this share of the hip height over a walk with hard turns.
const FeetWalk := preload("res://tests/lib/smoke_feet_walk.gd")
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
	await _t("_check_tank")
	await _t("_check_heli")
	await _t("_check_vehicle_fade")
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
	var mantle_ok := false
	for species: String in ["reptilian", "insectoid", "cephalopod"]:
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
			if species == "cephalopod":
				mantle_ok = _mantle_follows(kaiju, skin)
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
	check(mantle_ok, "the octopus mantle's breathing scale reaches its skin")
	await _t("_check_skin_mouth")
	VoxelSkin.show_rigid_voxels = true
	var rex: Dictionary = Content.species_def("reptilian")
	var rex_colors: Dictionary = rex["colors"]
	var rigid := KaijuModel.new("reptilian", rex_colors, "adult")
	var none := rigid.find_children("VoxelSkin", "VoxelSkin", true, false).is_empty()
	check(none, "the debug flag draws the rigid voxels instead (no skin)")
	rigid.free()
	VoxelSkin.show_rigid_voxels = false


## The mantle voxels' node (which gait_radial scales to breathe) sizes the skin's mantle0 bone.
func _mantle_follows(kaiju: KaijuModel, skin: VoxelSkin) -> bool:
	var rig: KaijuRig = kaiju.find_children("*", "KaijuRig", true, false)[0]
	var held: Variant = rig.skins.get("mantle0", null)
	if not is_instance_valid(held):
		return false
	var mantle: Node3D = held
	mantle.scale = Vector3.ONE * 1.2  # a roar puff
	skin.sync()
	var m := skin.pose[rig.bone_names().find("mantle0")]
	return absf(Vector3(m.x.x, m.x.y, m.x.z).length() - 1.2) < 0.001


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


## Each legged kaiju walks, curves, reverses hard and stands stomping the way the rampage drives it
## (sim speed, heading lerp, stomp beat); no planted foot may slide. A heavy body (the Komodo,
## D-201) moves only as the sim moves it, forward and turning, never crabwise or backing up (lead's
## ruling, 2026-10-24): it is driven by the real sim, as Rampage._update_kaiju feeds it. Fixed
## 60 Hz steps, no clock.
func _check_planted_feet() -> void:
	for species: String in ["reptilian", "insectoid"]:
		await _t("_check_feet_of", [species])


func _check_feet_of(species_id: String) -> void:
	var def: Dictionary = Content.species_def(species_id)
	var colors: Dictionary = def["colors"]
	var kaiju: KaijuModel
	var heavy: Dictionary = KaijuRig.class_of("%s_adult" % species_id).get("sim", {})
	if not heavy.is_empty():
		kaiju = FeetWalk.heavy(root, species_id)
	else:
		kaiju = KaijuModel.new(species_id, colors, "adult")
		kaiju.scale = Vector3.ONE * 1.3
		root.add_child(kaiju)
		var stats: Dictionary = def["stats"]
		FeetWalk.light(kaiju, stats)
	var drift := kaiju.foot_drift()
	var hip := kaiju.hip_height()
	check(
		hip > 0.0 and drift <= MAX_FOOT_DRIFT * hip,
		(
			"the %s's planted feet hold (drift %.3f <= %.3f units)"
			% [species_id, drift, MAX_FOOT_DRIFT * hip]
		)
	)
	kaiju.queue_free()
	await process_frame


## The Blender tank (D-042) loads as hull, turret and gun; the turret swings onto a target at
## the side while the hull stays put, and a shot leaves the muzzle ahead of the hull and kicks the
## gun back.
func _check_tank() -> void:
	var tank := TankModel.new()
	root.add_child(tank)
	var cfg := Content.section("vehicles")
	var counts: Array[int] = []
	for part: Node3D in [tank, tank._turret, tank._barrel]:
		for child: Node in part.get_children():
			if child is MultiMeshInstance3D:
				counts.append((child as MultiMeshInstance3D).multimesh.instance_count)
	check(
		counts.size() == 3 and not counts.has(0) and tank._barrel.get_parent() == tank._turret,
		"the tank is hull > turret > gun, each with voxels: %s" % [counts]
	)
	var target := Vector3(10.0, 1.0, 0.0)  # off the right side
	for _i: int in 120:
		tank.aim(target, 1.0 / 60.0)
	var facing := -tank._turret.global_basis.z
	var want := (target - tank._turret.global_position) * Vector3(1, 0, 1)
	check(
		facing.angle_to(want.normalized()) < 0.05 and tank.rotation.y == 0.0,
		"the turret turns onto a target at the side (off by %.3f rad)" % facing.angle_to(want)
	)
	var rest := tank._barrel.position
	var muzzle := tank.fire()
	tank._process(Num.f(cfg["recoil_seconds"]) * 0.25)
	check(
		muzzle.x > 2.0 and tank._barrel.position.distance_to(rest) > 0.05,
		"the shot leaves the muzzle (%s) and the gun kicks back" % muzzle
	)
	tank.free()


## The Blender helicopter (D-042) loads as body, main rotor, tail rotor and chin gun; both rotors
## spin about their own hubs, and the gun swings onto a target below and ahead with the muzzle
## at the nose.
func _check_heli() -> void:
	var heli := HelicopterModel.new()
	root.add_child(heli)
	var main: Node3D = heli._main_rotor
	var tail: Node3D = heli._tail_rotor
	var hub := main.position
	heli._process(0.1)
	check(
		heli.get_child_count() == 4 and main.rotation.y > 0.5 and tail.rotation.x > 0.5,
		(
			"the rotors spin about their hubs (main %.2f, tail %.2f rad)"
			% [main.rotation.y, tail.rotation.x]
		)
	)
	var target := Vector3(3.0, -6.0, -12.0)
	heli.aim(target)
	var muzzle := heli.fire()
	var aim := -heli._gun.global_basis.z
	check(
		(
			aim.angle_to(target - heli._gun.global_position) < 0.02
			and muzzle.z < -2.0
			and main.position == hub
		),
		"the chin gun aims at a target below and ahead; muzzle at %s" % muzzle
	)
	heli.free()


## A helicopter between the camera and the kaiju fades to the screen door and one off to the side
## stays solid; the sim keeps helicopters off the side the game camera actually views from.
func _check_vehicle_fade() -> void:
	var front := HelicopterModel.new()
	var side := HelicopterModel.new()
	root.add_child(front)
	root.add_child(side)
	var eye := CameraTuning.offset()
	front.position = eye * 0.5
	side.position = Vector3(20, 9, 0)
	var nodes: Array[Node3D] = [front, side]
	var fade := VehicleFade.new(func() -> Array: return [], func() -> Array: return nodes)
	for _i: int in 30:
		fade.update(eye, Vector3.ZERO, 1.0, 1.0 / 30.0)
	var low := Num.f(Content.section("vehicles")["fade_opacity"])
	var a: float = front.get_meta("opacity", 1.0)
	var b: float = side.get_meta("opacity", 1.0)
	check(
		is_equal_approx(a, low) and b == 1.0,
		"a helicopter in front of the kaiju fades to %.2f, one at the side stays %.2f" % [a, b]
	)
	var bearing := rad_to_deg(atan2(CameraTuning.offset().z, CameraTuning.offset().x))
	var air := Num.f(Content.section("air")["camera_bearing"])
	check(
		is_equal_approx(bearing, air),
		(
			"the helicopters' clear side (%.0f deg) is where the camera looks from (%.0f)"
			% [air, bearing]
		)
	)
	front.free()
	side.free()


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
