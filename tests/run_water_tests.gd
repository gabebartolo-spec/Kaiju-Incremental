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
	await _t("_check_liquid_wave")
	await _t("_check_liquid_settles")
	await _t("_check_liquid_whole_bay")
	await _t("_check_liquid_open_sea")
	await _t("_check_liquid_native")


func _check_default_on() -> void:
	var raw: Variant = Content.section("water").get("on", false)
	var on: bool = raw is bool and raw == true
	check(on, "tuning water.on defaults to true (the water surface is in the game)")


func _check_surface_on() -> void:
	var sheets := await _sheets(true)
	var cfg := Content.section("city")
	var channels := CityRiver.channels(CityGen.map(cfg), cfg)
	check(
		sheets.size() == channels.size() + 2,
		(
			"one water sheet per river channel, the open sea and the sea bay (%d sheets, %d channels)"
			% [sheets.size(), channels.size()]
		)
	)
	var shaded := 0
	var rivers := 0
	var bays := 0
	for mi: MeshInstance3D in sheets:
		var mat := _material(mi) as ShaderMaterial
		if mat == null or mat.shader != WaterSurface.SHADER:
			continue
		shaded += 1
		var deep: Color = mat.get_shader_parameter("deep_color")
		var flow: Vector2 = mat.get_shader_parameter("flow")
		var swell := Num.f(mat.get_shader_parameter("swell_length"))
		if swell > 0.0:
			bays += int(flow == Vector2.ZERO and deep.is_equal_approx(Look.color("water")))
		else:
			var size: Vector2 = (mi.mesh as PlaneMesh).size
			var long := Vector2.RIGHT if size.x >= size.y else Vector2.DOWN
			var along := flow.length() > 0.0 and absf(flow.normalized().dot(long)) > 0.999
			rivers += int(along and deep.is_equal_approx(Look.color("water")))
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
	check(
		bays == 2,
		"the open sea and the bay have the swell, no current and the look's sea colour (%d)" % bays
	)
	check(
		rivers == channels.size(),
		(
			"each river channel flows along its length in the look's one water colour (%d of %d)"
			% [rivers, channels.size()]
		)
	)
	_free_sheets(sheets)


func _check_surface_off() -> void:
	var sheets := await _sheets(false)
	var gloss := 0
	for mi: MeshInstance3D in sheets:
		var mat := _material(mi) as StandardMaterial3D
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


## A sheet's material: the sea bay's (HarbourView) is an override on its polygon mesh.
func _material(mi: MeshInstance3D) -> Material:
	if mi.material_override != null:
		return mi.material_override
	return (mi.mesh as PlaneMesh).material


func _free_sheets(sheets: Array[MeshInstance3D]) -> void:
	if not sheets.is_empty():
		sheets[0].get_parent().free()


## The liquid (WaterSim, director 2026-10-31 "make the water a real physical thing"): a stomp's
## worth thrown out of the bay's shelf makes a crater and a ring wave that reaches water 9 m off,
## and the water it moves is all still there.
func _check_liquid_wave() -> void:
	var w := _liquid()
	var bay: WaterSim.Basin = w.basins[0]
	var p := _shelf_point(w)
	var before := _volume(bay)
	var off := p + Vector2(9.0, 0.0)
	check(w.disturb(p, 40.0, 1.5), "a push into the bay's shelf water is taken")
	var dip := bay.rest - w.surface_at(p)
	check(dip > 0.1, "it leaves a crater (%.2f under the still water)" % dip)
	var peak := 0.0
	for n: int in 90:
		w._flow(bay, DT)
		peak = maxf(peak, w.surface_at(off) - bay.rest)
	check(peak > 0.02, "a wave reaches water 9 m off within 3 s (it rose %.3f m)" % peak)
	var lost := _volume(bay) - before
	check(absf(lost) < 0.5, "no water made or lost (%.3f m3 out of %.0f)" % [lost, before])


## Friction takes the waves down and the window sleeps: still water costs nothing.
func _check_liquid_settles() -> void:
	var w := _liquid()
	var bay: WaterSim.Basin = w.basins[0]
	w.disturb(_shelf_point(w), 40.0, 1.5)
	var n := 0
	while bay.active.has_area() and n < 1800:
		w._flow(bay, DT)
		n += 1
	var still := "the bay is still again within 60 s of a stomp (%.1f s)" % (n * DT)
	check(not bay.active.has_area(), still)


## The whole bay moves (director 2026-10-31: the 80 m window left one rectangle of waves, its
## edge a wall): the rise's wave runs on past where that wall stood.
func _check_liquid_whole_bay() -> void:
	var w := _liquid()
	var bay: WaterSim.Basin = w.basins[0]
	var p := _shelf_point(w)
	var far := p + Vector2(60.0, 0.0)
	check(not is_nan(w.surface_at(far)) and _wet(bay, far), "water 60 m off the push (past the old wall)")
	w.disturb(p, _rise_volume(), _rise_radius())
	var peak := 0.0
	for n: int in 600:
		w._flow(bay, DT)
		peak = maxf(peak, w.surface_at(far) - bay.rest)
	check(peak > 0.02, "the rise's wave reaches water 60 m off within 20 s (it rose %.3f m)" % peak)
	var whole := bay.active.size.x == bay.nx
	check(whole, "the stepped window grows to the bay's width (%d of %d)" % [bay.active.size.x, bay.nx])


## The bay's mouth is open sea: a wave runs out there instead of bouncing back off a wall. A wall
## doubles a wave as it turns it back, so the mouth's highest lift shows which it met.
func _check_liquid_open_sea() -> void:
	var top: Array[float] = []
	for open: bool in [false, true]:
		var w := _liquid()
		var bay: WaterSim.Basin = w.basins[0]
		bay.open = open
		var c := Vector2i(bay.nx / 2, 16)
		w.disturb(bay.centre(c), _rise_volume(), _rise_radius())
		var most := 0.0
		for n: int in 360:
			w._flow(bay, DT)
			most = maxf(most, bay.lift(c.x))
		top.append(most)
	var through := top[1] < top[0] * 0.75
	check(
		through,
		"the wave runs out of the mouth, not back (the mouth rose %.3f m walled, %.3f m open)" % top
	)


## KaijuWater steps the pipes with the GDScript's own floats: the same water either way.
func _check_liquid_native() -> void:
	if not ClassDB.class_exists("KaijuWater"):
		check(true, "no native library loaded: the GDScript pipes alone")
		return
	var runs := []
	for native: bool in [false, true]:
		var w := _liquid()
		w.use_native = native
		var bay: WaterSim.Basin = w.basins[0]
		var p := _shelf_point(w)
		w.disturb(p, 40.0, 1.5)
		w.disturb(bay.centre(Vector2i(bay.nx / 2, 3)), 40.0, 1.5)
		for n: int in 45:
			w._flow(bay, DT)
		runs.append([bay.depth, bay.flow, bay.active])
	var same_window: bool = runs[0][2] == runs[1][2]
	var same_depth: bool = runs[0][0] == runs[1][0]
	var same_flow: bool = runs[0][1] == runs[1][1]
	check(same_window, "the same window stepped (%s, %s)" % [runs[0][2], runs[1][2]])
	check(same_depth, "native and GDScript depths match bit for bit after 1.5 s")
	check(same_flow, "native and GDScript flows match bit for bit after 1.5 s")


func _rise_volume() -> float:
	return Num.f(Content.section("water_sim")["rise_volume"])


func _rise_radius() -> float:
	return Num.f(Content.section("water_sim")["rise_radius"])


func _wet(b: WaterSim.Basin, p: Vector2) -> bool:
	var c := b.at(p)
	return b.floor_y[c.y * b.nx + c.x] < b.rest - 0.5


func _liquid() -> WaterSim:
	return WaterSim.new(Content.section("city"), {"water_sim": Content.section("water_sim")})


## A point on the bay's flat shelf, clear of the rise's hollow and of the open sea at the mouth.
func _shelf_point(w: WaterSim) -> Vector2:
	var cfg := Content.section("city")
	var bay: WaterSim.Basin = w.basins[0]
	for k: int in bay.nx * bay.nz:
		var c := Vector2i(k % bay.nx, k / bay.nx)
		var p := bay.centre(c)
		if c.x > bay.nx / 4 and c.y >= 8 and absf(bay.floor_y[k] - CityHarbour.shelf_floor(cfg)) < 0.01:
			return p
	return bay.centre(Vector2i(bay.nx / 4, 8))


func _volume(b: WaterSim.Basin) -> float:
	var out := 0.0
	for k: int in b.nx * b.nz:
		out += b.depth[k]
	return out * b.cell * b.cell
