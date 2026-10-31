class_name PieceParts
extends RefCounted
## A lifted piece's debris samples (BuildingView.lift_piece), {"pos", "color"} each. A big piece
## has thousands (a dictionary each, ~10 ms), so they are made on a worker; they are first read
## when it lands, by then long made. The mesher is not changed while a piece is down.


## Starts piece's samples from these chunks of mesher's.
static func start(piece: Node3D, mesher: BuildingMesher, chunks: PackedInt32Array) -> void:
	var parts: Array[Dictionary] = []
	var make := func() -> void:
		for k: int in chunks:
			parts.append_array(mesher.parts_of(k))
	var task := WorkerWait.add(WorkerThreadPool.add_task(make, true))
	piece.set_meta("parts", parts)
	piece.set_meta("parts_task", task)


## node's samples: a lifted piece's waited for if still being made; any other node's as they are.
static func of(node: Node3D) -> Array:
	if node.has_meta("parts_task"):
		WorkerWait.wait(Num.i(node.get_meta("parts_task")))
		node.remove_meta("parts_task")
	return node.get_meta("parts", [])
