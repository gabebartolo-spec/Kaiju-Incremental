extends RefCounted
## Render plan item 8 (tuning render_opt.fx_pool), the bar: after 100 dust bursts the number of
## particle systems under Fx is what it was, and none was freed. Written without any pool symbol,
## so it runs on origin/main too, where it fails: every burst there builds a GPUParticles3D and
## frees it on a timer.
## The bursts come in WAVES of WAVE (under the pool's dust slots), each followed by the dust's
## whole lifetime, so a pool never runs out and the real give-back path (the `finished` signal,
## the timer behind it) is the one exercised. Engine.time_scale shortens the wait.

const WAVES := 5
const WAVE := 20
const SCALE := 10.0
const LIFE := 3.2  # the dust's 2.6 s plus the 0.2 s the old path waited, rounded up

var _check: Callable
var _tree: SceneTree
var _freed := 0
var _fx: Fx


func _init(check: Callable, tree: SceneTree) -> void:
	_check = check
	_tree = tree


static func particles_under(node: Node) -> int:
	var total := 0
	for child: Node in node.get_children():
		if child is GPUParticles3D:
			total += 1
		total += particles_under(child)
	return total


func _removed(node: Node) -> void:
	if node is GPUParticles3D and _fx.is_ancestor_of(node):
		_freed += 1


func run() -> void:
	_fx = Fx.new()
	_tree.root.add_child(_fx)
	await _tree.process_frame
	_tree.node_removed.connect(_removed)
	var before := particles_under(_fx)
	var scale_before := Engine.time_scale
	Engine.time_scale = SCALE
	var bursts := 0
	for wave: int in WAVES:
		for i: int in WAVE:
			_fx.dust(Vector3(i * 3.0, 0.0, wave * 3.0), 1.0)
			bursts += 1
		var during := particles_under(_fx)
		_check.call(
			during == before,
			(
				"wave %d: %d dust bursts leave %d particle systems under Fx, was %d"
				% [wave, WAVE, during, before]
			)
		)
		await _tree.create_timer(LIFE).timeout
	Engine.time_scale = scale_before
	_tree.node_removed.disconnect(_removed)
	var after := particles_under(_fx)
	_check.call(bursts == 100, "%d dust bursts were fired" % bursts)
	_check.call(after == before, "after the bursts %d particle systems, was %d" % [after, before])
	_check.call(
		_freed == 0, "%d particle systems under Fx were freed over %d bursts" % [_freed, bursts]
	)
	_fx.free()
