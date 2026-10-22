class_name AreaHit
extends RefCounted
## One building's share of an area hit (RampageSim.hit_area): `force` (a Callable from a ground
## point and a radius to a 0..1 strength) says how hard each chunk is struck. Part of RampageSim,
## split out to keep the file small.


## The damage to building i on floors floors.x..floors.y-1 (a carved one through Carving).
static func building(
	sim: RampageSim, i: int, force: Callable, damage: float, floors: Vector2i
) -> void:
	var b := sim.buildings[i]
	var near: float = force.call(Vector2(b.x, b.z), Vector2(b.w, b.d).length() * 0.5)
	if near > 0.0 and sim.carving.takes(i):
		sim.carving.hit(i, force, damage, floors)  # coats what it reaches too
		return
	if near <= 0.0 or b.frame.alive_count == 0:
		return
	var cells: Array[Vector3i] = []
	var amounts := PackedFloat32Array()
	for y: int in range(maxi(0, floors.x), mini(floors.y, b.height)):
		for x: int in b.w:
			for z: int in b.d:
				var c := Vector3i(x, y, z)
				if b.frame.alive(c):
					var p := b.chunk_world(c)
					var k: float = force.call(Vector2(p.x, p.z), 0.5)
					if k > 0.0:
						cells.append(c)
						amounts.append(damage * k)
	if not sim.hit_coat.is_empty():
		sim.powers.coat(i, cells)
	sim.damage_cells(i, cells, amounts)
