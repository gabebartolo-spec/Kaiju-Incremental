class_name Seeds
extends RefCounted
## Every random stream is derived from a name and an index, so any run can be replayed from
## (stream, index). Sim code takes the RandomNumberGenerator it is given.

const MASTER_SEED := 0x4B41494A


static func make(stream: String, index: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:%d" % [MASTER_SEED, stream, index])
	return rng
