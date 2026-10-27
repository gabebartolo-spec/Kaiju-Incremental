class_name Momentum
extends RefCounted
## The titan's run (D-337, "momentum based, at high momentum he can crash right through smaller
## buildings, and collide with a bang into bigger ones"). From the first rampage it builds while he
## walks (to full in build_seconds; the momentum node builds it faster) and bleeds as he turns
## (turn_bleed a radian) or stands (idle_decay a second); it adds speed_bonus x itself to his walk.
## At crash_min he crashes through what stands under his crash height without slowing or spending
## it; at slam_min his first touch of anything taller is a slam: one "slam" event, a dent, momentum
## 0 and the body stopped where it was (then it is held as any wall holds it). Each titan reads its
## own entry (powers.momentum.titans, by creation.titans id): a species with none has no momentum.
## Part of SpeciesPowers; pure, no randomness.

var sim: RampageSim
## 0..1: how much run the titan has built.
var value := 0.0
## Slams so far this rampage.
var slams := 0
## This titan's entry in powers.momentum.titans (empty: no momentum).
var titan: Dictionary = {}
var _cfg: Dictionary
var _touching: Dictionary = {}  # what the body touched last step: a slam is a new touch


## cfg: the tuning's powers.momentum section.
func _init(p_sim: RampageSim, cfg: Dictionary) -> void:
	sim = p_sim
	_cfg = cfg


## Picks the entry of the titan that plays `species_id` (creation.titans); none: no momentum.
func use_species(species_id: String) -> void:
	titan = {}
	var titans: Dictionary = _cfg["titans"]
	var rack: Array = Content.section("creation")["titans"]
	for t: Dictionary in rack:
		var id := str(t["id"])
		if species_id != "" and str(t["species"]) == species_id and titans.has(id):
			titan = titans[id]
			return


func active() -> bool:
	return not titan.is_empty()


## One step's build or bleed: `turn` radians turned this step while `moving` (the stick pushed).
func build(dt: float, turn: float, moving: bool) -> void:
	if not active():
		return
	if moving:
		var boost := 1.0 + sim.stat("momentum") * Num.f(titan["node_build"])
		value += dt * boost / Num.f(titan["build_seconds"]) - turn * Num.f(titan["turn_bleed"])
	else:
		value -= dt * Num.f(titan["idle_decay"])
	value = clampf(value, 0.0, 1.0)


## The walk's speed multiplier from momentum.
func speed_mult() -> float:
	return 1.0 + value * Num.f(titan["speed_bonus"]) if active() else 1.0


## 0..1 for the drawn walk-to-run blend (D-335, the keyed run): the momentum itself.
func blend() -> float:
	return value


## Whether he has the momentum to crash through what stands under his crash height.
func crashing() -> bool:
	return active() and value >= Num.f(titan["crash_min"])


## His crash height now, world units over the ground: his shoulder (by stage) or his body's top.
func crash_height() -> float:
	if str(titan["crash_height"]) == "body":
		var top := 0.0
		for d: Array in sim.body.discs():
			top = maxf(top, Num.f(d[3]))
		return top * sim.body_scale()
	var by_stage: Array = titan["shoulder"]
	return Num.f(by_stage[clampi(sim.size_tier() - 1, 0, by_stage.size() - 1)]) * sim.body_scale()


## Whether a crash takes column (x, z) of building b now: he has the momentum and it stands under
## his crash height.
func crashes_column(b: RampageSim.Building, x: int, z: int) -> bool:
	return crashing() and b.frame.top_below(x, z, b.height) + 1 < crash_height()


## Whether he crashes through building b where the body touches `cells`.
func crashes(b: RampageSim.Building, cells: Array[Vector3i]) -> bool:
	return crashing() and standing(b, cells) < crash_height()


## How many floors building b stands over the columns of `cells`.
static func standing(b: RampageSim.Building, cells: Array[Vector3i]) -> int:
	var top := 0
	for c: Vector3i in cells:
		top = maxi(top, b.frame.top_below(c.x, c.z, b.height) + 1)
	return top


## The body's sweep this step touches `hits` ({building: {cell: true}}). At slam_min the first
## touch of a building at or over his crash height is a slam (never in a leap's flight). Returns
## whether he slammed: the caller stops the body where it was.
func slam(hits: Dictionary) -> bool:
	var was := _touching
	_touching = hits
	if not active() or not bool(titan["slams"]) or value < Num.f(titan["slam_min"]):
		return false
	if sim.body.dash.on():
		return false
	var height := crash_height()
	for index: int in hits:
		var touched: Dictionary = hits[index]
		var cells: Array[Vector3i] = []
		cells.assign(touched.keys())
		if not was.has(index) and standing(sim.buildings[index], cells) >= height:
			_hit(index, cells)
			return true
	return false


## The slam on building `index` where the body touched `cells`: the event (where, how hard), the
## dent, momentum spent.
func _hit(index: int, cells: Array[Vector3i]) -> void:
	var b := sim.buildings[index]
	var strength := value * Num.f(titan["hit"])
	var mid := Vector3.ZERO
	for c: Vector3i in cells:
		mid += b.chunk_world(c)
	mid /= float(cells.size())
	slams += 1
	value = 0.0
	sim.events.append({"type": "slam", "building": index, "at": mid, "strength": strength})
	sim.damage_chunks(index, _dent(b, mid, cells, strength), INF)


## The chunks of b a slam of `strength` breaks: within dent_radius x body scale x strength of the
## contact across the ground, on the floors the body touched (`cells`).
func _dent(
	b: RampageSim.Building, mid: Vector3, cells: Array[Vector3i], strength: float
) -> Array[Vector3i]:
	var radius := Num.f(_cfg["dent_radius"]) * sim.body_scale() * strength
	var lo := b.height
	var hi := 0
	for c: Vector3i in cells:
		lo = mini(lo, c.y)
		hi = maxi(hi, c.y)
	var out: Array[Vector3i] = []
	for x: int in b.w:
		for z: int in b.d:
			var p := b.chunk_world(Vector3i(x, 0, z))
			if Vector2(p.x - mid.x, p.z - mid.z).length() > radius:
				continue
			for y: int in range(lo, hi + 1):
				if b.frame.alive(Vector3i(x, y, z)):
					out.append(Vector3i(x, y, z))
	return out
