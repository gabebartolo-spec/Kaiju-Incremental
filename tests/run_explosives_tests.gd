extends "res://tests/lib/runner.gd"
## Explosives suite (director comments #19): the city's red barrels. CityHazards places a few
## fuel silos, fireworks factories and chem labs per stage (spaced, clear of the kaiju's rise,
## the same every time); any blow to one lights its fuse; the blast breaks what is in its radius
## and nothing past it, sets off the sites it reaches (a chain), and each kind has its flavour.
## Seeded by design: hand-placed buildings, Seeds "army" 0, the kaiju parked out of reach.
##   godot --headless --path . --script tests/run_explosives_tests.gd

const DT := 1.0 / 15.0
const BANNED: Array[String] = ["Time.", "OS.", "randomize", "Node", "await"]
const FAR := Vector2(-40.0, 40.0)  # where the kaiju stands: out of reach of every site
const TALL := {"x": -30.0, "z": -30.0, "w": 4, "d": 4, "h": 20, "tier": 1, "style": 0}


func suite_name() -> String:
	return "Explosives"


func run_checks() -> void:
	await _t("_check_pure")
	await _t("_check_hit_lights_fuse")
	await _t("_check_blast_radius")
	await _t("_check_chain")
	await _t("_check_toxic_cloud")
	await _t("_check_fireworks")
	await _t("_check_city_places")
	await _t("_check_replay")
	await _t("_check_models")


func _site(kind: String, x: float, z: float) -> Dictionary:
	return {"x": x, "z": z, "w": 2, "d": 2, "h": 4, "tier": 1, "style": 0, "hazard": kind}


func _block(x: float, z: float) -> Dictionary:
	return {"x": x, "z": z, "w": 2, "d": 2, "h": 4, "tier": 1, "style": 0}


func _sim(layout: Array[Dictionary]) -> RampageSim:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var city := layout.duplicate()
	city.append(TALL)  # keeps the city standing (no "city_fallen" end) while a chain plays out
	var sim := RampageSim.new(stats, Content.tuning(), city, Seeds.make("army", 0))
	sim.kaiju_pos = FAR
	return sim


## Steps `seconds` with the kaiju parked at FAR; `pin` (a tank) is held where it was put.
func _run(sim: RampageSim, seconds: float, pin: RampageSim.Tank = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var held := pin.pos if pin != null else Vector2.ZERO
	for s: int in int(seconds / DT):
		sim.kaiju_pos = FAR
		if pin != null:
			pin.pos = held
		out.append_array(sim.step(DT, Vector2.ZERO, false))
	return out


func _of(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return str(e["type"]) == type)


func _check_pure() -> void:
	for path: String in [
		"res://sim/explosives.gd",
		"res://sim/city_hazards.gd",
		"res://sim/hazard_shape.gd",
		"res://sim/hazard_cells.gd",
	]:
		var src := FileAccess.get_file_as_string(path)
		for word: String in BANNED:
			check(not src.contains(word), "%s has no %s" % [path.get_file(), word])


## One small blow to a silo lights its fuse; it goes off after fuse_s, not before.
func _check_hit_lights_fuse() -> void:
	var sim := _sim([_site("fuel_silo", 0.0, 0.0)])
	var fuse := Num.f(Content.tuning()["explosives"]["fuse_s"])
	var site: Explosives.Site = sim.explosives.sites[0]
	check(site.state == Explosives.IDLE, "an untouched silo waits")
	sim.damage_chunks(0, [Vector3i(0, 0, 0)] as Array[Vector3i], 1.0)
	check(site.state == Explosives.ARMED, "a 1-point blow lights the fuse")
	var early := _run(sim, fuse * 0.5)
	check(_of(early, "explosion").is_empty(), "no blast before the fuse burns down")
	var late := _run(sim, fuse)
	check(_of(late, "explosion").size() == 1, "one blast once the fuse is out")
	check(sim.buildings[0].frame.alive_count == 0, "the silo itself is gone")


## The blast breaks the building beside it and pays rubble; one past twice the radius is untouched.
func _check_blast_radius() -> void:
	var sim := _sim([_site("fuel_silo", 0.0, 0.0), _block(3.0, 0.0), _block(25.0, 0.0)])
	var near_before := sim.buildings[1].frame.alive_count
	var far_before := sim.buildings[2].frame.alive_count
	var rubble := sim.rubble
	sim.explosives.damaged(0)
	_run(sim, 2.0)
	check(sim.buildings[1].frame.alive_count < near_before, "the next-door building is broken")
	check(sim.buildings[2].frame.alive_count == far_before, "a building 25 away is untouched")
	check(sim.rubble > rubble, "what the blast breaks pays biomass")


## A silo's blast sets off the chem lab beside it; a fireworks factory far off stays quiet.
func _check_chain() -> void:
	var sim := _sim(
		[
			_site("fuel_silo", 0.0, 0.0),
			_site("chem_lab", 7.0, 0.0),
			_site("fireworks_factory", 30.0, 0.0),
		]
	)
	sim.explosives.damaged(0)
	var events := _run(sim, 3.0)
	var kinds := _of(events, "explosion").map(func(e: Dictionary) -> String: return str(e["kind"]))
	check(
		kinds == ["fuel_silo", "chem_lab"], "silo then the chem lab it reached (got %s)" % [kinds]
	)
	check(sim.explosives.sites[2].state == Explosives.IDLE, "the far factory never went off")


## A chem lab's cloud wears down a tank parked inside it, past the blast's own reach.
func _check_toxic_cloud() -> void:
	var sim := _sim([_site("chem_lab", 0.0, 0.0)])
	var tank := RampageSim.Tank.new()
	tank.pos = Vector2(6.5, 0.0)  # past 2 x blast radius (6), inside the cloud (7)
	tank.hp = 1000.0
	tank.cooldown = 1000.0
	sim.tanks.append(tank)
	sim.explosives.damaged(0)
	var events := _run(sim, 1.5, tank)
	check(_of(events, "toxic_cloud").size() == 1, "the lab leaves a toxic cloud")
	var after_blast := tank.hp
	_run(sim, 3.0, tank)
	check(
		tank.hp < after_blast,
		"the cloud keeps hurting the tank (%.1f -> %.1f)" % [after_blast, tank.hp]
	)


## A fireworks factory throws its bursts around it, each setting what it hits burning.
func _check_fireworks() -> void:
	var sim := _sim([_site("fireworks_factory", 0.0, 0.0)])
	var k: Dictionary = Content.tuning()["explosives"]["fireworks_factory"]
	sim.explosives.damaged(0)
	var events := _run(sim, 5.0)
	check(_of(events, "firework_burst").size() == Num.i(k["bursts"]), "every burst goes off")
	check(sim.hit_coat.is_empty(), "the burning coat is only on during a burst")


## Every stage's city has its hazards, spaced, clear of the rise, in play, the same each time.
func _check_city_places() -> void:
	var tuning := Content.tuning()
	var h: Dictionary = tuning["city"]["hazards"]
	for stage: int in CityGrowth.stage_count(tuning):
		var cfg: Dictionary = CityGrowth.tuning_for(tuning, stage)["city"]
		var layout := CityGen.generate(Seeds.make("city", 0), cfg)
		var again := CityGen.generate(Seeds.make("city", 0), cfg)
		var spots: Array[Vector2] = []
		for n: int in layout.size():
			if layout[n].has("hazard"):
				spots.append(Vector2(Num.f(layout[n]["x"]), Num.f(layout[n]["z"])))
				check(
					str(again[n].get("hazard", "")) == str(layout[n]["hazard"]),
					"same site every time"
				)
		var counts: Array = h["count"]
		var ring := CityGen.districts(cfg).find(Num.f(cfg["half"]))
		var want := Num.i(counts[mini(ring, counts.size() - 1)])
		check(
			spots.size() >= want,
			"stage %d has at least %d sites (%d)" % [stage, want, spots.size()]
		)
		var spawn: Vector2 = CityGen.map(cfg).get("river_spawn", Vector2(INF, INF))
		for a: int in spots.size():
			check(spots[a].distance_to(spawn) >= Num.f(h["spawn_clear"]), "clear of the rise")
			for b: int in range(a + 1, spots.size()):
				check(spots[a].distance_to(spots[b]) >= Num.f(h["min_spacing"]), "sites spaced")


## The same chain twice gives the same events, step for step.
func _check_replay() -> void:
	var digests: Array[String] = []
	for run: int in 2:
		var sim := _sim([_site("fireworks_factory", 0.0, 0.0), _site("fuel_silo", 6.0, 0.0)])
		sim.explosives.damaged(0)
		digests.append(str(_run(sim, 4.0)).sha256_text())
	check(digests[0] == digests[1], "replay is identical")


## Each kind's model (HazardShape) at sizes the city gives them: every cell a known material, the
## sim's carving grid (HazardCells) the same cells as the drawn voxels (HazardVoxels), every floor
## of the footprint holding part of it (no structural chunk layer left as air), only the outside
## skin drawn (never the inside of a tank or shed), and each kind in its own colour.
func _check_models() -> void:
	var ids := CellGrid.material_ids()
	var res := CellGrid.cell_res()
	check(res == BuildingVoxels.RES, "the sim grid and the view share one cell size")
	var marks := {"fuel_silo": "hz_steel", "fireworks_factory": "hz_brick", "chem_lab": "hz_glow"}
	var sizes: Array[Vector3i] = [
		Vector3i(2, 2, 3), Vector3i(3, 3, 2), Vector3i(5, 2, 4), Vector3i(3, 10, 4)
	]
	for kind: String in marks:
		for size: Vector3i in sizes:
			var entry := {"x": 0.0, "z": 0.0, "w": size.x, "h": size.y, "d": size.z, "tier": 1}
			entry.merge({"style": 0, "hazard": kind})
			var b := Landmarks.building(entry, 10.0)
			var shape := HazardShape.cells(b, res)
			var label := "%s %s" % [kind, size]
			var keys := {}
			for cell: Vector3i in shape:
				keys[shape[cell]] = true
			check(
				keys.keys().all(func(k: String) -> bool: return ids.has(k)), label + ": materials"
			)
			check(keys.has(marks[kind]), label + ": drawn in its own colour")
			var grid := HazardCells.new(b)
			check(grid.count() == shape.size(), label + ": the carving grid is the model")
			var floors := {}
			for cell: Vector3i in shape:
				floors[floori(float(cell.y) / res)] = true
			var every := range(size.y).all(func(f: int) -> bool: return floors.has(f))
			check(every, label + ": every floor holds part of it")
			var voxels := HazardVoxels.new(b, Color.GRAY)
			check(
				voxels.vox.cells.size() == shape.size(), label + ": the view draws the same cells"
			)
			check(_drawn(voxels) < _open(shape), label + ": only the outside skin is drawn")


## Faces HazardVoxels draws (its face masks' bits).
func _drawn(voxels: HazardVoxels) -> int:
	var n := 0
	for cell: Vector3i in voxels.vox.cells:
		var mask := voxels.face_mask(cell)
		for k: int in 6:
			n += (mask >> k) & 1
	return n


## Faces that meet any empty cell (inside or out, never the ground).
func _open(shape: Dictionary) -> int:
	var n := 0
	for cell: Vector3i in shape:
		for d: Vector3i in BuildingMesher.NEIGHBOURS:
			var m := cell + d
			n += 1 if m.y >= 0 and not shape.has(m) else 0
	return n
