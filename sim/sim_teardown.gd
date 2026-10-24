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
