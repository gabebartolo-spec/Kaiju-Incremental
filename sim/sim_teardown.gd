class_name SimTeardown
extends RefCounted
## What RampageSim.dispose() does (D-179). The sim and its parts point at each other: every part
## keeps `sim`, the convoy keeps its firing posts and spacing and they keep the convoy, the body
## keeps its dash and the dash the body. Godot frees a reference-counted object only when nothing
## counts it, so a ring of them is never freed: each dropped rampage kept its city, its destruction
## grids and its road graph for good (about 240 MB a rampage in the pacing run, the shipped game
## leaked every rampage the same way). cut() walks the parts from the sim and clears every
## property that points back at a part still being walked, which leaves a tree of references that
## is freed the moment the last holder of the sim lets go. Nothing else changes: the parts keep
## their numbers, but a part that reached the sim through `sim` can no longer (read result() first).
## Any new back pointer is cut with no edit here; tests/lib/sim_dispose.gd fails if one is not.
##
## A run that is not the game (a test suite, a capture, a bench) builds hundreds of sims and drops
## most without dispose(): each kept its city until the process exited, and the exit printed
## "N ObjectDB instances were leaked" (debt row 2). Every RampageSim therefore registers here as it
## is built (note(): a weak reference, so the registry never keeps a sim alive), and cut_all() cuts
## the rings of those still alive. QuitGame.release_sims_at_exit() calls it as the process quits, so
## no test or capture has to remember dispose().

## The registry is pruned of freed sims once it holds this many, then at twice what is left.
const PRUNE_FROM := 64

## Weak references to the RampageSims built so far.
static var _built: Array[WeakRef] = []
## The size at which note() next drops the references whose sim is already freed.
static var _prune_at := PRUNE_FROM


## Registers a sim as it is built (RampageSim._init).
static func note(sim: RefCounted) -> void:
	if _built.size() >= _prune_at:
		_built = _built.filter(func(ref: WeakRef) -> bool: return ref.get_ref() != null)
		_prune_at = maxi(PRUNE_FROM, _built.size() * 2)
	_built.append(weakref(sim))


## How many registered sims are still alive.
static func alive() -> int:
	return _built.filter(func(ref: WeakRef) -> bool: return ref.get_ref() != null).size()


## Cuts the rings of every registered sim still alive and empties the registry; returns how many
## it cut. Cutting one that was already disposed changes nothing.
static func cut_all() -> int:
	return cut_built(_built)


## cut_all() over `built`, any list of weak references (tests pass their own, so a check never cuts
## a sim the suite still holds).
static func cut_built(built: Array[WeakRef]) -> int:
	var cut_sims := 0
	for ref: WeakRef in built:
		var sim := ref.get_ref() as RefCounted
		if sim != null:
			cut(sim)
			cut_sims += 1
	built.clear()
	return cut_sims


## Clears the references under `root` that point back up its tree of parts; returns how many.
static func cut(root: RefCounted) -> int:
	return _walk(root, {}, {})


## Depth-first over the script variables that hold a RefCounted. `on_path`: the parts between the
## root and this one (a reference to one of them closes a ring); `seen`: every part walked.
static func _walk(part: RefCounted, on_path: Dictionary, seen: Dictionary) -> int:
	var id := part.get_instance_id()
	on_path[id] = true
	seen[id] = true
	var cut_count := 0
	for prop: Dictionary in part.get_property_list():
		var kind: int = prop["type"]
		var usage: int = prop["usage"]
		if kind != TYPE_OBJECT or usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var prop_name := str(prop["name"])
		var value: Variant = part.get(prop_name)
		if not value is RefCounted:
			continue
		var next: RefCounted = value
		var next_id := next.get_instance_id()
		if on_path.has(next_id):
			part.set(prop_name, null)
			cut_count += 1
		elif not seen.has(next_id):
			cut_count += _walk(next, on_path, seen)
	on_path.erase(id)
	return cut_count
