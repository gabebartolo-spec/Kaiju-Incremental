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
	_check_tank()
	_check_heli()
	_check_vehicle_fade()


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


## The reptilian walks, curves, reverses hard and stands stomping the way the rampage drives it
## (sim speed, heading lerp, stomp beat); no planted foot may slide. Fixed 60 Hz steps, no clock.
func _check_planted_feet() -> void:
	var def: Dictionary = Content.species_def("reptilian")
	var stats: Dictionary = def["stats"]
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, "adult")
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
	var eye := Rampage.CAMERA_OFFSET
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
	var bearing := rad_to_deg(atan2(Rampage.CAMERA_OFFSET.z, Rampage.CAMERA_OFFSET.x))
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
