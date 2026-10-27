extends "res://tests/lib/runner.gd"
## Water suite (D-325 step 1, the surface; D-244, D-245: looks only). The river and the bay are
## WaterSurface sheets (scenes/water.gdshader), on by default: the river's waves ride its current
## along each channel, the bay has a swell, each takes its deep colour from the look; with tuning
## water.on false the glossy sheet it replaced is back (player-effect fixture "water.surface").
## The kaiju wades knee-deep (lead 2026-10-27: emerge.wade_depth x body scale), so the waterline
## shows on his body, and climbs out over the quay no later than from the surface (D-131's shore
## bar): player-effect fixture "water.waterline" (the same seeded start knee-deep vs at the
## surface, at every stage).
## Seeded by design: the default map_seed, Seeds "army" 0; the rise and the wade have no
## randomness, and no check reads the clock.
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
	await _t("_check_waterline")
	await _t("_check_wade_replays")


func _check_default_on() -> void:
	var raw: Variant = Content.section("water").get("on", false)
	var on: bool = raw is bool and raw == true
	check(on, "tuning water.on defaults to true (the water surface is in the game)")
	var knee := Num.f(Content.section("emerge").get("wade_depth", 0.0))
	check(knee > 0.0, "tuning emerge.wade_depth is above 0 (he wades knee-deep): %.2f" % knee)


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


## Player-effect fixture "water.waterline": the same seeded start at each stage, knee-deep
## (the shipped wade_depth) vs at the surface (0). Knee-deep his feet stand wade_depth x body
## scale under the river's surface once he has risen, so the water meets his legs; at the
## surface they stand on it. Either way he is on the bank no later than from the surface.
func _check_waterline() -> void:
	var knee := Num.f(Content.section("emerge")["wade_depth"])
	for stage: int in STAGES:
		var deep := _rise(stage, knee)
		var flat := _rise(stage, 0.0)
		var scale := Num.f(deep["scale"])
		var under := Num.f(deep["surface"]) - Num.f(deep["wading"])
		var flat_under := Num.f(flat["surface"]) - Num.f(flat["wading"])
		check(
			absf(under - knee * scale) < EPS and absf(flat_under) < EPS,
			(
				"stage %d: risen, feet %.2f m under the river (%.2f x body scale %.2f); at the surface %.2f"
				% [stage, under, knee, scale, flat_under]
			)
		)
		var deep_at := Num.f(deep["at"])
		var flat_at := Num.f(flat["at"])
		var both := Num.i(deep["emerged"]) == 1 and Num.i(flat["emerged"]) == 1
		check(
			both and deep_at <= flat_at + EPS,
			(
				"stage %d: knee-deep he is on the bank after %.2f s, from the surface %.2f s (no later)"
				% [stage, deep_at, flat_at]
			)
		)
		var landed: bool = deep["landed"]
		check(landed, "stage %d: knee-deep he ends on his feet on the street" % stage)


func _check_wade_replays() -> void:
	var knee := Num.f(Content.section("emerge")["wade_depth"])
	var a: PackedFloat32Array = _rise(2, knee)["trace"]
	var b: PackedFloat32Array = _rise(2, knee)["trace"]
	check(a == b, "the same seeded start wades the same (stand height trace)")


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


## One river start at `stage` with emerge.wade_depth `knee`: the surface and his feet once
## risen, when he emerged, whether he ended on the street, and the stand height every tick.
func _rise(stage: int, knee: float) -> Dictionary:
	var tuning := CityGrowth.tuning_for(Content.tuning(), stage)
	tuning["emerge"]["wade_depth"] = knee
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	stats["size"] = stage
	var none: Array[Dictionary] = []
	var sim := RampageSim.new(stats, tuning, none, Seeds.make("army", 0))
	sim.emerge.start(sim)
	var rise := Num.f(tuning["emerge"]["rise_seconds"])
	var limit := Num.f(tuning["emerge"]["max_seconds"]) + 1.0
	var surface := -Num.f(sim.city.get("river_depth", 0.0))
	var wading := INF
	var at := INF
	var emerged := 0
	var waited := 0.0
	var trace := PackedFloat32Array()
	while waited < limit:
		var before := sim.events.size()
		sim.emerge.step(sim, DT)
		waited += DT
		trace.append(sim.stand_y)
		if wading == INF and waited >= rise:
			wading = sim.stand_y
		for event: Dictionary in sim.events.slice(before):
			if str(event["type"]) == "kaiju_emerged":
				emerged += 1
				at = minf(at, waited)
	return {
		"surface": surface,
		"wading": wading,
		"scale": sim.body_scale(),
		"emerged": emerged,
		"at": at,
		"landed": emerged > 0 and sim.stand_y == 0.0,
		"trace": trace,
	}
