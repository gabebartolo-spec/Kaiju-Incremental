class_name CarvePace
extends RefCounted
## When Carving's heavy work runs (b2-3: one sim step that promoted and fully settled a dozen
## buildings took over a second). Two rules, both in sim steps, so a replay is the same:
##  - settles: a step settles buildings until it has spent settle_cells grid cells on full settles
##    (the flood's cost grows with the grid); a building carved after that waits, in the order
##    it was carved, for the next step, which settles the waiting ones first. The first settle
##    of a step always runs, so the queue always moves;
##  - warm-up: a step with nothing waiting and nothing settled does one stage of work on the
##    nearest building the kaiju can carve but has not hit, within warm_range past its ability
##    reach: promote it (its fine grid), then settle it, then build its settle cache, a stage a
##    step. Its first hit then pays for none of them.
## data/tuning.json "destruction": settle_cells, warm_range (0 turns the warm-up off).

var settle_cells := 0
var warm_range := 0.0
var _carving: Carving
## Buildings carved this step or before whose settle has not run yet, in carving order.
var _held: Array[int] = []
## Grid cells spent on full settles this step.
var _spent := 0
## The building being warmed (-1: none) and whether its settle has run.
var _warming := -1


func _init(carving: Carving, cfg: Dictionary) -> void:
	_carving = carving
	settle_cells = Num.i(cfg.get("settle_cells", 0))
	warm_range = Num.f(cfg.get("warm_range", 0.0))


## Once a sim step, before anything moves: the settles held back run, then the warm-up.
func tick() -> void:
	_spent = 0
	var sim := _carving.sim
	if not _carving.on or sim.over:
		return
	while not _held.is_empty() and (_spent == 0 or _spent < settle_cells):
		var n: int = _held.pop_front()
		sim.collapse.settle(n)
	if _held.is_empty() and _spent == 0:
		_warm()


## Building n was carved: settles it now if this step has budget left, else holds it.
func settle(n: int) -> void:
	if _held.has(n):
		return  # it settles in its turn, with every cell lost by then
	if settle_cells > 0 and _spent >= settle_cells:
		_held.append(n)
		return
	_carving.sim.collapse.settle(n)


## A full settle of a grid of `cells` cells ran (Carving.settle reports it).
func spent(cells: int) -> void:
	_spent += cells


## True while building n waits for its settle.
func holds(n: int) -> bool:
	return _held.has(n)


func _warm() -> void:
	if _warming >= 0:
		var f := _carving.frame(_warming)
		if not f.settled():
			_carving.sim.collapse.settle(_warming)
		else:
			f.prime()
			_warming = -1
		return
	var n := _nearest_cold()
	if n >= 0:
		_carving.promote(n)
		_warming = n


## The unpromoted building the kaiju can carve nearest to it, within warm_range past its ability
## reach (its footprint's half diagonal counts as hit_area's does); ties: the lower index.
func _nearest_cold() -> int:
	if warm_range <= 0.0:
		return -1
	var sim := _carving.sim
	var best := -1
	var best_gap := sim.ability_reach() + warm_range
	for n: int in sim.buildings.size():
		var b := sim.buildings[n]
		if _carving.promoted(n) or not _carving.takes(n) or b.frame.alive_count == 0:
			continue
		var gap := sim.kaiju_pos.distance_to(Vector2(b.x, b.z)) - Vector2(b.w, b.d).length() * 0.5
		if gap < best_gap:
			best_gap = gap
			best = n
	return best
