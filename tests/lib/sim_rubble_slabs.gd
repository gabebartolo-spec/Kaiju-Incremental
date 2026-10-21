extends RefCounted
## The sim suite's rubble checks (D-110, comments #24 #25), split out to keep the runner small:
##  - a toppled tower leaves big slabs on the street; the young reptilian walks through them and
##    after every step no slab lies inside its body (they break into smaller ones and gravel);
##    with breaking off (today's game) the same walk leaves the body inside a slab;
##  - a stomp breaks a slab the body does not touch;
##  - a tower toppled onto the kaiju breaks where it meets him: it lands before its fall time,
##    what comes down in line stops at his body, and what folds off his side lies outside him;
##    with the contact off (today's game) it falls through him;
##  - the same seeded run gives the same slabs and events twice.
## Seeded by design: fixed layouts, Seeds.make("army", 0), the sim's own derived streams.

const DT := 1.0 / 30.0
const LAND_STEPS := 30 * 6
const WALK_STEPS := 30 * 4

var _check: Callable


func _init(p_check: Callable) -> void:
	_check = p_check


func run() -> void:
	_walk_through()
	_stomp_breaks()
	_falls_on_kaiju()
	_replay()


## A 14-floor tower whose west base is cut: it topples west (D-099) away from the kaiju.
func _sim(kaiju: Vector2) -> RampageSim:
	var layout: Array[Dictionary] = [
		{"x": 0.0, "z": 0.0, "w": 3, "d": 3, "h": 14, "tier": 1, "style": 0},
		{"x": 25.0, "z": -25.0, "w": 3, "d": 3, "h": 4, "tier": 1, "style": 1},  # keeps it going
	]
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades(), {})
	)
	var sim := RampageSim.new(stats, Content.tuning(), layout, Seeds.make("army", 0))
	sim.body.use_species("reptilian")
	sim.kaiju_pos = kaiju
	var base: Array[Vector3i] = []
	for x: int in 2:
		for z: int in 3:
			base.append(Vector3i(x, 0, z))
	sim.damage_chunks(0, base, 999.0)
	return sim


## Steps until the fall lands; returns its fall_land event ({} if none).
static func _land(sim: RampageSim) -> Dictionary:
	for i: int in LAND_STEPS:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "fall_land":
				return event
	return {}


## Slabs lying inside the body now.
static func _inside(sim: RampageSim) -> int:
	var n := 0
	for s: RubbleSlabs.Slab in sim.collapse.slabs.slabs:
		for d: Array in sim.body.world_discs(sim.kaiju_pos, sim.body.heading):
			var c: Vector2 = d[0]
			if RubbleSlabs._overlaps(s, c, Num.f(d[1]), Num.f(d[2])):
				n += 1
				break
	return n


## Lands the tower far from the kaiju, then walks him along the strip through its slabs.
func _walk(breaking: bool) -> Dictionary:
	var sim := _sim(Vector2(30.0, 30.0))
	sim.collapse.slabs.breaks = breaking
	var land := _land(sim)
	var landed := sim.collapse.slabs.slabs.size()
	var biggest := 0.0
	for s: RubbleSlabs.Slab in sim.collapse.slabs.slabs:
		biggest = maxf(biggest, maxf(s.dims.x, s.dims.z))
	sim.kaiju_pos = Vector2(-1.0, 0.0)
	sim.facing = Vector2(-1, 0)
	sim.body.heading = sim.facing
	var worst := 0
	var steps_inside := 0
	var breaks := 0
	for i: int in WALK_STEPS:
		for event: Dictionary in sim.step(DT, Vector2(-1, 0), false):
			if str(event["type"]) == "slab_break":
				breaks += 1
		var inside := _inside(sim)
		worst = maxi(worst, inside)
		steps_inside += int(inside > 0)
	return {
		"landed": landed,
		"biggest": biggest,
		"land": land,
		"worst": worst,
		"steps": steps_inside,
		"breaks": breaks,
		"left": sim.collapse.slabs.slabs.size(),
	}


func _walk_through() -> void:
	var on := _walk(true)
	var off := _walk(false)
	var land: Dictionary = on["land"]
	var listed: Array = land.get("slabs", [])
	_check.call(
		Num.i(on["landed"]) >= 5 and Num.f(on["biggest"]) >= 1.2 and listed.size() == on["landed"],
		(
			"a toppled tower leaves big slabs on the street: %d (biggest %.2f), %d in fall_land"
			% [Num.i(on["landed"]), Num.f(on["biggest"]), listed.size()]
		)
	)
	_check.call(
		Num.i(off["steps"]) > 0,
		(
			"with breaking off the walk leaves the body inside a slab on %d steps (it clips)"
			% Num.i(off["steps"])
		)
	)
	_check.call(
		Num.i(on["steps"]) == 0 and Num.i(on["breaks"]) > 0,
		(
			"with it, the body breaks what it walks into: inside on %d steps, %d breaks, %d left"
			% [Num.i(on["steps"]), Num.i(on["breaks"]), Num.i(on["left"])]
		)
	)


## A stomp's ring breaks a slab beyond the body's reach.
func _stomp_breaks() -> void:
	var sim := _sim(Vector2(30.0, 30.0))
	_land(sim)
	var slabs := sim.collapse.slabs
	var before := slabs.slabs.size()
	var target: RubbleSlabs.Slab = slabs.slabs[0]
	var widest := 0.0
	for d: Array in sim.body.discs():
		widest = maxf(widest, Num.f(d[1]) * sim.body_scale())
	var gap := widest + Vector2(target.dims.x, target.dims.z).length() * 0.5 + 0.3
	sim.kaiju_pos = target.pos + Vector2(gap, 0)  # beside it, across the body's length
	var touched := 0
	for d: Array in sim.body.world_discs(sim.kaiju_pos, sim.body.heading):
		var c: Vector2 = d[0]
		touched += int(RubbleSlabs._overlaps(target, c, Num.f(d[1]), Num.f(d[2])))
	var by_blow := false
	var stomped := false
	for i: int in 30 * 3:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			stomped = stomped or str(event["type"]) == "stomp"
			if str(event["type"]) == "slab_break" and Num.i(event["id"]) == target.id:
				by_blow = str(event["by"]) == "blow"
		if by_blow:
			break
	_check.call(
		touched == 0 and stomped and by_blow and slabs.broken > 0,
		(
			"a stomp breaks a slab the body does not touch (touching %d, stomped %s, %d of %d)"
			% [touched, stomped, slabs.broken, before]
		)
	)


## The tower topples west onto the kaiju standing in its path, his body across the strip.
func _onto(contact: bool) -> Dictionary:
	var sim := _sim(Vector2(-9.0, 0.0))
	sim.collapse.breaks_on_kaiju = contact
	var f: RampageSim.Fall = sim.falls[0]
	var duration := f.duration
	var t := 0.0
	var land := {}
	for i: int in LAND_STEPS:
		t += DT
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "fall_land":
				land = event
		if not land.is_empty():
			break
	return {"sim": sim, "land": land, "t": t, "duration": duration}


func _falls_on_kaiju() -> void:
	var off := _onto(false)
	var off_land: Dictionary = off["land"]
	var through := 0.0
	if not off_land.is_empty():
		var to: Vector2 = off_land["to"]
		through = to.x  # west of the kaiju's x (-9) when it fell through him
	_check.call(
		not off_land.has("hit") and through < -12.0,
		"with the contact off the tower falls through the kaiju to x %.1f" % through
	)
	var on := _onto(true)
	var land: Dictionary = on["land"]
	var sim: RampageSim = on["sim"]
	var hit: Dictionary = land.get("hit", {})
	var early := Num.f(on["t"]) < Num.f(on["duration"]) - DT
	var to: Vector2 = land.get("to", Vector2.ZERO)
	var front := 9999.0  # the body's nearest point to the tower along the fall
	for d: Array in sim.body.world_discs(sim.kaiju_pos, sim.body.heading):
		var c: Vector2 = d[0]
		if absf(c.y) < 2.0 + Num.f(d[1]):
			front = minf(front, -1.5 - (c.x + Num.f(d[1])))
	var stopped := absf(to.x + 1.5) <= front + 0.5
	var pieces: Array = hit.get("pieces", [])
	(
		_check
		. call(
			not hit.is_empty() and early and stopped,
			(
				"a tower toppled onto the kaiju breaks on him: hit %s, at %.2f of %.2f s, in line to x %.1f"
				% [not hit.is_empty(), Num.f(on["t"]), Num.f(on["duration"]), to.x]
			)
		)
	)
	_check.call(
		Num.i(hit.get("large", 0)) >= 2 and _inside(sim) == 0,
		(
			"what was above the crack folds off his side as %d large slabs (%d pieces), none in him"
			% [Num.i(hit.get("large", 0)), pieces.size()]
		)
	)


## Two runs of the same seed: the same slabs, breaks and events.
func _replay() -> void:
	var digests: Array[int] = []
	for run: int in 2:
		var sim := _sim(Vector2(-9.0, 0.0))
		var events: Array = []
		for i: int in LAND_STEPS:
			events.append_array(sim.step(DT, Vector2(-0.3, 1.0), false))
		digests.append(hash([sim.collapse.slabs.digest(), str(events)]))
	_check.call(digests[0] == digests[1], "the rubble replays the same per seed: %s" % [digests])
