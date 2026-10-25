extends "res://tests/lib/runner.gd"
## One look, phase 1 (D-163): the far blur and the block-grain ground (the grade and the haze stay as
## today, D-221). The lowest presets drop the blur; the blur's focus follows the kaiju and never
## blurs him or anything nearer; the ground shader takes its numbers from the look. Seeded by design:
## nothing here is random.
##   godot --headless --path . --script tests/run_onelook_tests.gd

const PHASE_ONE_KEYS: Array[String] = ["far_blur_amount", "far_blur_start", "far_blur_ramp"]


func suite_name() -> String:
	return "OneLook"


func run_checks() -> void:
	await _t("_check_look_keys")
	await _t("_check_presets")
	await _t("_check_far_depth")
	await _t("_check_ground_numbers")



func _check_look_keys() -> void:
	Content.set_time("dusk")
	var missing: Array[String] = []
	for key: String in PHASE_ONE_KEYS:
		if not Content.look().has(key):
			missing.append(key)
	for key: String in CityGround.BLOCK_KEYS:
		if not Content.look().has("ground_" + key):
			missing.append("ground_" + key)
	check(missing.is_empty(), "the look carries every phase 1 number: %s" % [missing])





func _check_presets() -> void:
	var table: Dictionary = Content.section("display")["graphics"]
	var bad: Array[String] = []
	for name: String in table:
		var row: Dictionary = table[name]
		var quality := GraphicsPresets.far_blur(row)
		if name in ["potato", "low"] and quality >= 0:
			bad.append("%s keeps the blur" % name)
		if name in ["medium", "high", "max"] and quality < 0:
			bad.append("%s drops the blur" % name)
	check(bad.is_empty(), "the lowest presets drop the blur, Medium and up keep it: %s" % [bad])
	check(
		GraphicsPresets.errors(table).is_empty(),
		"every preset row is whole: %s" % [GraphicsPresets.errors(table)]
	)
	var saved := PlayerSettings.graphics
	PlayerSettings.graphics = "potato"
	Content.set_time("dusk")
	var camera := Camera3D.new()
	FarDepth.new(camera)
	check(camera.attributes == null, "on Potato the camera has no blur")
	PlayerSettings.graphics = saved
	camera.free()


func _check_far_depth() -> void:
	var saved := PlayerSettings.graphics
	PlayerSettings.graphics = "medium"
	Content.set_time("dusk")
	var camera := Camera3D.new()
	root.add_child(camera)
	var blur := FarDepth.new(camera)
	var attrs := camera.attributes as CameraAttributesPractical
	check(attrs != null and attrs.dof_blur_far_enabled, "Medium puts a far blur on the game camera")
	if attrs == null:
		return
	check(not attrs.dof_blur_near_enabled, "there is never a near blur (no band, no tilt-shift)")
	var seen: Array[float] = []
	for z: float in [-12.0, -20.0, -35.0]:
		blur.follow(Vector3(0.0, 0.0, z))  # the camera looks down -z from the origin
		seen.append(attrs.dof_blur_far_distance)
		check(
			attrs.dof_blur_far_distance > absf(z),
			(
				"the kaiju at %.0f m is nearer than where the blur starts (%.1f m)"
				% [absf(z), attrs.dof_blur_far_distance]
			)
		)
	check(
		seen[0] < seen[1] and seen[1] < seen[2],
		"the focus follows the kaiju as he walks away: %s" % [seen]
	)
	# Off to the side the distance along the view still counts, not the straight-line distance.
	blur.follow(Vector3(30.0, 0.0, -20.0))
	check(
		is_equal_approx(attrs.dof_blur_far_distance, 20.0 * Look.value("far_blur_start")),
		"depth along the view"
	)
	camera.queue_free()
	PlayerSettings.graphics = saved



func _check_ground_numbers() -> void:
	Content.set_time("dusk")
	var uniforms: Array[String] = []
	for u: Dictionary in CityGround.BLOCKS.get_shader_uniform_list():
		uniforms.append(str(u["name"]))
	var bad: Array[String] = []
	for key: String in CityGround.BLOCK_KEYS:
		if not key in uniforms:
			bad.append(key)
	check(bad.is_empty(), "every ground number is a uniform of the block shader: %s" % [bad])
	check(
		is_equal_approx(Look.value("ground_block"), 0.125),
		"the ground's block is the city's voxel grain, 0.125 m"
	)
	var mat := CityGround.block_material()
	check(
		is_equal_approx(
			Num.f(mat.get_shader_parameter("block_noise")), Look.value("ground_block_noise")
		),
		"the material carries the look's numbers"
	)
