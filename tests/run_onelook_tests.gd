extends "res://tests/lib/runner.gd"
## One look, phase 1 (D-163): the colour grade, the haze, the far blur and the block-grain ground.
## The grade leans shadows cool and keeps fire warm at every time of day and on every graphics
## preset; a preset may drop the blur, never the grade; the blur's focus follows the kaiju and never
## blurs him or anything nearer; one strength scales the whole haze; the ground shader takes its
## numbers from the look. Seeded by design: nothing here is random.
##   godot --headless --path . --script tests/run_onelook_tests.gd

const PHASE_ONE_KEYS: Array[String] = [
	"grade_amount",
	"grade_shadow",
	"grade_warm",
	"grade_shadow_to",
	"grade_warm_from",
	"grade_guard",
	"grade_lift",
	"grade_fire_boost",
	"grade_lut_size",
	"far_blur_amount",
	"far_blur_start",
	"far_blur_ramp",
	"haze_aerial",
	"haze_sky_affect",
	"haze_sun_scatter",
	"haze_height",
	"haze_height_density",
]
const FLAME := Color(0.95, 0.45, 0.1)
const SHADOW := Color(0.12, 0.13, 0.14)
const MID_GREY := Color(0.5, 0.5, 0.5)
const HIGHLIGHT := Color(0.92, 0.92, 0.92)


func suite_name() -> String:
	return "OneLook"


func run_checks() -> void:
	await _t("_check_look_keys")
	await _t("_check_grade_colours")
	await _t("_check_grade_every_time")
	await _t("_check_grade_table")
	await _t("_check_presets")
	await _t("_check_far_depth")
	await _t("_check_haze_strength")
	await _t("_check_ground_numbers")


func _lum(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


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


func _check_grade_colours() -> void:
	Content.set_time("dusk")
	check(Look.value("grade_amount") > 0.0, "the look grades (strength above 0)")
	var shadow := LookGrade.grade(SHADOW)
	check(
		shadow.b - shadow.r > SHADOW.b - SHADOW.r,
		(
			"a shadow leans cooler: blue minus red %.3f -> %.3f"
			% [SHADOW.b - SHADOW.r, shadow.b - shadow.r]
		)
	)
	var flame := LookGrade.grade(FLAME)
	check(
		flame.r >= FLAME.r and flame.b <= FLAME.b and flame.r > flame.b * 4.0,
		"a flame stays warm and is nudged more orange: %s -> %s" % [FLAME, flame]
	)
	var mid := LookGrade.grade(MID_GREY)
	check(
		absf(_lum(mid) - _lum(MID_GREY)) < 0.04,
		"grading keeps a mid tone's brightness: %.3f -> %.3f" % [_lum(MID_GREY), _lum(mid)]
	)
	var high := LookGrade.grade(HIGHLIGHT)
	check(high.r > high.b, "a highlight leans a touch warm: %s" % [high])
	var black := LookGrade.grade(Color.BLACK)
	check(
		black.b >= black.r and black.r < 0.05 and black.b < 0.08,
		"black stays near black, a hair cool: %s" % [black]
	)
	var white := LookGrade.grade(Color.WHITE)
	check(
		white.r <= 1.0 and white.b <= 1.0 and _lum(white) > 0.93, "white stays white: %s" % [white]
	)


func _check_grade_every_time() -> void:
	var bad: Array[String] = []
	for id: String in Content.times():
		Content.set_time(id)
		var env := Environment.new()
		LookGrade.apply(env)
		if env.adjustment_color_correction == null:
			bad.append("%s has no table" % id)
		var shadow := LookGrade.grade(SHADOW)
		var flame := LookGrade.grade(FLAME)
		if shadow.b - shadow.r <= SHADOW.b - SHADOW.r or flame.r < FLAME.r:
			bad.append("%s: shadow %s flame %s" % [id, shadow, flame])
	Content.set_time("dusk")
	check(bad.is_empty(), "cool shadows and warm fire at dusk, night, morning and noon: %s" % [bad])


func _check_grade_table() -> void:
	Content.set_time("dusk")
	var env := Environment.new()
	LookGrade.apply(env)
	var table := env.adjustment_color_correction as Texture3D
	check(table != null, "the grade is a 3D lookup table on the environment")
	if table == null:
		return
	var n := table.get_width()
	check(n == int(Look.value("grade_lut_size")), "the table is the look's size: %d" % n)
	var layers := table.get_data()
	if layers.size() < n:  # the headless renderer keeps no pixels to read back
		print("SKIP: the table's texels cannot be read back without a renderer")
	else:
		# Texel (r, g, b) holds the grade of the colour at the texel's centre.
		var at := Vector3i(int(n * 0.25), int(n * 0.5), int(n * 0.75))
		var centre := Color((at.x + 0.5) / n, (at.y + 0.5) / n, (at.z + 0.5) / n)
		var want := LookGrade.grade(centre)
		var got := layers[at.z].get_pixel(at.x, at.y)
		check(
			(
				absf(got.r - want.r) < 0.01
				and absf(got.g - want.g) < 0.01
				and absf(got.b - want.b) < 0.01
			),
			"a table texel is the graded colour: %s vs %s" % [got, want]
		)
		var corner := layers[0].get_pixel(0, 0)
		check(corner.r < 0.05 and corner.g < 0.05 and corner.b < 0.08, "the black corner is black")
	Content.look()["grade_amount"] = 0.0
	var bare := Environment.new()
	LookGrade.apply(bare)
	check(bare.adjustment_color_correction == null, "strength 0 builds no table (today's picture)")
	Content.set_time("noon")
	Content.set_time("dusk")  # the look's own numbers again


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
	# A preset that drops the blur leaves the grade alone.
	var saved := PlayerSettings.graphics
	PlayerSettings.graphics = "potato"
	Content.set_time("dusk")
	var camera := Camera3D.new()
	FarDepth.new(camera)
	var env := Environment.new()
	LookGrade.apply(env)
	check(
		camera.attributes == null and env.adjustment_color_correction != null,
		"on Potato the camera has no blur and the environment still has the grade"
	)
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


func _check_haze_strength() -> void:
	Content.set_time("dusk")
	var env := Environment.new()
	CityHaze.apply(env, 1.0)
	var base := env.fog_density
	var base_height := env.fog_height_density
	check(
		env.fog_enabled and base > 0.0 and env.fog_aerial_perspective > 0.0,
		"the haze is on and has aerial depth"
	)
	CityHaze.apply(env, 1.0, 2.0)
	check(
		(
			is_equal_approx(env.fog_density, base * 2.0)
			and is_equal_approx(env.fog_height_density, base_height * 2.0)
		),
		"one strength doubles the whole haze (the escalation's hook): %.4f" % env.fog_density
	)
	CityHaze.apply(env, 1.0, 0.0)
	check(
		(
			env.fog_density == 0.0
			and env.fog_aerial_perspective == 0.0
			and env.fog_height_density == 0.0
		),
		"strength 0 clears the haze"
	)
	CityHaze.apply(env, 0.5)
	check(
		is_equal_approx(env.fog_density, base * 0.5),
		"a grown city's fog scale still thins it: %.4f" % env.fog_density
	)


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
