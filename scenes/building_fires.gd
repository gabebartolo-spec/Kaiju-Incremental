class_name BuildingFires
extends RefCounted
## The fires the sim lit on a building's chunks (the beam's coat), split out of CityView: each sits
## on one chunk and goes out when that chunk breaks or falls, and every one goes out when the
## building is down. A destroyed building stays rubble, never a burning shell (#111, R 26.1).
## Presentation only.

var _on: Dictionary = {}  # building index -> Array of [Vector3i chunk, Fire]


func add(index: int, cell: Vector3i, fire: Fire) -> void:
	if not _on.has(index):
		_on[index] = []
	var list: Array = _on[index]
	list.append([cell, fire])


## The fires on `cells` of building `index`, now off the list (still live ones only).
func cells_gone(index: int, cells: Array[Vector3i]) -> Array[Fire]:
	var out: Array[Fire] = []
	if not _on.has(index):
		return out
	var keep: Array = []
	for entry: Array in _on[index]:
		var cell: Vector3i = entry[0]
		if cells.has(cell):
			_live(entry[1], out)
		else:
			keep.append(entry)
	_on[index] = keep
	return out


## Every fire on building `index`, now off the list (still live ones only).
func building_gone(index: int) -> Array[Fire]:
	var out: Array[Fire] = []
	for entry: Array in _on.get(index, []):
		_live(entry[1], out)
	_on.erase(index)
	return out


func _live(node: Variant, out: Array[Fire]) -> void:
	if not is_instance_valid(node):
		return  # the fire cap already put it out
	var fire: Fire = node
	if not fire.is_queued_for_deletion():
		out.append(fire)
