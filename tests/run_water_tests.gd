extends "res://tests/lib/runner.gd"
## Water suite (D-325 step 1, the surface; D-244, D-245: looks only). The river and the bay are
## WaterSurface sheets (scenes/water.gdshader), on by default: the river's waves ride its current
## along each channel, the bay has a swell, each takes its deep colour from the look; with tuning
## water.on false the glossy sheet it replaced is back (player-effect fixture "water.surface").
## The knee-deep river wade it shipped with left when the run start moved to the sea bay (D-377).
## Seeded by design: the default map_seed; no check reads the clock.
##   godot --headless --path . --script tests/run_water_tests.gd

const DT := 1.0 / 30.0
const STAGES := [1, 2, 3]
const EPS := 1e-4


func suite_name() -> String:
	return "Water"


func run_checks() -> void:
	await _t("_check_default_on")
	await _t("_check_surface_on")
	await _t("_check_surface_off")


func _check_default_on() -> void:
	var raw: Variant = Content.section("water").get("on", false)
	var on: bool = raw is bool and raw == true
	check(on, "tuning water.on defaults to true (the water surface is in the game)")


func _check_surface_on() -> void:
	var sheets := await _sheets(true)
	var cfg := Content.section("city")
	var channels := CityRiver.channels(CityGen.map(cfg), cfg)
	check(
		sheets.size() == channels.size() + 1,
		(
			"one water sheet per river channel and one bay (%d sheets, %d channels)"
			% [sheets.size(), channels.size()]
		)
	)
	var shaded := 0
	var rivers := 0
	var bays := 0
	for mi: MeshInstance3D in sheets:
		var mat := (mi.mesh as PlaneMesh).material as ShaderMaterial
		if mat == null or mat.shader != WaterSurface.SHADER:
			continue
		shaded += 1
		var deep: Color = mat.get_shader_parameter("deep_color")
		var flow: Vector2 = mat.get_shader_parameter("flow")
		var swell := Num.f(mat.get_shader_parameter("swell_length"))
		var size: Vector2 = (mi.mesh as PlaneMesh).size
		var long := Vector2.RIGHT if size.x >= size.y else Vector2.DOWN
		if swell > 0.0:
			bays += int(flow == Vector2.ZERO and deep.is_equal_approx(Look.color("water")))
		else:
			var along := flow.length() > 0.0 and absf(flow.normalized().dot(long)) > 0.999
			rivers += int(along and deep.is_equal_approx(Look.color("river")))
		shaded -= int(mat.render_priority != WaterSurface.PRIORITY)
		var foam: Color = mat.get_shader_parameter("foam_color")
		shaded -= int(not foam.is_equal_approx(Look.color("water_foam")))
	check(
		shaded == sheets.size(),
		(
			"every sheet draws the water shader, first of the transparents (%d of %d)"
			% [shaded, sheets.size()]
		)
	)
	check(bays == 1, "the bay has the swell, no current and the look's bay colour (%d)" % bays)
	check(
		rivers == channels.size(),
		(
			"each river channel flows along its length in the look's river colour (%d of %d)"
			% [rivers, channels.size()]
		)
	)
	_free_sheets(sheets)


func _check_surface_off() -> void:
	var sheets := await _sheets(false)
	var gloss := 0
	for mi: MeshInstance3D in sheets:
		var mat := (mi.mesh as PlaneMesh).material as StandardMaterial3D
		gloss += int(mat != null and is_equal_approx(mat.roughness, WaterSurface.GLOSS_ROUGHNESS))
	check(
		not sheets.is_empty() and gloss == sheets.size(),
		(
			"with water.on false every sheet is the old glossy colour (%d of %d)"
			% [gloss, sheets.size()]
		)
	)
	_free_sheets(sheets)


## The city's water sheets with the surface on or off (a stage-1 CityGround), in the tree.
func _sheets(on: bool) -> Array[MeshInstance3D]:
	Content.section("water")["on"] = on
	var ground := CityGround.new(Content.section("city"))
	root.add_child(ground)
	await process_frame
	Content.section("water")["on"] = true
	var out: Array[MeshInstance3D] = []
	for node: Node in get_nodes_in_group(WaterSurface.GROUP):
		if ground.is_ancestor_of(node):
			out.append(node as MeshInstance3D)
	return out


func _free_sheets(sheets: Array[MeshInstance3D]) -> void:
	if not sheets.is_empty():
		sheets[0].get_parent().free()
