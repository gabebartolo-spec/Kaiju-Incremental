class_name StrayShell
extends RefCounted
## A clumsy military (director, comments #18: "tanks shouldnt be perfectly accurate every time,
## i really like the idea of a clumsy military which destroys parts of its own city
## occasionally"). A tank's shot at the kaiju hits with a chance that falls from hit_near at
## point blank to hit_far at full reach; a hit does the shot's damage / that chance, so the
## kaiju takes what it took before on average. A miss lands in the city round the kaiju: it
## breaks the chunks it reaches on the low floors like any blow (the carving path for carved
## buildings). Seeded by the army's own stream; numbers are army.miss in data/tuning.json.


## The chance a shot from `dist` hits, with the tanks' full reach `reach`.
static func chance(cfg: Dictionary, dist: float, reach: float) -> float:
	var miss: Dictionary = cfg["miss"]
	var t := clampf(dist / maxf(reach, 0.001), 0.0, 1.0)
	return lerpf(Num.f(miss["hit_near"]), Num.f(miss["hit_far"]), t)


## Where a missed shell lands: beside the kaiju (director, 2026-10-21: "land beside him", so the
## player sees it break the buildings next to him), on a ring round it at a random angle, from
## ring_near to ring_far out past its body. Not along the line of fire: a tank to one side would
## put it behind the kaiju from the camera. A shell that lands in the street breaks nothing, so
## it tries up to ring_tries spots and takes the first within the blast radius of a standing
## building (the last when none is).
static func landing(sim: RampageSim, rng: RandomNumberGenerator) -> Vector2:
	var miss: Dictionary = sim.army["miss"]
	var body := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	var at := sim.kaiju_pos
	for _try: int in maxi(1, Num.i(miss["ring_tries"])):
		var out := body + rng.randf_range(Num.f(miss["ring_near"]), Num.f(miss["ring_far"]))
		at = sim.kaiju_pos + Vector2.from_angle(rng.randf_range(0.0, TAU)) * out
		if _near_building(sim, at, Num.f(miss["radius"])):
			break
	return at


## Is a standing building's footprint within `reach` of p?
static func _near_building(sim: RampageSim, p: Vector2, reach: float) -> bool:
	for b: RampageSim.Building in sim.buildings:
		if b.frame.alive_count == 0:
			continue
		var half := Vector2(b.w, b.d) * 0.5 + Vector2(reach, reach)
		if absf(p.x - b.x) <= half.x and absf(p.y - b.z) <= half.y:
			return true
	return false


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
			sim.explosives.damaged(i)  # any damage arms a red barrel (comments #19)
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
