## Bench census (bench_frames.gd): processing nodes and shadow casters per script.
class_name BenchCensus
extends RefCounted

## Frames at which the scene is counted.
const AT: Array[int] = [600, 1800, 2600]
const TOP := 12


static func at(root: Node, frame: int) -> void:
	if frame in AT:
		run(root, frame)


## Prints the scripts with the most processing nodes and the owners of the most visible shadow
## casters (a caster's owner: its nearest scripted ancestor), to name where frame time goes.
static func run(root: Node, frame: int) -> void:
	var procs := {}
	var casters := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		if node.is_processing() or node.is_physics_processing():
			var key := _script_of(node)
			procs[key] = Num.i(procs.get(key, 0)) + 1
		var g := node as GeometryInstance3D
		if g == null or not g.is_visible_in_tree():
			continue
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		var owner_key := _script_of(g)
		casters[owner_key] = Num.i(casters.get(owner_key, 0)) + 1
	print("BENCH_CENSUS frame %d processing %s" % [frame, _top(procs)])
	print("BENCH_CENSUS frame %d shadow_casters %s" % [frame, _top(casters)])


static func _script_of(node: Node) -> String:
	var n := node
	while n != null:
		var sc: Script = n.get_script()
		if sc != null:
			return sc.resource_path.get_file()
		n = n.get_parent()
	return "(none)"


static func _top(counts: Dictionary) -> String:
	var keys := counts.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return counts[a] > counts[b])
	var parts: Array[String] = []
	var total := 0
	for k: Variant in keys:
		total += Num.i(counts[k])
	for k: Variant in keys.slice(0, TOP):
		parts.append("%s=%d" % [k, counts[k]])
	return "total=%d %s" % [total, " ".join(parts)]
