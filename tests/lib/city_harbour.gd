extends RefCounted
## The kaiju rises from the sea bay and walks up its beach into the city (director 2026-10-26: "move
## it to the bay where a shoreline makes more natural sense", "Sea bay, real beach"; D-270: a
## crescent bay on the city's north edge, laid first as a fixed rectangle of whole blocks
## (CityHarbour), at least 2 blocks wide at stage 1, growing with the arena; earlier, 2026-10-21
## #17: "have him emerging facing the city so he can walk straight in"): the run's start (Emergence)
## rises in open water over the sea floor, facing the city, never turning or sliding sideways
## through the rise, the wade up the beach and its first second of walking ahead; the beach slopes
## from the sea floor to sand just under the street; nothing (street, building, prop, walker) stands
## in the bay; the railway keeps clear of the rise.

const DT := 1.0 / 30.0
const WALK := 1.0  # seconds of walking ahead once out
const SLIDE := 0.02  # metres sideways, and radians of turn, that still count as none
const WADE_SAMPLES := 64  # points along the wade line checked against the viaduct
const ON_BANK := 1.0  # metres from the bank point the wade may end
const STOMP := 3.0  # metres: the stomp at the rise bank that flattens the beach props there
const SAND_UNDER := 0.25  # metres: the sand's top lies within this under the street
## Each keyed rise_bay crouch's back top at its first frame, per body scale (metres over the
## feet): the adult's highest bone 3.58 plus 0.6 of hide (tools/capture/probe_rise.gd), the
## Behemoth's back 5.67 (keyer, 2026-10-28). Measured, not read from the tuning.
const CROUCH_TOPS := {"adult": 4.18, "Behemoth": 5.67}


static func check(
	tier: int, map_seed: int, sim: RampageSim, decor: CityDecor, check_fn: Callable
) -> void:
	var plan := CityGen.map(sim.city)
	check_fn.call(
		plan.has("harbour"), "stage %d, map_seed %d: the city has its sea bay" % [tier, map_seed]
	)
	if not plan.has("harbour"):
		return
	_check_walk_in(tier, map_seed, _fresh(tier, map_seed), check_fn)
	_check_bay(tier, map_seed, sim, plan, decor, check_fn)
	_check_beach_props(tier, map_seed, sim, plan, decor, check_fn)


static func _check_walk_in(tier: int, map_seed: int, sim: RampageSim, check_fn: Callable) -> void:
	sim.emerge.start(sim)
	var start := sim.kaiju_pos
	var ahead := sim.facing
	var side := 0.0
	var turn := 0.0
	var t := 0.0
	var out_at := -1.0
	var out_pos := Vector2.INF
	while (
		t < Num.f(Content.tuning()["emerge"]["max_seconds"]) + WALK
		and (out_at < 0.0 or t < out_at + WALK)
	):
		sim.step(DT, Vector2.ZERO if sim.emerge.active else ahead, false)
		t += DT
		if out_at < 0.0 and not sim.emerge.active:
			out_at = t
			out_pos = sim.kaiju_pos
		side = maxf(side, absf((sim.kaiju_pos - start).cross(ahead)))
		turn = maxf(turn, absf(sim.facing.angle_to(ahead)))
		turn = maxf(turn, absf(sim.body.heading.angle_to(ahead)))
	var plan := CityGen.map(sim.city)
	var bank: Vector2 = plan["rise_bank"]
	var into_city := ahead.dot(-start.normalized()) > 0.5
	var ashore := out_pos.distance_to(bank) <= ON_BANK and not CityHarbour.holds(plan, out_pos)
	check_fn.call(
		into_city and side <= SLIDE and turn <= SLIDE and out_at > 0.0 and ashore,
		(
			(
				"stage %d, map_seed %d: the kaiju rises facing the city (%s from %s) and walks"
				+ " straight up the beach to the bank %s (out at %s): %.3f m sideways, %.3f rad"
				+ " of turn, out after %.1f s"
			)
			% [tier, map_seed, ahead, start, bank, out_pos, side, turn, out_at]
		)
	)


## The biggest kaiju that can emerge at this stage (size tier = stage, as Main starts a run; the
## most growth it can own there, EmergeReach: director 2026-10-21, "Fit the biggest possible")
## rises in open water: its rise point is in the bay over the sea floor (CityHarbour.seabed), and
## through the rise no part of its body's discs is outside the bay's water (or the open sea past
## its mouth, where the biggest body's tail may reach).
## At this stage the sea floor at the rise lies deep enough that every measured crouch
## (CROUCH_TOPS) at the stage's biggest body scale starts wholly under the water: the back never
## shows at the rise's first frame (coordinator 2026-10-28).
static func check_seabed(tier: int, check_fn: Callable) -> void:
	var tuning := CityGrowth.tuning_for(Content.tuning().duplicate(true), tier)
	var cfg: Dictionary = tuning["city"]
	var depth := CityHarbour.sea(cfg) - CityHarbour.seabed(cfg)
	var scale := EmergeReach.biggest_scale(tuning, Content.upgrades(), tier)
	var tallest := ""
	var top := 0.0
	for form: String in CROUCH_TOPS:
		if Num.f(CROUCH_TOPS[form]) * scale > top:
			top = Num.f(CROUCH_TOPS[form]) * scale
			tallest = form
	(
		check_fn
		. call(
			depth >= top,
			(
				(
					"stage %d: the sea floor at the rise lies %.2f m under the water, over the %s crouch's"
					+ " back (%.2f m at body scale %.2f)"
				)
				% [tier, depth, tallest, top, scale]
			)
		)
	)


static func check_rise(tier: int, map_seed: int, check_fn: Callable) -> void:
	var grown := EmergeReach.max_growth(Content.upgrades(), "reptilian", tier)
	var sim := _fresh(tier, map_seed, tier, grown)
	sim.emerge.start(sim)
	var plan := CityGen.map(sim.city)
	var at := sim.kaiju_pos
	var bed := CityHarbour.floor_at(plan, sim.city, at)
	var deep := absf(bed - CityHarbour.seabed(sim.city)) < 0.01
	var dry := 0
	while sim.emerge.active and sim.emerge.risen() < 1.0:
		sim.step(DT, Vector2.ZERO, false)
		dry = maxi(dry, _on_ground(sim, plan))
	check_fn.call(
		CityHarbour.holds(plan, at) and deep and dry == 0,
		(
			(
				"stage %d, map_seed %d: the size-%d kaiju at growth %d (%.1f m) rises at %s in the"
				+ " bay (%s) over the sea floor (%.2f, seabed %.2f): %d points of its body over"
				+ " dry ground"
			)
			% [
				tier,
				map_seed,
				sim.size_tier(),
				grown,
				sim.body.length(),
				at,
				CityHarbour.holds(plan, at),
				bed,
				CityHarbour.seabed(sim.city),
				dry
			]
		)
	)


## The railway's viaduct (D-247) keeps clear of the rise (sim review #245, finding 1): no rail
## piece meets the biggest body's footprint at the rise (Emergence.footprint, its fit margin
## included) nor the line it wades from the rise point to the bank point.
static func check_rail_clear(tier: int, map_seed: int, check_fn: Callable) -> void:
	var grown := EmergeReach.max_growth(Content.upgrades(), "reptilian", tier)
	var sim := _fresh(tier, map_seed, tier, grown)
	sim.emerge.start(sim)
	var plan := CityGen.map(sim.city)
	if not plan.has("rise_spawn"):
		return
	var foot: Rect2 = sim.emerge.footprint(sim)
	var spawn := sim.kaiju_pos
	var bank: Vector2 = plan.get("rise_bank", spawn)
	var hits: Array[Vector2] = []
	for b: RampageSim.Building in sim.buildings:
		if not b.is_span():
			continue
		var r := Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)
		var crossed := false
		for k: int in WADE_SAMPLES + 1:
			crossed = crossed or r.has_point(spawn.lerp(bank, float(k) / WADE_SAMPLES))
		if r.intersects(foot) or crossed:
			hits.append(Vector2(b.x, b.z))
	check_fn.call(
		hits.is_empty(),
		(
			(
				"stage %d, map_seed %d: no rail piece meets the rise (footprint %s) or the wade"
				+ " from %s to %s: %s"
			)
			% [tier, map_seed, foot, spawn, bank, hits]
		)
	)


## The beachfront is the same at every stage (D-381, director 2026-10-29: "its always the
## same"): its rectangle, its shapes (shoreline, port, side streets) and the rise point match
## stage 1's at every later stage, for every map seed.
static func check_fixed(map_seed: int, check_fn: Callable) -> void:
	var first := {}
	var moved: Array[int] = []
	for tier: int in range(1, CityGrowth.stage_count(Content.tuning()) + 1):
		var plan := CityGen.map(_fresh(tier, map_seed).city)
		var b: Dictionary = plan["harbour"]
		var shape := [
			plan["bay"], b["rect"], b["apex"], b["quay_z"], b["sides"], plan["rise_spawn"]
		]
		if first.is_empty():
			first["shape"] = shape
		elif shape != first["shape"]:
			moved.append(tier)
	check_fn.call(
		moved.is_empty(),
		"map_seed %d: the beachfront is the same at every stage (moved at %s)" % [map_seed, moved]
	)


## How many sample points of the body's discs (centre, and eight round the rim) lie outside the
## bay's water.
static func _on_ground(sim: RampageSim, plan: Dictionary) -> int:
	var mouth := Num.f(plan["harbour"]["mouth"])
	var s := sim.body_scale()
	var out := 0
	for d: Array in sim.body.discs():
		var c := sim.kaiju_pos + sim.facing * Num.f(d[0]) * s
		var r := Num.f(d[1]) * s
		for k: int in 9:
			var p := c if k == 8 else c + Vector2.from_angle(k * PI / 4.0) * r
			if not CityHarbour.holds(plan, p) and p.y >= mouth:  # past the mouth: the open sea
				out += 1
	return out


## A sim of its own for the walk (it steps, and its stomps break things); size: the kaiju's
## size tier (0: the run stats' own, the young kaiju), growth its upgrade levels owned.
static func _fresh(tier: int, map_seed: int, size: int = 0, growth: int = 0) -> RampageSim:
	var base: Dictionary = Content.tuning().duplicate(true)
	base["city"]["map_seed"] = map_seed
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	if size > 0:
		stats["size"] = size
		stats["growth"] = float(growth)
	var sim := RampageSim.new(
		stats,
		CityGrowth.tuning_for(base, tier),
		CityGrowth.layout(base, tier, Seeds.make("city", 0)),
		Seeds.make("army", 0)
	)
	sim.body.use_species("reptilian")
	return sim


## The beach slopes from the sea floor up to sand just under the street; no street runs into the
## bay; no building or prop stands in it.
static func _check_bay(
	tier: int,
	map_seed: int,
	sim: RampageSim,
	plan: Dictionary,
	decor: CityDecor,
	check_fn: Callable
) -> void:
	var water := CityHarbour.basin(plan)
	var line := CityHarbour.arc(plan, sim.city)
	var mid := line[line.size() / 2]  # the beach's middle, at the curve
	var top := CityHarbour.floor_at(plan, sim.city, mid + Vector2(0.0, -0.01))
	var foot := CityHarbour.floor_at(
		plan, sim.city, mid - Vector2(0.0, Num.f(sim.city["harbour"]["beach"]) + 0.01)
	)
	var sloped := top < 0.0 and top > -SAND_UNDER
	sloped = sloped and absf(foot - CityHarbour.seabed(sim.city)) < 0.01
	var roads := 0
	var nodes: Array[Vector2] = plan["nodes"]
	for street: Dictionary in plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		var road := Rect2(a.min(b), (b - a).abs()).grow(0.01)
		if water.any(func(w: Rect2) -> bool: return w.intersects(road)):
			roads += 1
	var wet := 0
	for b: RampageSim.Building in sim.buildings:
		if wet_at(plan, Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)):
			wet += 1
	for g: Dictionary in decor._props._groups:
		var at: Vector3 = g["at"]
		if CityHarbour.holds(plan, Vector2(at.x, at.z)):
			wet += 1
	check_fn.call(
		sloped and roads == 0 and wet == 0,
		(
			(
				"stage %d, map_seed %d: the beach slopes from the sea floor (%.2f) to sand just"
				+ " under the street (%.2f); %d streets and %d buildings or props in the bay"
			)
			% [tier, map_seed, foot, top, roads, wet]
		)
	)


## The sand is crowded and he flattens it (D-381): umbrellas and courts stand on the sand only,
## none flat until he comes; a stomp at the rise bank flattens those within STOMP of it, and no
## other.
static func _check_beach_props(
	tier: int,
	map_seed: int,
	sim: RampageSim,
	plan: Dictionary,
	decor: CityDecor,
	check_fn: Callable
) -> void:
	var groups: Array[Dictionary] = decor._beach._groups if decor._beach != null else []
	var dry := 0
	var flat := 0
	for g: Dictionary in groups:
		var at: Vector3 = g["at"]
		dry += 0 if CityHarbour.on_sand(plan, sim.city, Vector2(at.x, at.z)) else 1
		flat += 1 if g.get("crushed", false) else 0
	var bank: Vector2 = plan["rise_bank"]
	var hit := Vector3(bank.x, 0.0, bank.y)
	decor.crush(hit, STOMP)
	var under := 0
	var stray := 0
	for g: Dictionary in groups:
		var at: Vector3 = g["at"]
		var near := Vector2(at.x - hit.x, at.z - hit.z).length() <= STOMP
		if g.get("crushed", false):
			under += 1 if near else 0
			stray += 0 if near else 1
	check_fn.call(
		groups.size() > 0 and dry == 0 and flat == 0 and under > 0 and stray == 0,
		(
			(
				"stage %d, map_seed %d: %d beach props, %d off the sand, %d flat before he comes;"
				+ " a stomp at the rise bank flattens %d within %.0f m, %d past it"
			)
			% [tier, map_seed, groups.size(), dry, flat, under, STOMP, stray]
		)
	)


## True when any of nine points over r (corners, edge middles, centre) lies in the front's water
## (CityHarbour.holds): the hotel blocks stand inside the front's rectangle, on dry land.
static func wet_at(plan: Dictionary, r: Rect2) -> bool:
	for i: int in 3:
		for j: int in 3:
			if CityHarbour.holds(plan, r.position + r.size * Vector2(i, j) * 0.5):
				return true
	return false


## No walker's pavement corner, nor the line between two linked corners, in the bay.
static func check_walkers(
	tier: int, map_seed: int, sim: RampageSim, street: StreetLife, check_fn: Callable
) -> void:
	var plan := CityGen.map(sim.city)
	var wet := 0
	var walk: Pavements = street._pavements
	for a: int in walk.nodes.size():
		for b: int in walk.links[a]:
			for k: int in 11:
				if CityHarbour.holds(plan, walk.nodes[a].lerp(walk.nodes[b], k / 10.0)):
					wet += 1
	check_fn.call(
		plan.has("harbour") and wet == 0,
		"stage %d, map_seed %d: no one walks in the bay (%d points)" % [tier, map_seed, wet]
	)
