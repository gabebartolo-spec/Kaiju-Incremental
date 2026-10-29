class_name StreamPlan
extends RefCounted
## The pure part of BuildingStream's replan: ranking the buildings, choosing which to mesh within
## the chunk budget, and which meshed ones are far enough past the last wanted to free.

## Buildings past the cutoff by this much (m) are freed.
const EVICT_MARGIN := 10.0
## Key resolution: buildings within 1/KEY_STEP m of each other in rank tie (then by index).
const KEY_STEP := 16.0


## The buildings not held, as sorted keys (rank, then index), and the chunks the held ones add:
## {keys, held}. The held ones (StreamRank.holds: touched, near the kaiju, or landmarks that stay
## meshed) go in `marks` and add their chunks to held.
static func rank_keys(
	sim: RampageSim,
	rank: StreamRank,
	chunks: PackedInt32Array,
	pinned: PackedByteArray,
	from: Vector2,
	limit: float,
	marks: Array[int]
) -> Dictionary:
	var keys := PackedFloat64Array()
	var held := 0
	for n: int in sim.buildings.size():
		if rank.holds(n, sim.buildings[n], from, pinned[n] == 1):
			marks.append(n)
			held += chunks[n]
		else:
			keys.append(floorf(rank.rank(n, from, limit) * KEY_STEP) * 65536.0 + n)
	keys.sort()
	return {"keys": keys, "held": held}


## The wanted buildings not built (state 0), landmarks first, then the best ranked until the
## chunk budget (less `held`) is spent: {queue, cutoff}, the cutoff the rank of the first left out.
static func pick(
	keys: PackedFloat64Array,
	marks: Array[int],
	state: PackedByteArray,
	chunks: PackedInt32Array,
	held: int,
	budget: int
) -> Dictionary:
	var queue: Array[int] = []
	for n: int in marks:
		if state[n] == 0:
			queue.append(n)
	var used := held
	var cutoff := INF
	for key: float in keys:
		var n := int(fmod(key, 65536.0))
		if used + chunks[n] > budget:
			cutoff = floorf(key / 65536.0) / KEY_STEP
			break
		used += chunks[n]
		if state[n] == 0:
			queue.append(n)
	return {"queue": queue, "cutoff": cutoff}


## The built buildings well past the cutoff, to go back to boxes.
static func evict(
	keys: PackedFloat64Array, cutoff: float, views: Array[BuildingView]
) -> Array[int]:
	var out: Array[int] = []
	if cutoff < INF:
		for key: float in keys:
			var n := int(fmod(key, 65536.0))
			if floorf(key / 65536.0) / KEY_STEP > cutoff + EVICT_MARGIN and views[n] != null:
				out.append(n)
	return out
