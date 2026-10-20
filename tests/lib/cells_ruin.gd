extends RefCounted
## A gone building leaves rubble, never a standing shell (director 2026-10-20: "they were
## previously reduced to rubble then emerge from the ground as flaming buildings"): every
## fixture's ruin stays within its heap's peak, no wall rising out of it.

const SPARE := 3  # voxels of lumpiness allowed above the heap's peak


static func run(check: Callable, fixtures: Array, building: Callable) -> void:
	var worst := ""
	for i: int in fixtures.size():
		var b: RampageSim.Building = building.call(fixtures[i])
		var voxels := BuildingVoxels.new(b, Color.GRAY)
		var hi := 0
		for cell: Vector3i in Ruin.heap(voxels, Seeds.make("ruin", i)).cells:
			hi = maxi(hi, cell.y)
		var tall := (hi + 1) * BuildingVoxels.VOXEL
		var peak := (2.4 + 0.9 * b.tier) + SPARE * BuildingVoxels.VOXEL
		if tall > peak:
			worst += " %s: %.2f m > %.2f m;" % [fixtures[i][0], tall, peak]
	check.call(worst == "", "every ruin is a heap no taller than its peak:%s" % worst)
