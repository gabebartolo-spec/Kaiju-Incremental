extends RefCounted
## Trees stand city.tree_min_apart apart (director: street and plaza trees were bunching at the
## crossings and between a plaza's ring and the kerb row). Every tree the decor planted, street,
## park, plaza ring and diagonal, is measured trunk to trunk.


## Prints each run's tree count and pair counts when KAIJU_TREE_REPORT is set (a dev aid).
static func check(
	tier: int, map_seed: int, sim: RampageSim, decor: CityDecor, check: Callable
) -> void:
	var apart := Num.f(sim.city["tree_min_apart"])
	var trees: Array[Vector2] = decor._props.felled()
	var close := 0
	var worst := INF
	var at := Vector2.ZERO
	for i: int in trees.size():
		for j: int in range(i + 1, trees.size()):
			var d := trees[i].distance_to(trees[j])
			if d < apart - 0.01:  # exactly the limit counts as clear
				close += 1
				if d < worst:
					worst = d
					at = trees[i]
	if OS.has_environment("KAIJU_TREE_REPORT"):
		print(
			(
				"TREE_REPORT stage %d seed %d: %d trees, %d pairs under %.1f m"
				% [tier, map_seed, trees.size(), close, apart]
			)
		)
	check.call(
		trees.size() > 0 and close == 0,
		(
			(
				"stage %d, map_seed %d: no two of the city's %d trees closer than %.1f m"
				% [tier, map_seed, trees.size(), apart]
			)
			+ " (%d pairs are, the closest %.2f m apart at %s)" % [close, worst, at]
		)
	)
