class_name StrayShell
extends RefCounted
## A clumsy military (director, comments #18: "tanks shouldnt be perfectly accurate every time,
## i really like the idea of a clumsy military which destroys parts of its own city
## occasionally"). A tank's shot at the kaiju hits with a chance that falls from hit_near at
## point blank to hit_far at full reach; a hit does the shot's damage / that chance, so the
## kaiju takes what it took before on average. A miss flies on past the kaiju, scattered, and
## lands in the city: it breaks the chunks it reaches on the low floors like any blow (the
## carving path for carved buildings). Seeded by the army's own stream; numbers are army.miss in
## data/tuning.json.


## The chance a shot from `dist` hits, with the tanks' full reach `reach`.
static func chance(cfg: Dictionary, dist: float, reach: float) -> float:
	var miss: Dictionary = cfg["miss"]
	var t := clampf(dist / maxf(reach, 0.001), 0.0, 1.0)
	return lerpf(Num.f(miss["hit_near"]), Num.f(miss["hit_far"]), t)


## Where a missed shell fired from `from` lands: on past the kaiju's body along the line of fire,
## up to scatter further, and up to scatter / 2 to either side.
static func landing(sim: RampageSim, from: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var miss: Dictionary = sim.army["miss"]
	var scatter := Num.f(miss["scatter"])
	var line := (sim.kaiju_pos - from).normalized()
	var body := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	var on := body + rng.randf_range(0.2, 1.0) * scatter
	var side := rng.randf_range(-0.5, 0.5) * scatter
	return sim.kaiju_pos + line * on + line.orthogonal() * side


## The shell lands at `at`: every standing chunk within radius on the floors below `floors` takes
## the shell's damage (falling off past it). Tanks, squads and helicopters are not touched.
static func land(sim: RampageSim, at: Vector2) -> void:
	var miss: Dictionary = sim.army["miss"]
	var radius := Num.f(miss["radius"])
	hit_buildings(
		sim,
		func(p: Vector2, r: float) -> float:
			return RampageSim.falloff(p.distance_to(at) - r, radius),
		Num.f(miss["damage"]),
		Vector2i(0, Num.i(miss["floors"]))
	)


## Damages every standing chunk on floors floors.x..floors.y-1 that `force` (position, own radius
## -> 0..1) reaches by damage x force, through the carving path for carved buildings, and lets the
## hit buildings settle (RampageSim.hit_area's buildings, shared with it).
static func hit_buildings(
	sim: RampageSim, force: Callable, damage: float, floors: Vector2i
) -> void:
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var near: float = force.call(Vector2(b.x, b.z), Vector2(b.w, b.d).length() * 0.5)
		if near > 0.0 and sim.carving.takes(i):
			sim.carving.hit(i, force, damage, floors)  # coats what it reaches too
			continue
		if near <= 0.0 or b.frame.alive_count == 0:
			continue
		var cells: Array[Vector3i] = []
		var amounts := PackedFloat32Array()
		for y: int in range(maxi(0, floors.x), mini(floors.y, b.height)):
			for x: int in b.w:
				for z: int in b.d:
					var c := Vector3i(x, y, z)
					if b.frame.alive(c):
						var p := b.chunk_world(c)
						var k: float = force.call(Vector2(p.x, p.z), 0.5)
						if k > 0.0:
							cells.append(c)
							amounts.append(damage * k)
		if not sim.hit_coat.is_empty():
			sim.powers.coat(i, cells)
		sim.damage_cells(i, cells, amounts)
