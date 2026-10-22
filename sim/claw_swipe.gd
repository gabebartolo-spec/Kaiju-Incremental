class_name ClawSwipe
extends RefCounted
## Claws (D-095): every few seconds the reptilian rakes the space in front of it with one arm,
## the arms alternating. The rake is a band ahead of the body (from the chest to past the snout,
## up to arm height) that slashes building fronts, tanks and soldiers at full force. Each Claws
## level hits harder (swipe_damage) and rakes wider (swipe_width); a body without the stats never
## swipes. A claw hit on a building's base counts as chewing it (D-096, director 2026-10-20:
## "Swipes undermine towers"): the face of its floors up to arm height also takes swipe_chew_s
## seconds of the body's bite, so Claws bring big towers down sooner. Part of SpeciesPowers;
## pure, no randomness.

var sim: RampageSim
var cfg: Dictionary
## Swipes so far, and the chunks they broke themselves (not what falls after).
var swipes := 0
var cut := 0
## Fine cells the swipes carved themselves (carving on, D-094 WP7).
var carved := 0
var _timer := 0.0
var _side := 1.0
var _wound := false


## cfg: the "powers" tuning (swipe_interval, swipe_windup, swipe_near, swipe_far, swipe_top,
## swipe_chew_s, swipe_chew_rows).
func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg
	_timer = Num.f(cfg["swipe_interval"])


func step(dt: float) -> void:
	if sim.stat("swipe_damage") <= 0.0:
		return
	_timer -= dt
	if not _wound and _timer <= Num.f(cfg["swipe_windup"]) and not sim.airborne:
		# The arm lifts this long before the rake lands (presentation's cue; changes nothing).
		_wound = true
		sim.events.append({"type": "swipe_windup", "side": -_side})
	if _timer > 0.0 or sim.airborne:
		return
	_timer += Num.f(cfg["swipe_interval"])
	_wound = false
	_rake()


func _rake() -> void:
	var bs := sim.body_scale()
	var near := Num.f(cfg["swipe_near"]) * bs
	var far := Num.f(cfg["swipe_far"]) * bs
	var half := sim.stat("swipe_width") * bs
	var top := sim.stand_y + Num.f(cfg["swipe_top"]) * bs
	var centre := sim.kaiju_pos
	var ahead := sim.facing
	var across := ahead.orthogonal()
	_side = -_side
	swipes += 1
	sim.events.append(
		{"type": "swipe", "side": _side, "near": near, "far": far, "width": half, "top": top}
	)
	var before := sim.chunks_destroyed
	var before_cells := sim.carving.cells_carved
	var band := func(p: Vector2, r: float) -> float:
		var to := p - centre
		var along := to.dot(ahead)
		var inside := along >= near - r and along <= far + r
		return 1.0 if inside and absf(to.dot(across)) <= half + r else 0.0
	var floor_lo := maxi(0, floori(sim.stand_y))
	sim.hit_area(band, sim.stat("swipe_damage") * sim.powers.hit_mult(), floor_lo, ceili(top))
	sim.army_units.taskforce.swat(band, top)  # a jetpack agent in the air is swatted (D-139)
	_undermine(band, Vector2i(floor_lo, ceili(top)), centre, ahead)
	cut += sim.chunks_destroyed - before
	carved += sim.carving.cells_carved - before_cells


## D-096: a building the band reaches has its base face chewed: up to the rake's top (arm
## height), the swipe_chew_rows rows of standing chunks nearest the kaiju (across the whole face,
## as the body chews) take swipe_chew_s seconds of the body's bite. That moves the edge holding
## the tower up, as chewing does, so it tips sooner.
## A claw can't reach through a tower into the block behind it: the chunks across the band are
## split into lanes one chunk wide, and each lane's chunks belong to the nearest standing
## building along it; a building keeps only the lanes it owns, so one standing wholly behind
## another is not chewed.
## floors: the lowest and one past the highest floor the rake reaches.
func _undermine(band: Callable, floors: Vector2i, centre: Vector2, ahead: Vector2) -> void:
	var chew := Num.f(sim.body.cfg["bite_dps"]) * Num.f(cfg["swipe_chew_s"])
	var rows := Num.f(cfg["swipe_chew_rows"])
	if chew <= 0.0:
		return
	var bases: Dictionary = {}  # building index -> its standing base chunks in reach
	var lane_front: Dictionary = {}  # lane -> along of the nearest standing chunk
	var lane_owner: Dictionary = {}  # lane -> index of the building it belongs to
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var near: float = band.call(Vector2(b.x, b.z), Vector2(b.w, b.d).length() * 0.5)
		if near <= 0.0 or b.frame.alive_count == 0:
			continue
		var base: Array[Vector3i] = []
		for y: int in range(floors.x, mini(floors.y, b.height)):
			for x: int in b.w:
				for z: int in b.d:
					var c := Vector3i(x, y, z)
					var at := _where(b, c, centre, ahead)
					if at.x >= 0.0 and b.frame.alive(c):  # the claw rakes ahead of the kaiju
						base.append(c)
						var lane := floori(at.y)
						if at.x < Num.f(lane_front.get(lane, INF)):
							lane_front[lane] = at.x
							lane_owner[lane] = i
		if not base.is_empty():
			bases[i] = base
	for i: int in bases:
		var b := sim.buildings[i]
		var base: Array[Vector3i] = bases[i]
		var seen: Array[Vector3i] = []
		var front := INF
		for c: Vector3i in base:
			var at := _where(b, c, centre, ahead)
			if Num.i(lane_owner[floori(at.y)]) == i:
				seen.append(c)
				front = minf(front, at.x)
		var cells: Array[Vector3i] = []
		for c: Vector3i in seen:
			if _where(b, c, centre, ahead).x < front + rows:
				cells.append(c)
		if not cells.is_empty():
			sim.damage_chunks(i, cells, chew)


## Chunk c of building b as (distance ahead of the kaiju, distance across the rake).
func _where(b: RampageSim.Building, c: Vector3i, centre: Vector2, ahead: Vector2) -> Vector2:
	var p := b.chunk_world(c)
	var to := Vector2(p.x, p.z) - centre
	return Vector2(to.dot(ahead), to.dot(ahead.orthogonal()))
