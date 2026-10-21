extends RefCounted
## What the river's own stonework hides of the rise (comment #27 "Nothing in the foreground hides
## the rise"): the quay walls, the bay's decks with their parapets, the bridges over the channel
## and the sand shore, as solid ground a sight line can strike, for the run intro's shot
## (fade_spawn's check). A deck's hole (the rise bursts up through it) is open from the break.

const STEP := 0.2
## Heights over the street: a deck's slab under it, a parapet on it, a quay wall's width.
const DECK_DEPTH := 0.5
const PARAPET := Vector2(0.9, 0.3)
const QUAY := 0.6
## Where the head, neck and shoulders are: shares of the way from the body's centre to the head
## along its facing, and drops (share of its height) below its top.
const HEAD := [1.0, 0.0]
const NECK := [0.7, 0.15]
const SHOULDERS := [0.45, 0.3]
## The body below the shoulders (comment #27: the rise is seen whole, not only its head).
const CHEST := [0.3, 0.55]
const HIPS := [0.1, 0.85]
const BACK := [-0.5, 0.5]  # behind the body's centre: the back and the tail's root
const REAR := [-1.0, 0.6]
## A part counts once it stands this far above the water.
const SHOWS := 0.1

var _plan: Dictionary
var _cfg: Dictionary
var _across: Array[Rect2]  # east-west decks, parapets along x
var _along: Array[Rect2]  # north-south decks, parapets along z
var _water: Array[Rect2]
var _holes: Array[Rect2]


func _init(sim: RampageSim) -> void:
	_cfg = sim.city
	_plan = CityGen.map(sim.city)
	_across = CityRiver.bay_bridges(_plan, _cfg)
	var inside := CityRiver.bay_bridges_ns(_plan, _cfg)
	_along.assign(CityRiver.bridges(_plan, _cfg).filter(func(d: Rect2) -> bool: return not d in inside))
	_along.append_array(inside)
	_water = CityRiver.water(_plan, _cfg)
	_holes = sim.emerge.burst + sim.emerge.burst_ns


## The points on the kaiju that must show (head, neck, shoulders) now, the ones above the water.
static func parts(sim: RampageSim) -> PackedVector3Array:
	var out := PackedVector3Array()
	var reach := sim.reach_height()
	var water := -Num.f(sim.city.get("river_depth", 0.0))
	var head := sim.facing * Num.f(Content.section("intro")["aim_ahead"]) * sim.body_scale()
	for part: Array in [HEAD, NECK, SHOULDERS, CHEST, HIPS, BACK, REAR]:
		var y: float = sim.stand_y + reach * (0.95 - Num.f(part[1]))
		if y > water + SHOWS:
			var at: Vector2 = sim.kaiju_pos + head * Num.f(part[0])
			out.append(Vector3(at.x, y, at.y))
	return out


## Whether stonework stands on the sight line eye -> to (the last half unit before `to` excluded).
func hides(eye: Vector3, to: Vector3, burst_open: bool, faded := false) -> bool:
	var steps := maxi(1, ceili(eye.distance_to(to) / STEP))
	var reach_end := maxi(1, steps - ceili(0.5 / STEP))
	for i: int in range(0, reach_end + 1):
		if solid(eye.lerp(to, float(i) / steps), burst_open, faded):
			return true
	return false


## `faded`: the shore and the bridges are faded out (IntroFade), so they hide nothing.
func solid(p: Vector3, burst_open: bool, faded := false) -> bool:
	var at := Vector2(p.x, p.z)
	if p.y < _ground(at, faded):
		return true
	if faded:
		return false
	for hole: Rect2 in _holes:
		if burst_open and hole.has_point(at):
			return false
	for deck: Rect2 in _across:
		if deck.has_point(at) and _deck(p, at, deck, true):
			return true
	for deck: Rect2 in _along:
		if deck.has_point(at) and _deck(p, at, deck, false):
			return true
	return false


func _deck(p: Vector3, at: Vector2, deck: Rect2, across: bool) -> bool:
	if p.y <= 0.0 and p.y >= -DECK_DEPTH:
		return true
	var from := at.y - deck.position.y if across else at.x - deck.position.x
	var size := deck.size.y if across else deck.size.x
	return p.y > 0.0 and p.y <= PARAPET.x and (from < PARAPET.y or from > size - PARAPET.y)


## The ground's top at (x, z): the street, the river's floor, the shore's slope, a quay wall
## up to the street along the water's edge.
func _ground(at: Vector2, faded: bool) -> float:
	var top := CityRiver.floor_at(_plan, _cfg, at)
	if faded and CityRiver.shore(_plan, _cfg).has_point(at):
		return -Num.f(_cfg.get("river_depth", 0.0))  # the sand gone: the river's floor
	if top >= 0.0:
		return top
	for w: Rect2 in _water:
		if w.has_point(at) and not w.grow(-QUAY).has_point(at):
			# no wall where the bay opens off the channel (water inside other water)
			var open := _water.any(func(o: Rect2) -> bool: return o != w and o.grow(-0.01).has_point(at))
			return top if open else 0.0
	return top
