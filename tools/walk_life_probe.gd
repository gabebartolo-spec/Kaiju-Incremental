extends SceneTree
## Prints the young croc's walk numbers (tests/lib/walk_life_probe.gd): each arm's swing each way,
## how well it follows the other foot, and the snout's bob per step. Bars: data/motion_gate.json
## "walk_life".
##   godot --headless --path . --script tools/walk_life_probe.gd

const WalkLifeProbe := preload("res://tests/lib/walk_life_probe.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var m := WalkLifeProbe.new().measure(root, "baby", 0.5)
	await process_frame
	print(
		(
			(
				"young croc walk: hip %.3f; arm swing l %.1f r %.1f deg (with the other foot %.2f %.2f);"
				+ " snout bob %.3f per step (%.1f%% of the hip); in the world snout %.3f hips %.3f;"
				+ " the head's own dip %.3f;"
				+ " %d steps"
			)
			% [
				m.hip,
				m.swing[0],
				m.swing[1],
				m.with_foot[0],
				m.with_foot[1],
				m.bob,
				m.bob / m.hip * 100.0,
				m.bob_world,
				m.hips_world,
				m.nod,
				m.steps,
			]
		)
	)
	quit(0)
