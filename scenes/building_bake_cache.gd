class_name BuildingBakeCache
extends RefCounted
## A building's voxels and meshes never change in a rampage (damage is the alive texture), and
## every run of a stage builds the same city, so each BuildingView's mesher is kept here for the
## next run (director's playtest: "load times when you start a run could be quicker"). Key: key().
## Safe on worker threads (BuildingView.build_all makes views there).

static var _baked: Dictionary = {}  # key -> [BuildingMesher, generation]
static var _lock := Mutex.new()
## The city being built (begin_city); an entry not used by it is dropped at end_city, so only
## the current city's buildings stay in memory as the city grows between runs.
static var _generation := 0


## What makes two buildings bake alike: place, size, floors, landmark, hazard, wall colour,
## party walls, and a pool building's model, variant and palette.
static func key(at: RampageSim.Building, base: Color, party: Dictionary) -> String:
	var model := "%s|%s|%d" % [at.model, str(at.variant), at.palette]
	return (
		"%s|%s|%d|%d|%d|%s|%s|%s|%s"
		% [
			at.x,
			at.z,
			at.w,
			at.d,
			at.height,
			at.landmark + at.hazard,
			base.to_html(),
			str(party),
			model
		]
	)


## The kept mesher of this key, marked as the current city's; null when none is kept (the caller
## bakes one and keeps it).
static func take(p_key: String) -> BuildingMesher:
	_lock.lock()
	var kept: Array = _baked.get(p_key, [])
	if not kept.is_empty():
		kept[1] = _generation
	_lock.unlock()
	return null if kept.is_empty() else kept[0]


## Keeps a freshly baked mesher for the current city.
static func keep(p_key: String, mesher: BuildingMesher) -> void:
	_lock.lock()
	_baked[p_key] = [mesher, _generation]
	_lock.unlock()


## A new city's build starts (BuildingStream): what it uses is marked as its own.
static func begin_city() -> void:
	_lock.lock()
	_generation += 1
	_lock.unlock()


## The city is done with (its rampage leaves): every kept building it did not use is dropped.
static func end_city() -> void:
	_lock.lock()
	for k: String in _baked.keys():
		var kept: Array = _baked[k]
		if Num.i(kept[1]) != _generation:
			_baked.erase(k)
	_lock.unlock()


## A view leaves for good (BuildingStream sends a far, untouched building back to a box): its
## kept meshes go too, so the memory is really returned.
static func forget(p_key: String) -> void:
	_lock.lock()
	_baked.erase(p_key)
	_lock.unlock()


## Buildings whose meshes are kept (tests).
static func cached() -> int:
	return _baked.size()
