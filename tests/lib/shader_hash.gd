extends RefCounted
## building_baked.gdshader's murmur3 (murmur_step, murmur_fmix) in 32-bit ints, step for step, so a
## test can hold it against GDScript hash(), which Look.jitter and the bite clump hash use.

const M := 0xFFFFFFFF
const SEED := 0x7F07C65


static func _step(k: int, h: int) -> int:
	k = (k * 0xcc9e2d51) & M
	k = ((k << 15) | (k >> 17)) & M
	k = (k * 0x1b873593) & M
	h ^= k
	h = ((h << 13) | (h >> 19)) & M
	return (h * 5 + 0xe6546b64) & M


static func _fmix(h: int) -> int:
	h ^= h >> 16
	h = (h * 0x85ebca6b) & M
	h ^= h >> 13
	h = (h * 0xc2b2ae35) & M
	return h ^ (h >> 16)


## The shader's jitter hash of a cell (hash(Vector4i(cell, salt))).
static func jitter(c: Vector3i, salt: int) -> int:
	return _fmix(_step(salt & M, _step(c.z & M, _step(c.y & M, _step(c.x & M, SEED)))))


## The shader's bite hash of a clump key (hash(Vector3i)).
static func bite(k: Vector3i) -> int:
	return _fmix(_step(k.z & M, _step(k.y & M, _step(k.x & M, SEED))))
