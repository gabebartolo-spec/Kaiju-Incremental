extends "res://tests/lib/runner.gd"
## One look, phase 1 (D-163): the far blur and the ground in the city's block grain (the grade and
## the haze stay as today, D-221), plus the flat-surface programme's ground (P0): every surface a
## texture, none a flat colour. The lowest presets drop the blur; the blur's focus follows the
## kaiju and never blurs him or anything nearer; the ground shader takes its numbers and its seed
## from the look. Seeded by design: nothing here is random.
##   godot --headless --path . --script tests/run_onelook_tests.gd

const FlatSurfaces := preload("res://tests/lib/flat_surfaces.gd")
const PHASE_ONE_KEYS: Array[String] = ["far_blur_amount", "far_blur_start", "far_blur_ramp"]


func suite_name() -> String:
	return "OneLook"


func run_checks() -> void:
	await _t("_check_look_keys")
	await _t("_check_presets")
	await _t("_check_clarity_knobs")
	await _t("_check_far_blur_off")
	await _t("_check_far_depth")
	await _t("_check_ground_numbers")
	await _t("_check_ground_seeded")
	await _t("_check_ground_kinds")
	await _t("_check_wet_is_last")
	await _t("_check_train_detail")
	await _t("_check_baked_detail")
	await _h("FlatSurfaces", func() -> void: await FlatSurfaces.run(self, check))
	await _h("NightClip", func() -> void: await NightClip.run(self, check))


func _check_look_keys() -> void:
	Content.set_time("dusk")
	var missing: Array[String] = []
	for key: String in PHASE_ONE_KEYS:
		if not Content.look().has(key):
			missing.append(key)
	for key: String in GroundKit.BLOCK_KEYS:
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


## 4K clarity (render plan item 3): a viewport takes its FSR sharpness from the preset row and its
## debanding from the look (looks.json deband). A sub-viewport stands in for the root.
func _check_clarity_knobs() -> void:
	Content.set_time("dusk")
	var table: Dictionary = Content.section("display")["graphics"]
	var look := Content.look()
	var saved: Variant = look.get("deband")
	var view := SubViewport.new()
	root.add_child(view)
	var bad: Array[String] = []
	for name: String in table:
		var row: Dictionary = table[name]
		for deband: bool in [false, true]:
			look["deband"] = deband
			GraphicsPresets.apply(row, view)
			if not is_equal_approx(view.fsr_sharpness, Num.f(row["fsr_sharpness"])):
				bad.append("%s sharpness %.2f" % [name, view.fsr_sharpness])
			if view.use_debanding != deband:
				bad.append("%s deband %s" % [name, view.use_debanding])
	check(
		bad.is_empty(), "a viewport takes the preset's sharpness and the look's deband: %s" % [bad]
	)
	var medium: Dictionary = table["medium"]
	var soft := medium.duplicate()
	soft["fsr_sharpness"] = 0.35
	GraphicsPresets.apply(soft, view)
	check(is_equal_approx(view.fsr_sharpness, 0.35), "a row's sharpness reaches the viewport")
	look["deband"] = saved
	# D-285 (director picked "Both" from the 20 stills): debanding on, Medium and Low sharpen to 0.1.
	var on: bool = look.get("deband", false)
	check(on, "the look ships with debanding on")
	var low: Dictionary = table["low"]
	var shipped: Array[float] = [Num.f(medium["fsr_sharpness"]), Num.f(low["fsr_sharpness"])]
	check(shipped == [0.1, 0.1], "Medium and Low ship FSR sharpness 0.1: %s" % [shipped])
	view.queue_free()


## D-360 (director picked "no far blur", 2026-10-28; replaces D-163's depth-blur clause): the game
## ships with the far blur off in every time of day and every preset, so no camera carries a
## depth of field pass at all (nothing to render, and FarDepth.follow returns at once).
func _check_far_blur_off() -> void:
	var saved := PlayerSettings.graphics
	var on: Array[String] = []
	var table: Dictionary = Content.section("display")["graphics"]
	for time: String in Content.times():
		Content.set_time(time)
		check(
			Num.f(Content.look().get("far_blur_amount", -1.0)) == 0.0,
			"%s ships far_blur_amount 0" % time
		)
		for name: String in table:
			PlayerSettings.graphics = name
			var camera := Camera3D.new()
			FarDepth.new(camera)
			if camera.attributes != null:
				on.append("%s/%s" % [time, name])
			camera.free()
	check(on.is_empty(), "no time of day or preset puts a far blur on the camera: %s" % [on])
	PlayerSettings.graphics = saved


func _check_far_depth() -> void:
	var saved := PlayerSettings.graphics
	PlayerSettings.graphics = "medium"
	Content.set_time("dusk")
	var look := Content.look()
	var saved_amount: Variant = look.get("far_blur_amount")
	look["far_blur_amount"] = 0.06  # the option stays; the shipped look has it at 0 (D-360)
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
	look["far_blur_amount"] = saved_amount
	PlayerSettings.graphics = saved


func _check_ground_numbers() -> void:
	Content.set_time("dusk")
	var uniforms: Array[String] = []
	for u: Dictionary in GroundKit.SLAB_SHADER.get_shader_uniform_list():
		uniforms.append(str(u["name"]))
	var bad: Array[String] = []
	for key: String in GroundKit.BLOCK_KEYS:
		if not key in uniforms:
			bad.append(key)
	check(bad.is_empty(), "every ground number is a uniform of the block shader: %s" % [bad])
	check(
		is_equal_approx(Look.value("ground_block"), 0.125),
		"the ground's block is the city's voxel grain, 0.125 m"
	)
	var mat := GroundKit.material(7301)
	check(
		is_equal_approx(
			Num.f(mat.get_shader_parameter("block_noise")), Look.value("ground_block_noise")
		),
		"the material carries the look's numbers"
	)


## Same seed, same ground: the material carries the map seed and the same seed gives the same
## numbers.
func _check_ground_seeded() -> void:
	Content.set_time("dusk")
	var a := GroundKit.material(7301)
	var b := GroundKit.material(7301)
	var c := GroundKit.material(7302)
	var same := true
	for key: String in GroundKit.BLOCK_KEYS + ["seed"]:
		if a.get_shader_parameter(key) != b.get_shader_parameter(key):
			same = false
	check(same, "the same map seed gives the same ground numbers")
	check(
		not is_equal_approx(
			Num.f(a.get_shader_parameter("seed")), Num.f(c.get_shader_parameter("seed"))
		),
		"another map seed shifts every hash of the ground (a different ground)"
	)


## The slabs the street plan lays: every surface kind is there with a measurable share of the
## ground, each street slab knows its centre line to a few millimetres through the half-float
## instance buffer, and a river wall knows the water line the damp band follows.
func _check_ground_kinds() -> void:
	Content.set_time("dusk")
	var base: Dictionary = Content.tuning().duplicate(true)
	var cfg: Dictionary = CityGrowth.tuning_for(base, 2)["city"]
	var ground := CityGround.new(cfg)
	root.add_child(ground)
	var area := {}
	var total := 0.0
	var bad_centre := 0
	var roads := 0
	var walls_wet := 0
	var walls := 0
	for slab: Dictionary in ground.get("_slabs"):
		var t: Transform3D = slab["t"]
		var d: Color = slab["d"]
		var kind := int(floorf(d.r))
		var size := Vector2(t.basis.x.length(), t.basis.z.length())
		var a := size.x * size.y
		if t.origin.y > -0.5 and size.x < 1000.0:  # not the land under everything
			area[kind] = Num.f(area.get(kind, 0.0)) + a
			total += a
		if kind == GroundKit.K_ROAD or kind == GroundKit.K_DECK:
			var axis := roundi(fposmod(d.r, 1.0) * 8.0)
			if axis != GroundKit.TURNED:
				roads += 1
				var across := t.origin.z if axis == GroundKit.ALONG_X else t.origin.x
				var half := (size.y if axis == GroundKit.ALONG_X else size.x) * 0.5
				var centre := d.g + d.b
				# A street or deck piece lies inside its street, in its width of the centre line.
				if absf(across - centre) > d.a + 0.01 or absf(d.b) > 8.0 or half > d.a + 0.01:
					bad_centre += 1
		if kind == GroundKit.K_CONCRETE:
			walls += 1
			if d.g < -0.5:
				walls_wet += 1
	for kind: int in [GroundKit.K_ROAD, GroundKit.K_PAVEMENT, GroundKit.K_CONCRETE]:
		var share := Num.f(area.get(kind, 0.0)) / maxf(total, 1.0)
		check(
			share > (0.0001 if kind == GroundKit.K_CONCRETE else 0.01),
			"kind %d covers a measurable share of the ground (%.1f%%)" % [kind, 100.0 * share]
		)
	check(roads > 20, "the street plan lays its streets as slabs of their own (%d)" % roads)
	check(
		bad_centre == 0, "every street slab keeps its centre line and width (%d off)" % bad_centre
	)
	check(
		walls > 0 and walls_wet > 0,
		"river walls carry their water line (%d of %d)" % [walls_wet, walls]
	)
	ground.queue_free()


## Wet applies last: the rain darkens and glosses whatever the surface looks like, with the numbers
## atm-rain-2 set (identity of `wet`).
func _check_wet_is_last() -> void:
	var code := GroundKit.SLAB_SHADER.code
	var wet_at := code.rfind("wet * WET_DARKEN")
	var grain_at := code.rfind("sd_grain(")
	check(
		wet_at > 0 and grain_at > 0 and wet_at > grain_at,
		"wet darkens after every surface look has run"
	)
	check(
		(
			code.contains("const float WET_DARKEN = 0.62;")
			and code.contains("const float WET_ROUGHNESS = 0.18;")
			and code.contains("const float WET_SPECULAR = 0.9;")
			and code.contains("render_mode diffuse_burley;")
		),
		"wet keeps its darken, roughness and specular, and the burley diffuse"
	)


## A train car draws in the city's surface family with the detail fixed to the car (debt row 25):
## the detail shader, reading each cube's cell from its custom data, which the car's MultiMesh
## carries (without it every cube reads the same block and the car is one flat colour again,
## though the material scan passes). The per-cube values are not read back here: the headless
## renderer keeps no MultiMesh instance data (every get_instance_* returns the default).
func _check_train_detail() -> void:
	var car := TrainModel.car(true, Num.f(Content.section("rail")["car_length"]))
	var mm := car.multimesh
	var mat := mm.mesh.surface_get_material(0) as ShaderMaterial
	check(
		mat != null and mat.shader == Look.VOXEL_DETAIL_SHADER,
		"a train car draws on voxel_detail.gdshader"
	)
	check(
		Look.VOXEL_DETAIL_SHADER.code.contains("INSTANCE_CUSTOM.xyz"),
		"the detail shader places its grain from each cube's cell (INSTANCE_CUSTOM)"
	)
	check(
		mm.use_custom_data and mm.instance_count > 100,
		"a train car's %d cubes carry custom data" % mm.instance_count
	)
	car.free()


## People and cars are baked meshes (no instances): they draw in the city's surface family with
## the detail read from their own model-space vertices (flat surfaces P3). Off, they are the plain
## voxel material: one flat colour per cube.
func _check_baked_detail() -> void:
	var voxel := Num.f(Content.section("street")["person_voxel"])
	var meshes: Dictionary = {
		"a person": VoxelPerson.mesh(0, 0, voxel),
		"a car": TrafficMeshes.cars(TrafficMeshes.palette())[0],
	}
	for what: String in meshes:
		var mat := (meshes[what] as ArrayMesh).surface_get_material(0) as ShaderMaterial
		check(
			(
				mat != null
				and mat.shader == Look.VOXEL_DETAIL_SHADER
				and mat.get_shader_parameter("baked") == true
			),
			"%s draws on voxel_detail.gdshader, baked" % what
		)
	var off := VoxelBuilder.new()
	off.put(Vector3i.ZERO, "x")
	var plain_mesh := off.bake({"x": Color.WHITE}, voxel, Vector3.ZERO, 0.0)
	var plain := plain_mesh.surface_get_material(0) as ShaderMaterial
	check(plain.shader == Look.VOXEL_SHADER, "a bake without detail keeps the plain voxel material")
