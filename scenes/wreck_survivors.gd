class_name WreckSurvivors
extends RefCounted
## Survivors crawling out of a derailed train and fleeing (the director's answer, 022 update
## 2026-10-25: "After a derail, survivors crawl out of the wreck and flee, using the game's
## existing crowd people"): new StreetLife people at the wreck, already running, on the pavement
## line nearest it. Presentation only.


## Adds `count` fleeing people round `at` (ground x, z) to `street`.
static func spill(street: StreetLife, at: Vector2, count: int, rng: RandomNumberGenerator) -> void:
	var nodes := street.ring_nodes()
	if nodes.is_empty():
		return
	var near := 0
	for n: int in nodes.size():
		if nodes[n].distance_squared_to(at) < nodes[near].distance_squared_to(at):
			near = n
	for _k: int in count:
		var i := street.add_person()
		var off := Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
		street.pos[i] = at + off
		street.from_node[i] = near
		street.to_node[i] = (near & ~3) + ((near + 1) & 3)
		street.heading[i] = off.normalized() if off != Vector2.ZERO else Vector2(0, 1)
		street.outfit[i] = rng.randi_range(0, VoxelPerson.COP - 1)
		street.phase[i] = rng.randf()
		street.pace[i] = rng.randf_range(1.1, 1.4)
		street.fleeing[i] = 1
