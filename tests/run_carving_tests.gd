extends "res://tests/lib/runner.gd"
## Carving suite: the rampage on the fine destruction grid (Carving, D-094 WP7; D-097, D-099).
## A building's first hit promotes it; blows carve its cells by their force at each column and
## wear adds up; VoxelSupport decides what drops and which way a tower topples (toward the cut,
## wherever the kaiju stands, then b2-5's seeded mix of cut, side or away, D-387); the chunk
## Structure is kept as a mirror that pays rubble as today. Includes the player-effect fixtures
## "carving" (the same seeded rampage with carving on and off), "fall_dirs" (b2-5 on and off),
## "landmark_carve" (tests/lib/landmark_carve_check.gd) and "bridge_carve"
## (tests/lib/bridge_carve_check.gd).
## Seeded by design: one or two hand-placed buildings, Seeds "army" 0 (fall_dirs: 0..15),
## scripted input.
##   godot --headless --path . --script tests/run_carving_tests.gd

const LandmarkCarveCheck := preload("res://tests/lib/landmark_carve_check.gd")
const BridgeCarveCheck := preload("res://tests/lib/bridge_carve_check.gd")
const DT := 1.0 / 15.0
const BANNED: Array[String] = [
	"Time.", "OS.", "randi", "randf", "randomize", "RandomNumberGenerator", "Node", "await"
]
## The tower the checks carve: 3x3 units, 14 floors, tier 1, office style.
const TOWER := {"x": 0.0, "z": 0.0, "w": 3, "d": 3, "h": 14, "tier": 1, "style": 0}


func suite_name() -> String:
	return "Carving"


func run_checks() -> void:
	await _t("_check_pure")
	await _t("_check_effect")
	await _t("_check_promote_once")
	await _t("_check_topple_toward_cut")
	await _t("_check_fall_dirs")
	await _h("LandmarkCarveCheck", func() -> void: LandmarkCarveCheck.new(check, _sim).run())
	await _h("BridgeCarveCheck", func() -> void: BridgeCarveCheck.new(check, _sim).run())
	await _t("_check_wear")
	await _t("_check_rubble_parity")
	await _t("_check_replay")
	await _t("_check_beam_parity")


## A tuning with carving switched on or off (everything else as data/tuning.json); `cut_only`
## sets b2-5's fall odds to D-099's rule (every topple to its cut side).
func _tuning(carve: bool, cut_only := false) -> Dictionary:
	var tuning := Content.tuning().duplicate(true)
	var cfg: Dictionary = tuning["destruction"]
	cfg["carve"] = carve
	if cut_only:
		cfg["fall_dirs"] = {"cut": 1.0, "side": 0.0, "away": 0.0}
	return tuning


func _sim(
	layout: Array[Dictionary], carve: bool, species := "reptilian", cut_only := false
) -> RampageSim:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), Content.species_def(species), UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(stats, _tuning(carve, cut_only), layout, Seeds.make("army", 0))
	var ability: Dictionary = Content.species_def(species)["ability"]
	sim.ability_type = str(ability["type"])
	return sim


## Steps the kaiju standing at `at` (stomping) for `steps` steps; returns every event.
func _stand(sim: RampageSim, at: Vector2, steps: int) -> Array[Dictionary]:
	sim.kaiju_pos = at
	var out: Array[Dictionary] = []
	for s: int in steps:
		out.append_array(sim.step(DT, Vector2.ZERO, false))
	return out


func _of(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		if str(e["type"]) == type:
			out.append(e)
	return out


func _banned_in(source: String) -> Array[String]:
	var out: Array[String] = []
	for line: String in source.split("\n"):
		var code := line.split("#")[0]
		for word: String in BANNED:
			if code.contains(word) and not out.has(word):
				out.append(word)
	return out


## No clock, RNG, Node or await in the module (sim rules 2 and 3); the scan catches a plant.
func _check_pure() -> void:
	var found: Array[String] = []
	for path: String in ["res://sim/carving.gd", "res://sim/party_walls.gd"]:
		var source := FileAccess.get_file_as_string(path)
		check(not source.is_empty(), "%s exists and reads" % path)
		for word: String in _banned_in(source):
			found.append("%s: %s" % [path.get_file(), word])
	check(found.is_empty(), "no clock, RNG, Node or await in the carving port: %s" % [found])
	check(
		_banned_in("var t := Time.get_ticks_usec()\nvar r := randi()") == ["Time.", "randi"],
		"the scan finds a planted Time. and randi"
	)


## Player-effect fixture "carving" (D-094 WP7): the same seeded rampage (the kaiju stomping
## beside the tower's east face for 4 s, claws off) with carving on and off. On: the tower is
## promoted, cells are carved in a crater no wider than the stomp's reach, and some chunks are
## only partly carved (finer than a chunk); off: no grid, no cell, only whole chunks.
func _check_effect() -> void:
	var layout: Array[Dictionary] = [TOWER.duplicate()]
	var runs: Array = []
	for carve: bool in [true, false]:
		var sim := _sim(layout, carve)
		sim.stats["swipe_damage"] = 0.0  # stomps only: the claw rake (D-095) reaches past them
		runs.append([sim, _stand(sim, Vector2(2.6, 0.0), 60)])
	var on: RampageSim = runs[0][0]
	var off: RampageSim = runs[1][0]
	var on_events: Array[Dictionary] = runs[0][1]
	var off_events: Array[Dictionary] = runs[1][1]
	var carved := on.carving.cells_carved
	var g: Carving.Grid = on.carving.grids.get(0, null)
	var partial := 0
	if g != null:
		for ci: int in g.live.size():
			partial += int(g.live[ci] > 0 and g.live[ci] < g.full[ci])
	print(
		(
			(
				"  carving fixture: on %d cells carved, %d fell, %d chunks partly carved, %d chunks"
				+ " down, %.1f rubble; off %d chunks down, %.1f rubble"
			)
			% [
				carved,
				on.carving.cells_fallen,
				partial,
				on.chunks_destroyed,
				on.rubble,
				off.chunks_destroyed,
				off.rubble,
			]
		)
	)
	check(
		g != null and _of(on_events, "cells_promoted").size() == 1,
		"carving on: the tower is promoted once on its first hit"
	)
	check(
		carved > 0 and not _of(on_events, "cells_carved").is_empty(),
		"carving on: stomps carve cells (%d)" % carved
	)
	check(
		partial > 0, "carving on: %d chunks are only partly carved (finer than a chunk)" % partial
	)
	check(
		off.carving.grids.is_empty() and _of(off_events, "cells_carved").is_empty(),
		"carving off: no fine grid and no carved cell"
	)
	check(off.chunks_destroyed > 0, "carving off: the same stomps break whole chunks")
	if g == null:
		return
	var reach := on.stomp_radius() * 2.0 + 0.5
	var far := 0
	var f := g.frame
	for e: Dictionary in _of(on_events, "cells_carved"):
		var index: PackedInt32Array = e["index"]
		for i: int in index:
			var local := Vector3(i % f.w + f.offset.x + 0.5, 0, (i / f.w) % f.d + f.offset.z + 0.5)
			var p := on.buildings[0].local_to_world(local / f.res)
			far += int(Vector2(p.x, p.z).distance_to(Vector2(2.6, 0.0)) > reach)
	check(far == 0, "every carved cell lies within the stomp's reach (%d beyond)" % far)


## A building is promoted on its first hit and only then; later hits reuse its grid.
func _check_promote_once() -> void:
	var layout: Array[Dictionary] = [TOWER.duplicate(), TOWER.duplicate()]
	layout[1]["x"] = 40.0
	var sim := _sim(layout, true)
	check(not sim.carving.promoted(0) and not sim.carving.promoted(1), "nothing promoted at start")
	var events := _stand(sim, Vector2(2.6, 0.0), 30)
	check(
		sim.carving.promoted(0) and not sim.carving.promoted(1),
		"only the building hit is promoted (the far one keeps its chunks)"
	)
	check(_of(events, "cells_promoted").size() == 1, "one cells_promoted event for many stomps")


## D-099: cutting the tower's base on one side topples it toward the cut, wherever the kaiju
## stands (b2-5's odds held at cut only); the fall carries its fine cells for the view.
func _check_topple_toward_cut() -> void:
	var cut := _base_cut()
	for side: float in [-12.0, 12.0]:
		var sim := _sim([TOWER.duplicate()] as Array[Dictionary], true, "reptilian", true)
		sim.kaiju_pos = Vector2(side, 0.0)
		sim.damage_chunks(0, cut, 999.0)
		var topples: Array[Dictionary] = []
		for e: Dictionary in _of(sim.events, "fall_start"):
			if str(e["kind"]) == "topple":
				topples.append(e)
		var dir: Vector2 = topples[0]["dir"] if not topples.is_empty() else Vector2.ZERO
		var index: PackedInt32Array = (
			topples[0]["index"] if not topples.is_empty() else PackedInt32Array()
		)
		var chunks: Array[Vector3i] = topples[0]["cells"] if not topples.is_empty() else []
		check(
			topples.size() == 1 and dir == Vector2(1, 0),
			(
				(
					"base cut on +x, kaiju at x %.0f: the tower topples toward the cut, +x (%d topples,"
					+ " dir %s)"
				)
				% [side, topples.size(), dir]
			)
		)
		check(
			index.size() > 1000 and chunks.size() >= 3 * 3 * 12,
			(
				"the toppling part carries its fine cells (%d) and the chunks it takes (%d)"
				% [index.size(), chunks.size()]
			)
		)


## The tower's base cells on +x (the cut the topple checks make).
func _base_cut() -> Array[Vector3i]:
	var cut: Array[Vector3i] = []
	for x: int in [1, 2]:
		for z: int in 3:
			cut.append(Vector3i(x, 0, z))
	return cut


## Player-effect fixture "fall_dirs" (b2-5, D-387: "buildings seem to ALWAYS collapse toward our
## kaiju ... make the collapse directions more varied"): the same tower cut on +x with the kaiju
## on that side, over 16 run seeds. On (data/tuning.json odds): it falls at least three ways,
## and to its cut in some runs only; off (cut only): always +x. A seed replays the same way.
func _check_fall_dirs() -> void:
	for cut_only: bool in [false, true]:
		var ways := {}
		var cut_side := 0
		var last := Vector2.ZERO
		for run_seed: int in 16:
			last = _fall_dir(cut_only, run_seed)
			ways[last] = true
			cut_side += 1 if last == Vector2(1, 0) else 0
		var again := _fall_dir(cut_only, 15)
		check(again == last, "fall_dirs: seed 15 falls the same way twice (%s, %s)" % [last, again])
		if cut_only:
			check(cut_side == 16, "fall_dirs off: every fall goes to its cut (%d of 16)" % cut_side)
		else:
			check(
				ways.size() >= 3 and cut_side > 0 and cut_side < 16,
				(
					"fall_dirs on: falls go %d ways, %d of 16 to the cut: %s"
					% [ways.size(), cut_side, ways.keys()]
				)
			)


## The direction the +x-cut tower falls in a run with this seed (ZERO if it does not topple).
func _fall_dir(cut_only: bool, run_seed: int) -> Vector2:
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var layout: Array[Dictionary] = [TOWER.duplicate()]
	var sim := RampageSim.new(stats, _tuning(true, cut_only), layout, Seeds.make("army", run_seed))
	sim.kaiju_pos = Vector2(12.0, 0.0)
	sim.damage_chunks(0, _base_cut(), 999.0)
	for e: Dictionary in _of(sim.events, "fall_start"):
		if str(e["kind"]) == "topple":
			return e["dir"]
	return Vector2.ZERO


## Wear (the WP1 review's rule): a building that dwarfs the kaiju takes dwarf_mult of each
## blow, so one blow below its strength breaks nothing, but the blows add up until cells go;
## the chunk Structure breaks on the same blow with carving off.
func _check_wear() -> void:
	var tower := TOWER.duplicate()
	tower["tier"] = 3
	var hp := Num.f(Content.section("city")["chunk_hp"]) * 3.0
	var chunk: Array[Vector3i] = [Vector3i(1, 2, 0)]
	var broke := {}
	for carve: bool in [true, false]:
		var sim := _sim([tower] as Array[Dictionary], carve)
		var blow := hp / Growth.dwarf_mult(sim.size_tier(), 3, sim.city) / 2.5  # 2.5 blows break it
		var first := -1
		for n: int in 5:
			var before := sim.carving.cells_carved if carve else sim.chunks_destroyed
			sim.damage_chunks(0, chunk, blow)
			var after := sim.carving.cells_carved if carve else sim.chunks_destroyed
			if after > before and first < 0:
				first = n + 1
		broke[carve] = first
	check(
		Num.i(broke[true]) == 3,
		"carving: a tough chunk's cells go on the 3rd blow, not before (%d)" % broke[true]
	)
	check(
		Num.i(broke[false]) == Num.i(broke[true]),
		"the chunk Structure breaks on the same blow (%d)" % broke[false]
	)


## A building brought down whole pays the same rubble and counts the same chunks either way.
func _check_rubble_parity() -> void:
	var all: Array[Vector3i] = []
	for y: int in 14:
		for x: int in 3:
			for z: int in 3:
				all.append(Vector3i(x, y, z))
	var got: Array = []
	for carve: bool in [true, false]:
		var sim := _sim([TOWER.duplicate()] as Array[Dictionary], carve)
		sim.damage_chunks(0, all, 9999.0)
		got.append([sim.rubble, sim.chunks_destroyed, sim.buildings[0].frame.alive_count])
	var same: bool = (
		is_equal_approx(Num.f(got[0][0]), Num.f(got[1][0]))
		and got[0][1] == got[1][1]
		and got[0][2] == 0
	)
	check(
		same,
		(
			"razed whole: rubble %.2f / %.2f and chunks %d / %d match, nothing left standing"
			% [got[0][0], got[1][0], got[0][1], got[1][1]]
		)
	)


## Replay: the same seeded walk past two buildings twice gives the same grids, falls and pay,
## the second time with the native cell loops off (VoxelSupport.use_native): the GDScript
## reference (CarvingCells, VoxelFrame, VoxelSupport) and KaijuSettle carve, fall and pay alike.
func _check_replay() -> void:
	var layout: Array[Dictionary] = [TOWER.duplicate(), TOWER.duplicate()]
	layout[1]["x"] = 5.0
	layout[1]["h"] = 6
	layout[1]["style"] = 1
	var traces: Array[String] = []
	for run: int in 2:
		VoxelSupport.use_native = run == 0
		var sim := _sim(layout, true)
		sim.kaiju_pos = Vector2(-6.0, 3.0)
		var trace := PackedStringArray()
		for s: int in 150:
			for e: Dictionary in sim.step(DT, Vector2(1, 0), s % 40 == 0):
				var t := str(e["type"])
				if t in ["cells_carved", "fall_start", "chunks_broken"]:
					trace.append("%d %s %d" % [s, t, hash(str(e.get("index", e.get("cells"))))])
		for n: int in sim.carving.grids:
			trace.append("grid %d %d" % [n, sim.carving.frame(n).digest()])
		trace.append("rubble %.4f falls %d" % [sim.rubble, sim.next_fall_id])
		traces.append("\n".join(trace))
	VoxelSupport.use_native = true
	check(
		traces[0] == traces[1] and traces[0].count("cells_carved") > 0,
		(
			"the same walk, native %s and reference, carves, falls and pays alike (%d lines)"
			% [VoxelSupport.native() != null, traces[0].count("\n")]
		)
	)


## Beam parity: a beam slanting across a tower carves the same cells whether its force per grid
## column comes from KaijuSettle.beam_at or Carving.hit's Callable loop (the GDScript reference).
func _check_beam_parity() -> void:
	var digests: Array[int] = []
	var cut: Array[int] = []
	for run: int in 2:
		VoxelSupport.use_native = run == 0
		var sim := _sim([TOWER.duplicate()], true)
		var beam := RampageSim.Beam.new(
			Vector2(-9.0, -1.3), Vector2(0.96, 0.28).normalized(), 12.0, 0.9
		)
		sim.hit_beam = beam
		for k: int in 6:
			sim.carving.hit(0, beam.reaches, 400.0, Vector2i(0, 8))
		sim.hit_beam = null
		digests.append(sim.carving.frame(0).digest())
		cut.append(sim.carving.frame(0).cells.count(VoxelFrame.EMPTY))
	VoxelSupport.use_native = true
	check(
		digests[0] == digests[1] and cut[0] == cut[1] and cut[0] > 0,
		(
			"a beam carves alike natively (%s) and by the reference: %d empty cells, digest %d"
			% [VoxelSupport.native() != null, cut[0], digests[0]]
		)
	)
