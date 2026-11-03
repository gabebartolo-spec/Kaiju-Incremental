extends "res://tests/lib/powers_base.gd"
## Fall contact suite (FallContact, KaijuHide; director 2026-11-03): a falling building never
## passes through a standing neighbour or the kaiju. After every sim step the falling part, posed
## the way the view draws it (FallMotion's turn, ToppleFx's tilt), may not reach into a standing
## neighbour's live chunks (what it carved is gone, so excepted) or into the kaiju's hide beyond
## TOLERANCE; a part dropped onto the kaiju breaks up against him and its fragments (DebrisField,
## real rigid bodies) end up outside his hide. The same falls with fall_contact.on false are the
## before numbers (NOTICE lines). Headless.
##   godot --headless --path . --script tests/run_fall_contact_tests.gd

## How deep (sim units) a part may reach into what it hits: one tick's sweep at most.
const TOLERANCE := 0.35
## How deep a fragment's centre may sit inside the hide once settled (half a small fragment).
const FRAGMENT_TOLERANCE := 0.1
const TOWER := Vector3i(2, 2, 14)
const SAMPLES := 3  # per axis per chunk, measuring (finer than FallContact's own)


func suite_name() -> String:
	return "FallContact"


func run_checks() -> void:
	await _t("_check_neighbour")
	await _t("_check_kaiju_topple")
	await _t("_check_kaiju_drop")
	await _t("_check_fragments_outside")


## A tower toppling east into a lower neighbour 2 m away: never inside its standing chunks.
func _check_neighbour() -> void:
	var off := _topple_run(false, false)
	var on := _topple_run(true, false)
	print(
		"NOTICE: collapse step %d us a tick before, %d after" % [off["step_usec"], on["step_usec"]]
	)
	print(
		(
			"NOTICE: neighbour max overlap before %.2f, after %.2f"
			% [off["neighbour"], on["neighbour"]]
		)
	)
	check(Num.f(off["neighbour"]) > 0.4, "the fixture reaches the neighbour: %s" % off)
	check(Num.f(on["neighbour"]) <= TOLERANCE, "never inside a standing neighbour: %s" % on)
	check(
		Num.i(on["carved"]) > 0 or str(on["contact"]) == "building", "it carves or stops: %s" % on
	)


## The same tower toppling onto the kaiju: it breaks up against his hide, never inside it.
func _check_kaiju_topple() -> void:
	var off := _topple_run(false, true)
	var on := _topple_run(true, true)
	print(
		"NOTICE: kaiju (topple) max overlap before %.2f, after %.2f" % [off["kaiju"], on["kaiju"]]
	)
	check(Num.f(off["kaiju"]) > 0.5, "the fixture reaches the kaiju: %s" % off)
	check(Num.f(on["kaiju"]) <= TOLERANCE, "never inside the kaiju's hide: %s" % on)
	check(str(on["contact"]) == "kaiju", "it breaks up against him: %s" % on)


## The tower's top floors dropping straight onto the kaiju standing in its footprint.
func _check_kaiju_drop() -> void:
	var results: Array[Dictionary] = []
	for contact: bool in [false, true]:
		var sim := _contact_sim(contact, true, Vector2(0, 0))
		var b := sim.buildings[0]
		var f := RampageSim.Fall.new()
		f.building = 0
		f.kind = "drop"
		for x: int in b.w:
			for z: int in b.d:
				for y: int in range(11, b.height):
					f.cells.append(Vector3i(x, y, z))
		f.drop = 11.0
		f.pivot = b.local_to_world(Vector3(b.w * 0.5, 11, b.d * 0.5))
		f.duration = sqrt(2.0 * f.drop / Num.f(sim.city["fall_gravity"]))
		results.append(_follow(sim, f))
		sim.dispose()
	print(
		(
			"NOTICE: kaiju (drop) max overlap before %.2f, after %.2f"
			% [results[0]["kaiju"], results[1]["kaiju"]]
		)
	)
	check(Num.f(results[0]["kaiju"]) > 0.5, "the drop fixture reaches the kaiju: %s" % results[0])
	check(Num.f(results[1]["kaiju"]) <= TOLERANCE, "a drop never sinks into him: %s" % results[1])
	check(str(results[1]["contact"]) == "kaiju", "a drop breaks up on him: %s" % results[1])


## A part breaking up on the kaiju: its fragments, thrown from where its chunks were (inside and
## round his hide), fall off him and settle outside it.
func _check_fragments_outside() -> void:
	var sim := _contact_sim(true, true, Vector2(6, 0))
	var world := Node3D.new()
	root.add_child(world)
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	gs.shape = box
	gs.position.y = -0.5
	ground.add_child(gs)
	world.add_child(ground)
	var hide := KaijuHide.new(sim)
	world.add_child(hide)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var field := DebrisField.new(rng, 400)
	field.keep_out = hide.outside
	world.add_child(field)
	var cap := hide.capsule()
	var top: Vector3 = cap[1]
	for n: int in 160:  # a slab's chunks across and over him
		var at := (
			top + Vector3(rng.randf_range(-4, 4), rng.randf_range(-2, 4), rng.randf_range(-3, 3))
		)
		var away := Vector3(at.x - top.x, 0.3, at.z - top.z).normalized()
		field.spawn(at, Color.GRAY, away)
	for _i: int in 240:
		await physics_frame
	var worst := -INF
	var bodies := 0
	for body: Node in field.get_children():
		if body is RigidBody3D:
			var rb: RigidBody3D = body
			bodies += 1
			worst = maxf(worst, FallContact.hide_depth(rb.global_position, cap))
	print("NOTICE: fragments %d, deepest centre inside the hide %.2f" % [bodies, worst])
	check(bodies >= 150, "the fragments were thrown: %d" % bodies)
	check(worst <= FRAGMENT_TOLERANCE, "every fragment ends outside his hide: %.2f" % worst)
	world.queue_free()
	await process_frame
	sim.dispose()


## A sim with the tower at the origin, a 4x4x6 neighbour east of it (or none) and the kaiju at
## `at`; fall_contact.on = `contact`.
func _contact_sim(contact: bool, kaiju: bool, at: Vector2) -> RampageSim:
	var tuning: Dictionary = Content.tuning().duplicate(true)
	tuning["fall_contact"]["on"] = contact
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), {}, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout: Array[Dictionary] = [_b(0, 0, TOWER)]
	if not kaiju:
		layout.append(_b(5, 0, Vector3i(4, 4, 6)))
	layout.append(_b(38.0, 38.0, Vector3i(2, 2, 2)))
	var sim := RampageSim.new(stats, tuning, layout, Seeds.make("army", 0))
	sim.kaiju_pos = at if kaiju else Vector2(-30, -30)
	return sim


## The tower toppling east from its east edge; the max overlaps seen.
func _topple_run(contact: bool, kaiju: bool) -> Dictionary:
	var sim := _contact_sim(contact, kaiju, Vector2(6, 0))
	var b := sim.buildings[0]
	var f := RampageSim.Fall.new()
	f.building = 0
	f.kind = "topple"
	for x: int in b.w:
		for z: int in b.d:
			for y: int in b.height:
				f.cells.append(Vector3i(x, y, z))
	f.height = b.height
	f.dir = Vector2(1, 0)
	f.pivot = b.local_to_world(Vector3(b.w, 0, b.d * 0.5))
	f.duration = sqrt(2.0 * f.height / Num.f(sim.city["fall_gravity"])) * 1.8
	var out := _follow(sim, f)
	sim.dispose()
	return out


## Steps the collapse alone with f falling; after each step measures f where the view draws it.
func _follow(sim: RampageSim, f: RampageSim.Fall) -> Dictionary:
	sim.falls.append(f)
	var topple := Content.section("topple_fx")
	var cfg := Content.section("fall_contact")
	var neighbour := 1 if sim.buildings.size() > 2 else -1
	var start := 0
	if neighbour >= 0:
		start = _alive_chunks(sim.buildings[neighbour])
	var worst := {"neighbour": 0.0, "kaiju": 0.0}
	var steps := 0
	var usec := 0
	while sim.falls.has(f) and steps < 400:
		var t0 := Time.get_ticks_usec()
		sim.collapse.step(DT)
		usec += Time.get_ticks_usec() - t0
		steps += 1
		var t := minf(f.t, f.duration)
		var k := t / f.duration
		var basis := FallMotion.topple_turn(f.dir, ToppleFx.tilt(topple, t, f.duration))
		if f.kind != "topple":
			basis = Basis()
		var xf := Transform3D(basis, f.pivot - Vector3(0, f.drop * k * k, 0))
		var own := sim.buildings[f.building]
		var cap := FallContact.hide(sim, cfg)
		for c: Vector3i in f.cells:
			var rel := own.chunk_world(c) - f.pivot
			for i: int in SAMPLES * SAMPLES * SAMPLES:
				var q := Vector3(i % SAMPLES, (i / SAMPLES) % SAMPLES, i / (SAMPLES * SAMPLES))
				var p := xf * (rel + (q + Vector3.ONE * 0.5) / SAMPLES - Vector3.ONE * 0.5)
				if neighbour >= 0:
					var d := FallContact.chunk_depth(sim.buildings[neighbour], p)
					worst["neighbour"] = maxf(Num.f(worst["neighbour"]), d)
				worst["kaiju"] = maxf(Num.f(worst["kaiju"]), FallContact.hide_depth(p, cap))
	worst["contact"] = f.contact
	worst["steps"] = steps
	worst["step_usec"] = usec / maxi(1, steps)  # the collapse step's cost with this fall in it
	worst["carved"] = start - _alive_chunks(sim.buildings[neighbour]) if neighbour >= 0 else 0
	return worst


func _alive_chunks(b: RampageSim.Building) -> int:
	var n := 0
	for x: int in b.w:
		for z: int in b.d:
			for y: int in b.height:
				n += int(b.frame.alive(Vector3i(x, y, z)))
	return n
