class_name BroodModel
extends RefCounted
## The insectoid's brood as drawn: an egg, or one of its elephant-sized young. Split out of
## PowersView to keep files small; `box` is PowersView's _box(size, color, lit). Presentation only.


static func make(egg: bool, box: Callable) -> Node3D:
	var node := Node3D.new()
	if egg:
		node.set_meta("egg", true)
		var shell: MeshInstance3D = box.call(Vector3(0.8, 1.0, 0.8), PowersView.EGG, false)
		shell.position.y = 0.5
		node.add_child(shell)
	else:
		# Elephant-sized: a low body, a head and six legs, in the insectoid's dark brown.
		var body: MeshInstance3D = box.call(Vector3(1.4, 1.0, 2.4), PowersView.YOUNG, false)
		body.position.y = 1.2
		node.add_child(body)
		var head: MeshInstance3D = box.call(
			Vector3(1.0, 0.8, 0.8), PowersView.YOUNG.lightened(0.15), false
		)
		head.position = Vector3(0, 1.4, -1.5)
		node.add_child(head)
		for n: int in 6:
			var leg: MeshInstance3D = box.call(
				Vector3(0.25, 1.2, 0.25), PowersView.YOUNG.darkened(0.3), false
			)
			leg.position = Vector3(0.8 if n % 2 == 0 else -0.8, 0.5, -0.8 + (n / 2) * 0.8)
			node.add_child(leg)
	return node
